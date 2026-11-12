import 'package:flutter/widgets.dart';
import 'package:liquid_glass_plus/liquid_glass_plus.dart';
import 'package:meta/meta.dart';

/// Clips its child to a [LiquidShape].
///
/// Compared to a [ClipPath] with a [ShapeBorderClipper], this uses the
/// dedicated clip primitive for each shape ([ClipRSuperellipse], [ClipRRect],
/// [ClipOval]), which is cheaper than clipping to an arbitrary path.
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
    return switch (shape) {
      LiquidRoundedSuperellipse(:final borderRadius) => ClipRSuperellipse(
          clipBehavior: clipBehavior,
          borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
          child: child,
        ),
      LiquidRoundedRectangle(:final borderRadius) => ClipRRect(
          clipBehavior: clipBehavior,
          borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
          child: child,
        ),
      LiquidOval() => ClipOval(
          clipBehavior: clipBehavior,
          child: child,
        ),
    };
  }
}
