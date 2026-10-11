import 'dart:collection';
import 'dart:math';
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_shaders/flutter_shaders.dart';
import 'package:liquid_glass_plus/liquid_glass_plus.dart';
import 'package:liquid_glass_plus/src/internal/render_liquid_glass_geometry.dart';
import 'package:liquid_glass_plus/src/internal/snap_rect_to_pixels.dart';
import 'package:liquid_glass_plus/src/logging.dart';
import 'package:meta/meta.dart';

/// A render object that can assemble [RenderLiquidGlassGeometry] shapes and
/// render them to the screen with the liquid glass effect.
@internal
abstract class LiquidGlassRenderObject extends RenderProxyBox {
  LiquidGlassRenderObject({
    required GeometryRenderLink link,
    required FragmentShader? renderShader,
    required LiquidGlassSettings settings,
    required double devicePixelRatio,
    required BackdropKey? backdropKey,
  })  : _renderShader = renderShader,
        _settings = settings,
        _devicePixelRatio = devicePixelRatio,
        _backdropKey = backdropKey,
        _link = link {
    logger.info('Setting backdrop key to $backdropKey');
    _updateShaderSettings();
  }

  static final logger = Logger(LgrLogNames.render);

  FragmentShader? _renderShader;
  FragmentShader? get renderShader => _renderShader;
  set renderShader(FragmentShader? value) {
    if (_renderShader == value) return;
    _renderShader = value;
    _updateShaderSettings();
    markNeedsPaint();
  }

  /// The size that the geometry texture should have.
  Size get desiredMatteSize;

  Matrix4 get matteTransform;

  late GeometryRenderLink _link;
  GeometryRenderLink get link => _link;
  set link(GeometryRenderLink value) {
    if (_link == value) return;
    markNeedsPaint();
    _link = value;
  }

  LiquidGlassSettings? _settings;

  /// The settings for the liquid glass effect.
  ///
  /// This is always non-null after construction as it's a required parameter.
  LiquidGlassSettings get settings {
    assert(
      _settings != null,
      'Settings accessed before initialization. '
      'Ensure the render object is properly constructed.',
    );
    return _settings!;
  }

  set settings(LiquidGlassSettings value) {
    if (_settings == value) return;
    _settings = value;
    _updateShaderSettings();
    markNeedsPaint();
  }

  BackdropKey? _backdropKey;
  BackdropKey? get backdropKey => _backdropKey;
  set backdropKey(BackdropKey? value) {
    if (_backdropKey == value) return;
    _backdropKey = value;
  }

