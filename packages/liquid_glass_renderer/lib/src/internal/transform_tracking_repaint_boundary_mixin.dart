import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:meta/meta.dart';

@internal
mixin TransformTrackingRenderObjectMixin on RenderProxyBox {
  // Only this mixin sets the layer, so it is always a
  // GeometryTransformTrackingLayer when present.
  @override
  GeometryTransformTrackingLayer? get layer => switch (super.layer) {
        final GeometryTransformTrackingLayer layer => layer,
        _ => null,
      };

  @override
  @nonVirtual
  bool get isRepaintBoundary => false;

  @override
  bool get alwaysNeedsCompositing => true;

  @mustCallSuper
  @override
  void paint(PaintingContext context, ui.Offset offset) {
    final layer = setUpLayer(offset);
    context.pushLayer(layer, (context, offset) {}, offset);
    super.paint(context, offset);
  }

  GeometryTransformTrackingLayer setUpLayer(Offset offset) {
    return (layer ??= GeometryTransformTrackingLayer())
      ..renderObject = this
      ..onTransformChanged = () {
        if (attached) {
          onTransformChanged();
        }
      };
  }

  void onTransformChanged();
}

@internal
class GeometryTransformTrackingLayer extends OffsetLayer {
  GeometryTransformTrackingLayer();

  RenderObject? renderObject;
  VoidCallback? onTransformChanged;
  Matrix4? _lastTransform;

  @override
  bool get alwaysNeedsAddToScene => true;

  @override
  void addToScene(ui.SceneBuilder builder) {
    final currentTransform = renderObject?.getTransformTo(null);
    if (!MatrixUtils.matrixEquals(currentTransform, _lastTransform)) {
      onTransformChanged?.call();
      _lastTransform = currentTransform;
    }
  }

  @override
  void dispose() {
    // Clear callbacks to prevent memory leaks
    onTransformChanged = null;
    renderObject = null;
    _lastTransform = null;
    super.dispose();
  }
}
