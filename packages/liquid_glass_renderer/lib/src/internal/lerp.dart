import 'dart:ui';

import 'package:meta/meta.dart';

/// [lerpDouble] for non-null values, with a non-null result.
///
/// Uses the same arithmetic as [lerpDouble], which only returns null when
/// both of its arguments are null.
@internal
double lerpDoubleNonNull(double a, double b, double t) {
  if (a == b || a.isNaN && b.isNaN) return a;
  return a * (1.0 - t) + b * t;
}

/// [Color.lerp] for non-null colors, with a non-null result.
///
/// [Color.lerp] only returns null when both colors are null, so the fallback
/// is unreachable.
@internal
Color lerpColorNonNull(Color a, Color b, double t) => Color.lerp(a, b, t) ?? b;
