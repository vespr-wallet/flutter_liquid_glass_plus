import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:liquid_glass_plus/liquid_glass_plus.dart';
import 'package:meta/meta.dart';

/// Clips its child to a [LiquidShape].
///
/// Compared to a [ClipPath] with a [ShapeBorderClipper], this uses the
/// dedicated clip primitive for each shape, which is cheaper than clipping to
/// an arbitrary path: [ClipRSuperellipse] for superellipses, and [ClipRRect]
/// for rounded rectangles and ovals (an oval is a rounded rect with
/// elliptical radii of half its size).
///
/// Both clips are always built, nested, so a change of shape type doesn't
/// remount [child] and reset its state. Only the clip matching [shape] gets a
/// clipper, which also limits hit testing to the exact shape, as the
/// [ClipPath] did. The other one has no clipper and [Clip.none], so it
/// neither clips nor filters hits.
///
/// [RenderClipRSuperellipse] only hit tests against the bounding rect of its
/// superellipse, so the superellipse clip overrides it to test the exact
/// shape; painting still uses the cheap primitive clip.
@internal
class OptimizedClip extends StatelessWidget {
  const OptimizedClip({
    required this.shape,
    required this.child,
    this.clipBehavior = Clip.antiAlias,
    super.key,
  });

  final LiquidShape shape;

  final Clip clipBehavior;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final shape = this.shape;
    return _ClipRSuperellipseWithExactHitTest(
      clipper: switch (shape) {
        LiquidRoundedSuperellipse(:final borderRadius) =>
          _RSuperellipseClipper(borderRadius),
        _ => null,
      },
      clipBehavior:
          shape is LiquidRoundedSuperellipse ? clipBehavior : Clip.none,
      child: ClipRRect(
        clipper: switch (shape) {
          LiquidRoundedSuperellipse() => null,
          LiquidRoundedRectangle(:final borderRadius) =>
            _RRectClipper(borderRadius),
          LiquidOval() => const _RRectClipper(null),
        },
        clipBehavior:
            shape is LiquidRoundedSuperellipse ? Clip.none : clipBehavior,
        child: child,
      ),
    );
  }
}

/// A [ClipRSuperellipse] whose hit testing follows the superellipse itself
/// instead of its bounding rect.
class _ClipRSuperellipseWithExactHitTest extends ClipRSuperellipse {
  const _ClipRSuperellipseWithExactHitTest({
    super.clipper,
    super.clipBehavior,
    super.child,
  });

  @override
  RenderClipRSuperellipse createRenderObject(BuildContext context) {
    return _RenderClipRSuperellipseWithExactHitTest(
      borderRadius: borderRadius,
      clipBehavior: clipBehavior,
      clipper: clipper,
      textDirection: Directionality.maybeOf(context),
    );
  }
}

class _RenderClipRSuperellipseWithExactHitTest extends RenderClipRSuperellipse {
  _RenderClipRSuperellipseWithExactHitTest({
    super.borderRadius,
    super.clipBehavior,
    super.clipper,
    super.textDirection,
  });

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final clipper = this.clipper;
    if (clipper != null && !clipper.getClip(size).contains(position)) {
      return false;
    }
    return super.hitTest(result, position: position);
  }
}

class _RSuperellipseClipper extends CustomClipper<RSuperellipse> {
  const _RSuperellipseClipper(this.radius);

  final double radius;

  @override
  RSuperellipse getClip(Size size) => RSuperellipse.fromRectAndRadius(
        Offset.zero & size,
        Radius.circular(radius),
      );

  @override
  bool shouldReclip(_RSuperellipseClipper oldClipper) =>
      oldClipper.radius != radius;
}

class _RRectClipper extends CustomClipper<RRect> {
  /// Clips to a rounded rect with [radius], or to an oval when [radius] is
  /// null.
  const _RRectClipper(this.radius);

  final double? radius;

  @override
  RRect getClip(Size size) {
    final rect = Offset.zero & size;
    return switch (radius) {
      final radius? => RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      null => RRect.fromRectXY(rect, size.width / 2, size.height / 2),
    };
  }

  @override
  bool shouldReclip(_RRectClipper oldClipper) => oldClipper.radius != radius;
}