  double _devicePixelRatio;
  double get devicePixelRatio => _devicePixelRatio;
  set devicePixelRatio(double value) {
    if (_devicePixelRatio == value) return;
    _devicePixelRatio = value;
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => _geometryImage != null;

  /// Pre-rendered geometry texture in screen space
  ui.Image? _geometryImage;

  /// The bounding box of the geometry matte in the coordinate space of the
  /// shader
  Rect _geometryMatteBounds = Rect.zero;

  @override
  @mustCallSuper
  void attach(PipelineOwner owner) {
    super.attach(owner);
  }

  @override
  @mustCallSuper
  void detach() {
    // Clear cached geometry to release GPU resources when detached from tree.
    // The geometry will be rebuilt when re-attached if needed.
    _clearGeometryImage();
    super.detach();
  }

  @override
  void layout(Constraints constraints, {bool parentUsesSize = false}) {
    needsGeometryUpdate = true;
    super.layout(constraints, parentUsesSize: parentUsesSize);
  }

  void _updateShaderSettings() {
    final shader = renderShader;
    if (shader == null) return;
    shader.setFloatUniforms(initialIndex: 6, (value) {
      value
        ..setColor(settings.glassColor)
        ..setFloats([
          settings.liquidGlassConfigs.refractiveIndex,
          settings.liquidGlassConfigs.chromaticAberration,
          settings.thickness,
          settings.lightIntensity,
          settings.ambientStrength,
          settings.saturation,
        ])
        ..setOffset(
          Offset(
            cos(settings.lightAngle),
            sin(settings.lightAngle),
          ),
        );
    });
  }

  ui.Rect _paintBounds = ui.Rect.zero;

  @override
  ui.Rect get paintBounds => _paintBounds;

  // MARK: Painting

  @override
  @nonVirtual
  void paint(PaintingContext context, Offset offset) {
    logger.finest('$hashCode Painting liquid glass with '
        '${link._shapeGeometries.length} shapes.');

    final shapesWithGeometry =
        <(RenderLiquidGlassGeometry, GeometryCache, Matrix4)>[];

    Rect? boundingBox;

    for (final geometryRo in link.shapes) {
      final geometry = geometryRo.maybeRebuildGeometry();

      if (geometry == null) continue;

      final transform = geometryRo.getTransformTo(this);
      shapesWithGeometry.add((geometryRo, geometry, transform));

      final geoBounds = MatrixUtils.transformRect(
        transform,
        geometry.bounds,
      );
      boundingBox = boundingBox == null
          ? geoBounds
          : boundingBox.expandToInclude(geoBounds);
    }

    if (boundingBox == null) {
      _clearGeometryImage();

      super.paint(context, offset);
      return;
    }

    _paintBounds = boundingBox;

    if (settings.thickness <= 0) {
      _clearGeometryImage();
      paintShapeContents(
        context,
        offset,
        shapesWithGeometry,
        insideGlass: true,
      );
      paintShapeContents(
        context,
        offset,
        shapesWithGeometry,
        insideGlass: false,
      );
      super.paint(context, offset);
      return;
    }

    if (needsGeometryUpdate || _geometryImage == null || link._dirty) {
      link.updateAllGeometries();
      _clearGeometryImage();
      link._dirty = false;

      needsGeometryUpdate = false;

      // When the geometry image can't be built (empty bounds), no glass is
      // painted this frame and children are painted normally below.
      if (_buildGeometryImage(shapesWithGeometry, boundingBox)
          case (final image, final matteBounds)) {
        _geometryImage = image;
        _geometryMatteBounds = matteBounds;
      }
    }

    if (debugPaintLiquidGlassGeometry) {
      _debugPaintGeometry(context, offset);
      paintShapeContents(
        context,
        offset,
        shapesWithGeometry,
        insideGlass: true,
      );
      paintShapeContents(
        context,
        offset,
        shapesWithGeometry,
        insideGlass: false,
      );
    } else {
      if (_geometryImage case final geometryImage?) {
        final shader = renderShader;
        if (shader != null) {
          shader
            ..setFloatUniforms(initialIndex: 2, (value) {
              value
                ..setOffset(_geometryMatteBounds.topLeft * devicePixelRatio)
                ..setSize(_geometryMatteBounds.size * devicePixelRatio);
            })
            ..setImageSampler(1, geometryImage);
          paintLiquidGlass(
            context,
            offset,
            shapesWithGeometry,
            _paintBounds,
          );
        } else {
          paintFakeGlass(
            context,
            offset,
            shapesWithGeometry,
            _paintBounds,
          );
        }
      }
    }

    super.paint(context, offset);
  }

  void _clearGeometryImage() {
    _geometryImage?.dispose();
    _geometryImage = null;
  }

  /// Subclasses implement the actual glass rendering
  /// (e.g., with backdrop filters)
  void paintLiquidGlass(
    PaintingContext context,
    Offset offset,
    List<(RenderLiquidGlassGeometry, GeometryCache, Matrix4)> shapes,
    Rect boundingBox,
  );

  /// Subclasses implement fake glass rendering when shader is not available.
  /// This uses backdrop filters and canvas painting instead of shaders.
  void paintFakeGlass(
    PaintingContext context,
    Offset offset,
    List<(RenderLiquidGlassGeometry, GeometryCache, Matrix4)> shapes,
    Rect boundingBox,
  );

  @protected
  void paintShapeContents(
    PaintingContext context,
    Offset offset,
    List<(RenderLiquidGlassGeometry, GeometryCache, Matrix4)> shapes, {
    required bool insideGlass,
  }) {
    for (final (geometryRenderObject, _, _) in shapes) {
      geometryRenderObject.paintShapeContents(
        this,
        context,
        offset,
        insideGlass: insideGlass,
      );
    }
  }

  void _debugPaintGeometry(PaintingContext context, Offset offset) {
    if (_geometryImage case final geometryImage?) {
      final backToThis = Matrix4.inverted(matteTransform).storage;
      final bounds = MatrixUtils.transformRect(
        matteTransform,
        paintBounds,
      ).snapToPixels(devicePixelRatio);
      context.canvas
        ..save()
        ..transform(backToThis)
        ..translate(
          bounds.left,
          bounds.top,
        )
        ..scale(1 / devicePixelRatio)
        ..drawImage(
          geometryImage,
          offset * devicePixelRatio,
          Paint()..blendMode = BlendMode.src,
        )
        ..restore();
    }
  }

  @override
  @mustCallSuper
  void dispose() {
    _clearGeometryImage();
    super.dispose();
  }

  // MARK: Geometry

  @protected
  bool needsGeometryUpdate = true;

  /// Returns null when the geometry bounds have no area in physical pixels,
  /// since `toImageSync` throws "Invalid image dimensions" for those.
  (ui.Image, Rect)? _buildGeometryImage(
    List<(RenderLiquidGlassGeometry, GeometryCache, Matrix4)> geometries,
    Rect bounds,
  ) {
    final boundsInMatteSpace = MatrixUtils.transformRect(
      matteTransform,
      bounds,
    ).snapToPixels(devicePixelRatio);

    final size = boundsInMatteSpace.size * devicePixelRatio;
    final imageWidth = size.width.ceil();
    final imageHeight = size.height.ceil();
    if (imageWidth <= 0 || imageHeight <= 0) {
      logger.fine(
        '$hashCode Skipping geometry image for empty size '
        '${size.width}x${size.height}',
      );
      return null;
    }

    // Only allocate StringBuffer if logging is active to avoid
    // unnecessary allocations on every frame
    final isLogging = LgrLogs.isLogActive(logger);
    StringBuffer? buffer;
    if (isLogging) {
      buffer = StringBuffer(
        '$hashCode Built geometry image with ${geometries.length} shapes '
        'at size ${size.width}x${size.height}:\n',
      );
    }

    final recorder = ui.PictureRecorder();

    final canvas = Canvas(recorder);

    for (final (_, geometry, transform) in geometries) {
      canvas
        ..save()
        ..scale(devicePixelRatio)
        ..translate(
          -boundsInMatteSpace.left,
          -boundsInMatteSpace.top,
        )
        ..transform(matteTransform.storage)
        ..transform(transform.storage)
        ..scale(1 / devicePixelRatio)
        ..translate(
          geometry.matteBounds.topLeft.dx,
          geometry.matteBounds.topLeft.dy,
        );

      switch (geometry) {
        case UnrenderedGeometryCache(matte: final picture):
          buffer?.writeln('\t- Unrendered @ ${geometry.bounds}');
          canvas.drawPicture(picture);
        case RenderedGeometryCache(matte: final image):
          buffer?.writeln('\t- Rendered @ ${geometry.bounds}');
          canvas.drawImage(image, Offset.zero, Paint());
        case PathOnlyGeometryCache():
          buffer?.writeln('\t- PathOnly @ ${geometry.bounds}');
        // PathOnlyGeometryCache has no matte to draw
      }

      canvas.restore();
    }

    final picture = recorder.endRecording();
    try {
      final image = picture.toImageSync(imageWidth, imageHeight);

      if (buffer != null) {
        logger.fine(buffer.toString());
      }
      return (image, boundsInMatteSpace);
    } finally {
      picture.dispose();
    }
  }
}

@internal
class GeometryRenderLink {
  final List<RenderLiquidGlassGeometry> _shapeGeometries = [];

