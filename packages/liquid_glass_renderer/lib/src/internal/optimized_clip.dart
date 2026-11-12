import 'package:flutter/widgets.dart';
import 'package:liquid_glass_plus/liquid_glass_plus.dart';
import 'package:meta/meta.dart';

/// Clips its child to a [LiquidShape].
///
/// Compared to a [ClipPath] with a [ShapeBorderClipper], this uses the
/// dedicated clip primitive for each shape ([ClipRSuperellipse], [ClipRRect],
/// [ClipOval]), which is cheaper than clipping to an arbitrary path.
///
/// All three clips are always built, nested, and only the one matching
/// [shape] clips; the others use [Clip.none], which pushes no layer and
/// doesn't affect hit testing. Keeping the same widgets means a change of
/// shape type doesn't remount [child] and reset its state.
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
    return ClipRSuperellipse(
      clipBehavior:
          shape is LiquidRoundedSuperellipse ? clipBehavior : Clip.none,
      borderRadius: switch (shape) {
        LiquidRoundedSuperellipse(:final borderRadius) =>
          BorderRadius.all(Radius.circular(borderRadius)),
        _ => BorderRadius.zero,
      },
      child: ClipRRect(
        clipBehavior:
            shape is LiquidRoundedRectangle ? clipBehavior : Clip.none,
        borderRadius: switch (shape) {
          LiquidRoundedRectangle(:final borderRadius) =>
            BorderRadius.all(Radius.circular(borderRadius)),
          _ => BorderRadius.zero,
        },
        child: ClipOval(
          clipBehavior: shape is LiquidOval ? clipBehavior : Clip.none,
          child: child,
        ),
      ),
    );
  }
}
