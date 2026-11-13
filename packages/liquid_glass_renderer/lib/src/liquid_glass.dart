// ignore_for_file: avoid_setters_without_getters

import 'dart:ui';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_shaders/flutter_shaders.dart';
import 'package:liquid_glass_plus/liquid_glass_plus.dart';
import 'package:liquid_glass_plus/src/glass_shadow.dart';
import 'package:liquid_glass_plus/src/internal/optimized_clip.dart';
import 'package:liquid_glass_plus/src/internal/render_liquid_glass_geometry.dart';
import 'package:liquid_glass_plus/src/internal/transform_tracking_repaint_boundary_mixin.dart';
import 'package:liquid_glass_plus/src/rendering/liquid_glass_render_object.dart';
import 'package:liquid_glass_plus/src/shaders.dart';
import 'package:meta/meta.dart';

/// A liquid glass shape.
///
/// To render liquid glass, you must wrap this in a [LiquidGlassLayer],
/// where the glass effect will be rendered.
///
/// If you only need a single shape with its own settings, you can also use the
/// [LiquidGlass.withOwnLayer] constructor, which will create its own
/// [LiquidGlassLayer] internally.
/// Be mindful that creating many individual layers can be expensive.
///
/// **Impeller Required:** Liquid glass rendering requires Impeller to be
/// enabled. On non-Impeller devices (Skia), the effect automatically falls
/// back to fake glass rendering using standard backdrop filters.
///
/// **Implicit Animations:** When [LiquidGlassSettings.animationDuration] is
/// non-zero (default is 300ms), changes to [shape] and settings will animate
/// automatically. Set the duration to [Duration.zero] to disable animations
/// and make changes instant with no animation overhead.
///
/// See the [LiquidGlassLayer] documentation for more information.
class LiquidGlass extends StatefulWidget {
  /// Creates a new [LiquidGlass] with the given [child] and [shape].
  ///
  /// This will expect a parent [LiquidGlassLayer] to be present in the widget
  /// tree, where the liquid glass effect will be rendered.
  const LiquidGlass({
    required this.child,
    required this.shape,
    this.glassContainsChild = false,
    this.clipBehavior = Clip.hardEdge,
    this.shadows = const [],
    this.debugLabel,
    super.key,
  }) : ownLayerSettings = null;

  /// Creates a new [LiquidGlass] that creates its own [LiquidGlassLayer].
  ///
  /// While this might seem convenient, creating many individual layers can be
  /// expensive.
  ///
  /// You should prefer rendering multiple [LiquidGlass] shapes that share the
  /// same settings inside a single [LiquidGlassLayer] for better performance.
  ///
  /// The rendering mode (liquid glass vs fake glass) is automatically
  /// determined based on platform support.
  const LiquidGlass.withOwnLayer({
    required this.child,
    required this.shape,
    LiquidGlassSettings settings = const LiquidGlassSettings(),
    super.key,
    this.glassContainsChild = false,
    this.clipBehavior = Clip.hardEdge,
    this.shadows = const [],
    this.debugLabel,
  }) : ownLayerSettings = settings;

  /// The child of this widget.
  ///
  /// You can choose whether this should be rendered "inside" of the glass, or
  /// on top using [glassContainsChild].
  final Widget child;

  /// {@template liquid_glass_plus.LiquidGlass.shape}
  /// The shape of this glass.
  ///
  /// This is the shape of the glass that will be rendered.
  /// {@endtemplate}
  final LiquidShape shape;

  /// Controls whether the [child] is rendered behind or on top of the glass
  /// effect.
  ///
  /// When `false` (the default), the child renders **on top** of the glass
  /// surface - ideal for UI elements like text or icons that should appear
  /// crisp and unaffected by the glass effect.
  ///
  /// When `true`, the child renders **behind** the glass surface, meaning
  /// it will be affected by the glass tint, refraction, and blur effects -
  /// useful for content that should appear to be "inside" or "behind" the
  /// glass.
  ///
  /// Defaults to `false`.
  final bool glassContainsChild;

  /// The clip behavior of this glass.
  ///
  /// Defaults to [Clip.hardEdge], so [child] will be clipped to the shape.
  final Clip clipBehavior;

  /// Shadows painted around the glass shape.
  ///
  /// They are drawn with the canvas primitive that matches [shape]
  /// (`drawRSuperellipse`, `drawRRect`, `drawOval`) instead of blurring an
  /// arbitrary path, so they stay cheap.
  ///
  /// Like CSS `box-shadow` on a translucent box, shadows are only painted
  /// outside the shape: they are clipped out where the glass is, whatever
  /// their [BlurStyle], offset or spread, so the glass is never darkened.
  ///
  /// Defaults to no shadows.
  final List<BoxShadow> shadows;

  /// The settings for this glass if it is supposed to create its own layer.
  final LiquidGlassSettings? ownLayerSettings;

  /// Debug label for logging. When set, enables debug output
  /// for fake glass mode.
  final String? debugLabel;