  UnmodifiableListView<RenderLiquidGlassGeometry> get shapes =>
      UnmodifiableListView(_shapeGeometries);

  bool _dirty = false;

  void updateAllGeometries() {
    for (final renderObject in _shapeGeometries) {
      renderObject.maybeRebuildGeometry();
    }
  }

  void registerGeometry(
    RenderLiquidGlassGeometry renderObject,
  ) {
    // Prevent duplicate registrations
    if (_shapeGeometries.contains(renderObject)) {
      return;
    }
    _dirty = true;
    _shapeGeometries.add(renderObject);
  }

  void markRebuilt(RenderLiquidGlassGeometry renderObject) {
    _dirty = true;
  }

  void unregisterGeometry(RenderLiquidGlassGeometry renderObject) {
    _shapeGeometries.remove(renderObject);
  }

  void dispose() {
    _shapeGeometries.clear();
  }
}

@internal
class InheritedGeometryRenderLink extends InheritedWidget {
  const InheritedGeometryRenderLink({
    required this.link,
    required super.child,
    super.key,
  });

  final GeometryRenderLink link;

  static GeometryRenderLink? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<InheritedGeometryRenderLink>()
        ?.link;
  }

  @override
  bool updateShouldNotify(covariant InheritedGeometryRenderLink oldWidget) {
    return oldWidget.link != link;
  }
}
