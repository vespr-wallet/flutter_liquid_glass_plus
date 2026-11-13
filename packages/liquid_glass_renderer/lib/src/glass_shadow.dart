import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:liquid_glass_plus/liquid_glass_plus.dart';

/// Paints [BoxShadow]s for a [LiquidShape] using canvas primitives
/// (`drawRSuperellipse`, `drawRRect`, `drawOval`) instead of `drawPath`.
///
/// This avoids rasterizing an arbitrary [Path] with a blur [MaskFilter],
/// which is much slower than the dedicated primitives Impeller and Skia
/// provide for these shapes.
///
/// The shadows are clipped out of the shape itself, like CSS `box-shadow` on
/// a translucent box: whatever the [BlurStyle] or offset, nothing is painted
/// where the glass is, so the shadow never darkens the glass.
@internal
class GlassShadow extends SingleChildRenderObjectWidget {
  /// Creates a [GlassShadow] that paints [shadows] around [shape].
  const GlassShadow({
    required this.shape,
    required this.shadows,
    super.child,
    super.key,
  });

  /// The shape to paint shadows for.
  final LiquidShape shape;

  /// The shadows to paint, in order.
  final List<BoxShadow> shadows;

  @override
  RenderGlassShadow createRenderObject(BuildContext context) {
    return RenderGlassShadow(shape: shape, shadows: shadows);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderGlassShadow renderObject,
  ) {
    renderObject
      ..shape = shape
      ..shadows = shadows;
  }
}

/// Render object for [GlassShadow].
@internal
class RenderGlassShadow extends RenderProxyBox {
  /// Creates a [RenderGlassShadow].
  RenderGlassShadow({
    required LiquidShape shape,
    required List<BoxShadow> shadows,
  })  : _shape = shape,
        _shadows = shadows;

  /// The shape to paint shadows for.
  LiquidShape get shape => _shape;
  LiquidShape _shape;
  set shape(LiquidShape value) {
    if (_shape == value) return;
    _shape = value;
    markNeedsPaint();
  }

  /// The shadows to paint.
  List<BoxShadow> get shadows => _shadows;
  List<BoxShadow> _shadows;
  set shadows(List<BoxShadow> value) {
    if (listEquals(_shadows, value)) return;
    _shadows = value;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_shadows.isNotEmpty) {
      final rect = offset & size;
      final canvas = context.canvas;

      // Clip the shape out of everything the shadows can reach, so they only
      // paint outside the glass.
      var shadowBounds = rect;
      for (final shadow in _shadows) {
        shadowBounds = shadowBounds.expandToInclude(
          rect
              .shift(shadow.offset)
              .inflate(shadow.spreadRadius + shadow.blurSigma * 3),
        );
      }
      canvas
        ..save()
        ..clipPath(
          Path()
            ..fillType = PathFillType.evenOdd
            ..addRect(shadowBounds.inflate(1))
            ..addPath(_shape.getOuterPath(rect), Offset.zero),
        );

      for (final shadow in _shadows) {
        final shadowRect =
            rect.shift(shadow.offset).inflate(shadow.spreadRadius);
        final paint = shadow.toPaint();

        switch (_shape) {
          case LiquidRoundedSuperellipse(:final borderRadius):
            canvas.drawRSuperellipse(
              RSuperellipse.fromRectAndRadius(
                shadowRect,
                Radius.circular(borderRadius),
              ),
              paint,
            );
          case LiquidRoundedRectangle(:final borderRadius):
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                shadowRect,
                Radius.circular(borderRadius),
              ),
              paint,
            );
          case LiquidOval():
            canvas.drawOval(shadowRect, paint);
        }
      }

      canvas.restore();
    }

    super.paint(context, offset);
  }
}