  @override
  State<LiquidGlass> createState() => _LiquidGlassState();
}

class _LiquidGlassState extends State<LiquidGlass>
    with SingleTickerProviderStateMixin {
  // Lazily created, reused across shape animations
  AnimationController? _controller;
  CurvedAnimation? _curvedAnimation;

  // Shape animation values
  LiquidShape? _fromShape;
  LiquidShape? _animatedShape;

  // Cached settings for animation duration/curve lookup
  LiquidGlassSettings? _contextSettings;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Track context settings for animation parameters (duration/curve).
    if (widget.ownLayerSettings == null) {
      _contextSettings = LiquidGlassSettings.of(context);
    }
  }

  @override
  void didUpdateWidget(LiquidGlass oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.shape == oldWidget.shape) return;

    // Get animation params from settings
    final effectiveSettings = widget.ownLayerSettings ?? _contextSettings;
    final duration = effectiveSettings?.animationDuration ?? Duration.zero;

    if (duration == Duration.zero) {
      _clearAnimationState();
      return;
    }

    _fromShape = _animatedShape ?? oldWidget.shape;
    _startAnimation(
      duration,
      effectiveSettings?.animationCurve ?? Curves.easeInOut,
    );
  }

  void _startAnimation(Duration duration, Curve curve) {
    final controller = _controller ??= AnimationController(vsync: this)
      ..addListener(_onAnimationTick)
      ..addStatusListener(_onAnimationStatus);

    if (controller.duration != duration) {
      controller.duration = duration;
    }

    _curvedAnimation?.dispose();
    _curvedAnimation = CurvedAnimation(parent: controller, curve: curve);

    controller.forward(from: 0);
  }

  void _onAnimationTick() {
    // Set by _startAnimation before the controller starts ticking.
    final curvedAnimation = _curvedAnimation;
    if (curvedAnimation == null) return;
    _animatedShape =
        LiquidShape.lerp(_fromShape, widget.shape, curvedAnimation.value);
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
    _fromShape = null;
    _animatedShape = null;
  }

  @override
  void dispose() {
    _curvedAnimation?.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shape = _animatedShape ?? widget.shape;

    // Only create own layer if widget was constructed with ownLayerSettings.
    // Settings animation is handled by LiquidGlassLayer.
    if (widget.ownLayerSettings case final ownLayerSettings?) {
      return LiquidGlassLayer(
        settings: ownLayerSettings,
        child: Builder(
          builder: (context) => _buildGlassContent(context, shape),
        ),
      );
    }

    return _buildGlassContent(context, shape);
  }

  Widget _buildGlassContent(BuildContext context, LiquidShape shape) {
    final effectiveSettings = LiquidGlassSettings.of(context);

    final glassChild = OptimizedClip(
      shape: shape,
      clipBehavior: widget.clipBehavior,
      child: GlassGlowLayer(
        child: widget.child,
      ),
    );

    // Always present (even without shadows) so adding or removing shadows
    // doesn't remount the glass render object.
    return GlassShadow(
      shape: shape,
      shadows: widget.shadows,
      child: _buildRawGlass(context, shape, effectiveSettings, glassChild),
    );
  }

  Widget _buildRawGlass(
    BuildContext context,
    LiquidShape shape,
    LiquidGlassSettings effectiveSettings,
    Widget glassChild,
  ) {
    // Use fake glass when forced via settings or when Impeller is not available
    if (effectiveSettings.shouldUseFakeGlass) {
      return _RawLiquidGlass(
        shader: null,
        renderLink: InheritedGeometryRenderLink.of(context),
        settings: effectiveSettings,
        devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
        shape: shape,
        glassContainsChild: widget.glassContainsChild,
        child: glassChild,
      );
    }

    // Real glass: load shader and register geometry
    return ShaderBuilder(
      (context, shader, builtChild) => _RawLiquidGlass(
        shader: shader,
        renderLink: InheritedGeometryRenderLink.of(context),
        settings: effectiveSettings,
        devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
        shape: shape,
        glassContainsChild: widget.glassContainsChild,
        child: builtChild,
      ),
      assetKey: ShaderKeys.blendedGeometry,
      child: glassChild,
    );
  }
}

class _RawLiquidGlass extends SingleChildRenderObjectWidget {
  const _RawLiquidGlass({
    required super.child,
    required this.shader,
    required this.renderLink,
    required this.settings,
    required this.devicePixelRatio,
    required this.shape,
    required this.glassContainsChild,
  });

  final FragmentShader? shader;
  final GeometryRenderLink renderLink;
  final LiquidGlassSettings settings;
  final double devicePixelRatio;
  final LiquidShape shape;
  final bool glassContainsChild;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderLiquidGlassSingleShape(
      geometryShader: shader,
      renderLink: renderLink,
      settings: settings,
      devicePixelRatio: devicePixelRatio,
      shape: shape,
      glassContainsChild: glassContainsChild,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderLiquidGlassSingleShape renderObject,
  ) {
    renderObject
      ..geometryShader = shader
      ..renderLink = renderLink
      ..settings = settings
      ..devicePixelRatio = devicePixelRatio
      ..shape = shape
      ..glassContainsChild = glassContainsChild;
  }
}

