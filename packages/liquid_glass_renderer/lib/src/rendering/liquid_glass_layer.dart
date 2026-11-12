// ignore_for_file: avoid_setters_without_getters

import 'dart:ui';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_shaders/flutter_shaders.dart';
import 'package:liquid_glass_plus/liquid_glass_plus.dart';
import 'package:liquid_glass_plus/src/internal/render_liquid_glass_geometry.dart';
import 'package:liquid_glass_plus/src/internal/transform_tracking_repaint_boundary_mixin.dart';
import 'package:liquid_glass_plus/src/liquid_glass_render_scope.dart';
import 'package:liquid_glass_plus/src/logging.dart';
import 'package:liquid_glass_plus/src/rendering/fake_glass_effects_mixin.dart';
import 'package:liquid_glass_plus/src/rendering/liquid_glass_render_object.dart';
import 'package:liquid_glass_plus/src/shaders.dart';
import 'package:meta/meta.dart';

/// Represents a layer of multiple [LiquidGlass] shapes that have shared
/// [LiquidGlassSettings] and will be rendered together.
///
/// **Impeller Required:** Liquid glass rendering requires Impeller to be
/// enabled. On non-Impeller devices (Skia), the effect automatically falls
/// back to fake glass rendering using standard backdrop filters.
///
/// **Performance:** Impeller-based liquid glass provides better visual quality
/// AND better performance than fake glass, because it uses custom shaders that
/// run entirely on the GPU.
///
/// If you create a [LiquidGlassLayer] with one or more [LiquidGlass] widgets,
/// the liquid glass effect will be rendered where this layer is.
///
/// Make sure not to stack any other widgets between the [LiquidGlassLayer] and
/// the [LiquidGlass] widgets, otherwise the liquid glass effect will be behind
/// them.
///
/// ## Example
///
/// ```dart
/// Widget build(BuildContext context) {
///   return LiquidGlassLayer(
///     child: Column(
///       children: [
///         LiquidGlass(
///           shape: LiquidRoundedSuperellipse(
///             borderRadius: 10,
///           ),
///           child: const SizedBox.square(
///             dimension: 100,
///           ),
///         ),
///         const SizedBox(height: 16),
///         LiquidGlass(
///           shape: const LiquidOval(),
///           child: const SizedBox.square(
///             dimension: 100,
///           ),
///         ),
///       ],
///     ),
///   );
/// }
/// ```
class LiquidGlassLayer extends StatefulWidget {
  /// Creates a new [LiquidGlassLayer] with the given [child] and [settings].
  ///
  /// The rendering mode (liquid glass vs fake glass) is automatically
  /// determined based on platform support. Impeller-enabled devices use
  /// shader-based liquid glass; Skia devices fall back to fake glass.
  const LiquidGlassLayer({
    required this.child,
    this.settings = const LiquidGlassSettings(),
    this.useBackdropGroup = false,
    super.key,
  });

  /// The subtree in which you should include at least one [LiquidGlass] widget.
  ///
  /// The [LiquidGlassLayer] will automatically register all [LiquidGlass]
  /// widgets in the subtree as shapes and render them.
  final Widget child;

  /// The settings for the liquid glass effect for all shapes in this layer.
  final LiquidGlassSettings settings;

  /// Whether to look up the tree for a [BackdropGroup] to use for this layer's
  /// blur.
  ///
  /// If you have multiple [LiquidGlassLayer]s in a subtree that use the same
  /// background blur, setting this to true can improve performance by sharing
  /// the same backdrop.
  ///
  /// When fake glass mode is active (non-Impeller devices), this will be
  /// ignored as the widget already uses a shared backdrop internally.
  ///
  /// Defaults to false.
  final bool useBackdropGroup;

  @override
  State<LiquidGlassLayer> createState() => _LiquidGlassLayerState();
}