/// Render object for a single liquid glass shape.
///
/// Each shape independently manages its own geometry rendering and caching.
/// This provides better performance than the previous blend group approach,
/// as moving one shape no longer forces other shapes to re-render.
@internal
class RenderLiquidGlassSingleShape extends RenderLiquidGlassGeometry
    with TransformTrackingRenderObjectMixin, LiquidGlassShapeMixin {
  /// Creates a new [RenderLiquidGlassSingleShape].
  RenderLiquidGlassSingleShape({
    required super.renderLink,
    required super.geometryShader,
    required super.settings,
    required super.devicePixelRatio,
    required LiquidShape shape,
    required bool glassContainsChild,
  })  : _shape = shape,
        _glassContainsChild = glassContainsChild;

  LiquidShape _shape;

  /// The shape of this glass.
  LiquidShape get shape => _shape;
  set shape(LiquidShape value) {
    if (_shape == value) return;
    _shape = value;
    // Update the path immediately when shape changes
    // (performLayout only runs when size changes)
    if (hasSize) {
      _lastPath = _shape.getOuterPath(Offset.zero & size);
    }
    markGeometryNeedsUpdate(force: true);
    markNeedsPaint();
  }

  bool _glassContainsChild;

  /// Whether the child is rendered inside the glass.
  bool get glassContainsChild => _glassContainsChild;
  set glassContainsChild(bool value) {
    if (_glassContainsChild == value) return;
    _glassContainsChild = value;
    markNeedsPaint();
  }

  late Path _lastPath;

  final _transformLayerHandle = LayerHandle<TransformLayer>();

  @override
  void performLayout() {
    super.performLayout();
    _lastPath = _shape.getOuterPath(Offset.zero & size);
    // Mark geometry needs update when layout changes
    markGeometryNeedsUpdate();
  }

  @override
  void onTransformChanged() {
    markGeometryNeedsUpdate();
    markNeedsPaint();
  }

  @override
  void dispose() {
    _transformLayerHandle.layer = null;
    super.dispose();
  }

  // MARK: RenderLiquidGlassGeometry implementation

  @override
  void updateShaderWithSettings(
    LiquidGlassSettings settings,
    double devicePixelRatio,
  ) {
    final shader = geometryShader;
    if (shader == null) return;
    shader.setFloatUniforms(initialIndex: 2, (value) {
      value.setFloats([
        settings.liquidGlassConfigs.refractiveIndex,
        settings.liquidGlassConfigs.chromaticAberration,
        settings.thickness,
        0.0, // blend always 0 for single shapes
      ]);
    });
  }

  @override
  void updateGeometryShaderShapes(List<ShapeGeometry> shapes) {
    final shader = geometryShader;
    if (shader == null) return;
    if (shapes.isEmpty) return;

    final shapeGeo = shapes.first;
    final center = shapeGeo.shapeBounds.center;
    final shapeSize = shapeGeo.shapeBounds.size;

    shader.setFloatUniforms(initialIndex: 6, (value) {
      value
        ..setFloat(1) // numShapes = 1
        ..setFloat(shapeGeo.rawShapeType.shaderIndex)
        ..setFloat(center.dx * devicePixelRatio)
        ..setFloat(center.dy * devicePixelRatio)
        ..setFloat(shapeSize.width * devicePixelRatio)
        ..setFloat(shapeSize.height * devicePixelRatio)
        ..setFloat(shapeGeo.rawCornerRadius * devicePixelRatio);
    });
  }

  @override
  (Rect, List<ShapeGeometry>, bool) gatherShapeData() {
    if (!hasSize) {
      return (Rect.zero, [], false);
    }

    final bounds = Offset.zero & size;
    final shapeGeometry = ShapeGeometry(
      renderObject: this,
      shape: _shape,
      glassContainsChild: _glassContainsChild,
      shapeBounds: bounds,
    );

    // Compare with cached geometry to determine if rebuild needed
    final cached = geometry?.shapes.firstOrNull;
    final needsUpdate = cached == null ||
        cached.shapeBounds != bounds ||
        cached.shape != _shape;

    return (bounds, [shapeGeometry], needsUpdate);
  }

  @override
  void paintShapeContents(
    RenderObject from,
    PaintingContext context,
    Offset offset, {
    required bool insideGlass,
  }) {
    if (_glassContainsChild != insideGlass) return;
    if (!attached) return;

    // Paint child with transform to the requesting render object
    final transform = getTransformTo(from);
    _transformLayerHandle.layer = context.pushTransform(
      needsCompositing,
      offset,
      transform,
      (context, offset) {
        if (child case final child?) {
          context.paintChild(child, offset);
        }
      },
      oldLayer: _transformLayerHandle.layer,
    );
  }

  @override
  Path getShapePath() => _lastPath;
}