class _LiquidGlassLayerState extends State<LiquidGlassLayer>
    with SingleTickerProviderStateMixin {
  late final GeometryRenderLink _link = GeometryRenderLink();

  late final logger = Logger(LgrLogNames.layer);

  // Animation support for settings changes
  AnimationController? _controller;
  CurvedAnimation? _curvedAnimation;
  LiquidGlassSettings? _fromSettings;
  LiquidGlassSettings? _animatedSettings;

  @override
  void didUpdateWidget(LiquidGlassLayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.settings == oldWidget.settings) return;

    final duration = widget.settings.animationDuration;
    if (duration == Duration.zero) {
      _clearAnimationState();
      return;
    }

    _fromSettings = _animatedSettings ?? oldWidget.settings;
    _startAnimation(duration, widget.settings.animationCurve);
  }

  void _startAnimation(Duration duration, Curve curve) {
    _controller ??= AnimationController(vsync: this)
      ..addListener(_onAnimationTick)
      ..addStatusListener(_onAnimationStatus);

    if (_controller!.duration != duration) {
      _controller!.duration = duration;
    }

    _curvedAnimation?.dispose();
    _curvedAnimation = CurvedAnimation(parent: _controller!, curve: curve);

    _controller!.forward(from: 0);
  }

  void _onAnimationTick() {
    final t = _curvedAnimation?.value ?? _controller!.value;
    _animatedSettings =
        LiquidGlassSettings.lerp(_fromSettings!, widget.settings, t);
    setState(() {});
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _clearAnimationState();
      setState(() {});
    }
  }

  void _clearAnimationState() {
    _controller?.stop();
    _fromSettings = null;
    _animatedSettings = null;
  }

  @override
  void dispose() {
    _curvedAnimation?.dispose();
    _controller?.dispose();
    _link.dispose();
    super.dispose();
  }

  LiquidGlassSettings get _effectiveSettings =>
      _animatedSettings ?? widget.settings;

  @override
  Widget build(BuildContext context) {
    final settings = _effectiveSettings;

    // Use fake glass when forced via settings or when Impeller is not available
    final useFakeGlass = settings.shouldUseFakeGlass;

    if (useFakeGlass) {
      // Use the same rendering pipeline as real glass, but with null shader
      // This enables unified widget grouping and layer behavior
      return RepaintBoundary(
        child: LiquidGlassRenderScope(
          settings: settings,
          child: InheritedGeometryRenderLink(
            link: _link,
            child: BackdropGroup(
              child: Builder(
                builder: (context) => _RawShapes(
                  renderShader: null,
                  backdropKey: BackdropGroup.of(context)?.backdropKey,
                  settings: settings,
                  link: _link,
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return RepaintBoundary(
      child: LiquidGlassRenderScope(
        settings: settings,
        child: InheritedGeometryRenderLink(
          link: _link,
          child: ShaderBuilder(
            assetKey: ShaderKeys.liquidGlassRender,
            (context, shader, child) => _RawShapes(
              renderShader: shader,
              backdropKey: widget.useBackdropGroup
                  ? BackdropGroup.of(context)?.backdropKey
                  : null,
              settings: settings,
              link: _link,
              child: child!,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class _RawShapes extends SingleChildRenderObjectWidget {
  const _RawShapes({
    required this.renderShader,
    required this.backdropKey,
    required this.settings,
    required Widget super.child,
    required this.link,
  });

  final FragmentShader? renderShader;
  final BackdropKey? backdropKey;
  final LiquidGlassSettings settings;
  final GeometryRenderLink link;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderLiquidGlassLayer(
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
      renderShader: renderShader,
      backdropKey: backdropKey,
      settings: settings,
      link: link,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderLiquidGlassLayer renderObject,
  ) {
    renderObject
      ..link = link
      ..devicePixelRatio = MediaQuery.devicePixelRatioOf(context)
      ..renderShader = renderShader
      ..settings = settings
      ..backdropKey = backdropKey;
  }
}

@internal
class RenderLiquidGlassLayer extends LiquidGlassRenderObject
    with TransformTrackingRenderObjectMixin, FakeGlassEffectsMixin {
  RenderLiquidGlassLayer({
    required super.renderShader,
    required super.backdropKey,
    required super.devicePixelRatio,
    required super.settings,
    required super.link,
  });

  @override
  LiquidGlassSettings get fakeGlassSettings => settings;

  @override
  set settings(LiquidGlassSettings value) {
    if (settings == value) return;
    invalidateFakeGlassCache();
    super.settings = value;
  }

  final _shaderHandle = LayerHandle<BackdropFilterLayer>();
  final _blurLayerHandle = LayerHandle<BackdropFilterLayer>();
  final _clipPathLayerHandle = LayerHandle<ClipPathLayer>();
  final _clipRectLayerHandle = LayerHandle<ClipRectLayer>();

  // Layer handles for fake glass rendering
  final _fakeGlassFilterLayerHandle = LayerHandle<BackdropFilterLayer>();
  final _fakeGlassClipPathLayerHandle = LayerHandle<ClipPathLayer>();

  // Cache for saturation matrix
  double? _cachedSaturationValue;
  List<double>? _cachedSaturationMatrix;
  List<double> _getSaturationMatrix(double saturation) {
    if (_cachedSaturationMatrix != null &&
        _cachedSaturationValue == saturation) {
      return _cachedSaturationMatrix!;
    }
    _cachedSaturationValue = saturation;
    _cachedSaturationMatrix = createSaturationMatrix(saturation);
    return _cachedSaturationMatrix!;
  }

  /// Saturation boosted to match the real glass shader appearance.
  double get _fakeGlassBoostedSaturation =>
      (1.0 + (settings.saturation - 1.0) * kFakeGlassSaturationMultiplier)
          .clamp(0.0, double.infinity);

  /// Whether the fake glass backdrop filter would change the backdrop at all.
  ///
  /// When it wouldn't (no blur, no saturation change and no refraction), the
  /// [BackdropFilterLayer] is skipped: it would only cost an extra backdrop
  /// read and an offscreen pass for an identity filter.
  bool get _hasFakeGlassBackdropEffect =>
      settings.frostIntensity != 0 ||
      _fakeGlassBoostedSaturation != 1.0 ||
      settings.fakeGlassConfigs.refraction > 0;

  /// Builds a combined filter for fake glass effects.
  ///
  /// Uses the layer's size for refraction calculations to ensure consistent
  /// positioning regardless of which shapes are enabled.
  ///
  /// Always includes blur (with frostIntensity as sigma) to avoid animation
  /// glitches when transitioning between frosted and non-frosted states.
  ImageFilter _buildFakeGlassFilter() {
    final refraction = settings.fakeGlassConfigs.refraction;

    // Use layer center for the refraction effect to ensure consistent
    // positioning regardless of which shapes are enabled
    final layerBounds = Offset.zero & size;
    final center = layerBounds.center;

    final refractionFilter = refraction > 0
        ? createRefractionFilter(center, refraction, layerBounds.size)
        : null;

    final boostedSaturation = _fakeGlassBoostedSaturation;
    final saturationFilter = boostedSaturation != 1.0
        ? ColorFilter.matrix(_getSaturationMatrix(boostedSaturation))
        : null;

    // Always include blur to avoid animation glitches when frostIntensity
    // transitions between 0 and non-zero. A sigma of 0 is a no-op for the GPU.
    final blurFilter = ImageFilter.blur(
      sigmaX: settings.frostIntensity,
      sigmaY: settings.frostIntensity,
      tileMode: TileMode.mirror,
    );

    // Compose: refraction -> saturation -> blur
    var combinedFilter = blurFilter;
    if (saturationFilter != null) {
      combinedFilter = ImageFilter.compose(
        inner: saturationFilter,
        outer: combinedFilter,
      );
    }
    if (refractionFilter != null) {
      combinedFilter = ImageFilter.compose(
        inner: refractionFilter,
        outer: combinedFilter,
      );
    }

    return combinedFilter;
  }

  @override
  Size get desiredMatteSize => switch (owner?.rootNode) {
        final RenderView rv => rv.size,
        final RenderBox rb => rb.size,
        _ => Size.zero,
      };

  @override
  Matrix4 get matteTransform => getTransformTo(null);

  @override
  void onTransformChanged() {
    needsGeometryUpdate = true;
    markNeedsPaint();
  }

  @override
  void paintLiquidGlass(
    PaintingContext context,
    Offset offset,
    List<(RenderLiquidGlassGeometry, GeometryCache, Matrix4)> shapes,
    Rect boundingBox,
  ) {
    if (!attached) return;

    // Filter out detached shapes
    final attachedShapes = shapes.where((s) => s.$1.attached).toList();
    if (attachedShapes.isEmpty) {
      _blurLayerHandle.layer = null;
      _clipPathLayerHandle.layer = null;
      return;
    }

    final shaderLayer = (_shaderHandle.layer ??= BackdropFilterLayer())
      ..filter = ImageFilter.shader(renderShader!);

    // Build clip path from all shapes
    final clipPath = Path();
    for (final geometry in attachedShapes) {
      clipPath.addPath(
        geometry.$2.path,
        Offset.zero,
        matrix4: geometry.$3.storage,
      );
    }

    // Always use the blur layer to avoid animation glitches when frostIntensity
    // transitions between 0 and non-zero. A sigma of 0 is a no-op for the GPU.
    // Note: There's a known subtle displacement when transitioning between
    // sigma=0 and sigma>0 due to Impeller's different code paths, but fixing
    // it with a minimum sigma has significant performance cost.
    final blurLayer = (_blurLayerHandle.layer ??= BackdropFilterLayer())
      ..backdropKey = backdropKey
      ..filter = ImageFilter.blur(
        tileMode: TileMode.mirror,
        sigmaX: settings.frostIntensity,
        sigmaY: settings.frostIntensity,
      );

    _clipPathLayerHandle.layer = context.pushClipPath(
      needsCompositing,
      offset,
      boundingBox,
      clipPath,
      (context, offset) {
        context.pushLayer(
          blurLayer,
          (context, offset) {
            paintShapeContents(
              context,
              offset,
              attachedShapes,
              insideGlass: true,
            );
          },
          offset,
        );
      },
      oldLayer: _clipPathLayerHandle.layer,
    );

    // Apply shader to ALL shapes
    _clipRectLayerHandle.layer = context.pushClipRect(
      needsCompositing,
      offset,
      boundingBox,
      (context, offset) {
        context.pushLayer(
          shaderLayer,
          (context, offset) {
            paintShapeContents(
              context,
              offset,
              shapes,
              insideGlass: false,
            );
          },
          offset,
        );
      },
      oldLayer: _clipRectLayerHandle.layer,
    );
  }

  @override
  void paintFakeGlass(
    PaintingContext context,
    Offset offset,
    List<(RenderLiquidGlassGeometry, GeometryCache, Matrix4)> shapes,
    Rect boundingBox,
  ) {
    if (!attached) return;

    // Use layer bounds for clip rect to ensure consistent backdrop sampling
    // regardless of which shapes are enabled
    final layerBounds = Offset.zero & size;

    // Filter out detached shapes
    final attachedShapes = shapes.where((s) => s.$1.attached).toList();
    if (attachedShapes.isEmpty) {
      _fakeGlassFilterLayerHandle.layer = null;
      _fakeGlassClipPathLayerHandle.layer = null;
      return;
    }

    final clipPath = Path();
    for (final geometry in attachedShapes) {
      clipPath.addPath(
        geometry.$2.path,
        Offset.zero,
        matrix4: geometry.$3.storage,
      );
    }

    void paintInsideGlass(PaintingContext context, Offset offset) {
      // Paint inside-glass content
      paintShapeContents(
        context,
        offset,
        attachedShapes,
        insideGlass: true,
      );

      // Paint fake glass visual effects for each shape
      for (final (_, geometry, transform) in attachedShapes) {
        final transformedPath = geometry.path.transform(transform.storage);
        final transformedBounds = MatrixUtils.transformRect(
          transform,
          geometry.bounds,
        );
        paintFakeGlassEffects(
          context.canvas,
          transformedPath,
          transformedBounds,
        );
      }
    }

    final hasBackdropEffect = _hasFakeGlassBackdropEffect;
    if (!hasBackdropEffect) {
      // Nothing to filter: paint the tint, highlights and content directly
      // inside the clip, without a BackdropFilterLayer.
      _fakeGlassFilterLayerHandle.layer = null;
    }

    _fakeGlassClipPathLayerHandle.layer = context.pushClipPath(
      needsCompositing,
      offset,
      layerBounds,
      clipPath,
      (context, offset) {
        if (!hasBackdropEffect) {
          paintInsideGlass(context, offset);
          return;
        }

        // Reuse the same layer while it is needed to avoid animation glitches
        final filterLayer = (_fakeGlassFilterLayerHandle.layer ??=
            BackdropFilterLayer())
          ..backdropKey = backdropKey
          ..filter = _buildFakeGlassFilter();
        context.pushLayer(filterLayer, paintInsideGlass, offset);
      },
      oldLayer: _fakeGlassClipPathLayerHandle.layer,
    );

    // Paint outside-glass content for all shapes
    paintShapeContents(context, offset, shapes, insideGlass: false);
  }

  @override
  void dispose() {
    _blurLayerHandle.layer = null;
    _shaderHandle.layer = null;
    _clipPathLayerHandle.layer = null;
    _clipRectLayerHandle.layer = null;
    _fakeGlassFilterLayerHandle.layer = null;
    _fakeGlassClipPathLayerHandle.layer = null;
    super.dispose();
  }
}
