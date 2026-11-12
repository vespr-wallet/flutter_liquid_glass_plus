// alchemist still builds goldens on package:flutter/material.dart, so the
// tests stay on it instead of material_ui to keep one Theme hierarchy.
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_plus/liquid_glass_plus.dart';

void main() {
  group('LiquidRoundedSuperellipse', () {
    test('creates with required borderRadius', () {
      const shape = LiquidRoundedSuperellipse(borderRadius: 16);
      expect(shape.borderRadius, 16);
    });

    test('creates path from getOuterPath', () {
      const shape = LiquidRoundedSuperellipse(borderRadius: 16);
      final path = shape.getOuterPath(const Rect.fromLTWH(0, 0, 100, 100));
      expect(path, isA<Path>());
    });

    test('creates inner path', () {
      const shape = LiquidRoundedSuperellipse(borderRadius: 16);
      final path = shape.getInnerPath(const Rect.fromLTWH(0, 0, 100, 100));
      expect(path, isA<Path>());
    });

    test('copyWith creates copy with modified values', () {
      const original = LiquidRoundedSuperellipse(borderRadius: 16);
      final copy = original.copyWith(borderRadius: 32);

      expect(copy.borderRadius, 32);
    });

    test('copyWith preserves values when not specified', () {
      const original = LiquidRoundedSuperellipse(
        borderRadius: 16,
        side: BorderSide(color: Colors.red),
      );
      final copy = original.copyWith();

      expect(copy.borderRadius, 16);
      expect(copy.side, const BorderSide(color: Colors.red));
    });

    test('scale multiplies borderRadius', () {
      const shape = LiquidRoundedSuperellipse(borderRadius: 16);
      final scaled = shape.scale(2) as LiquidRoundedSuperellipse;

      expect(scaled.borderRadius, 32);
    });

    test('equality works correctly', () {
      const a = LiquidRoundedSuperellipse(borderRadius: 16);
      const b = LiquidRoundedSuperellipse(borderRadius: 16);
      const c = LiquidRoundedSuperellipse(borderRadius: 32);

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });

  group('LiquidRoundedRectangle', () {
    test('creates with required borderRadius', () {
      const shape = LiquidRoundedRectangle(borderRadius: 16);
      expect(shape.borderRadius, 16);
    });

    test('creates path from getOuterPath', () {
      const shape = LiquidRoundedRectangle(borderRadius: 16);
      final path = shape.getOuterPath(const Rect.fromLTWH(0, 0, 100, 100));
      expect(path, isA<Path>());
    });

    test('copyWith creates copy with modified values', () {
      const original = LiquidRoundedRectangle(borderRadius: 16);
      final copy = original.copyWith(borderRadius: 32);

      expect(copy.borderRadius, 32);
    });

    test('scale multiplies borderRadius', () {
      const shape = LiquidRoundedRectangle(borderRadius: 16);
      final scaled = shape.scale(2) as LiquidRoundedRectangle;

      expect(scaled.borderRadius, 32);
    });

    test('equality works correctly', () {
      const a = LiquidRoundedRectangle(borderRadius: 16);
      const b = LiquidRoundedRectangle(borderRadius: 16);
      const c = LiquidRoundedRectangle(borderRadius: 32);

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });

  group('LiquidOval', () {
    test('creates with default side', () {
      const shape = LiquidOval();
      expect(shape.side, BorderSide.none);
    });

    test('creates path from getOuterPath', () {
      const shape = LiquidOval();
      final path = shape.getOuterPath(const Rect.fromLTWH(0, 0, 100, 100));
      expect(path, isA<Path>());
    });

    test('copyWith creates copy with modified side', () {
      const original = LiquidOval();
      final copy = original.copyWith(side: const BorderSide(color: Colors.red));

      expect(copy.side, const BorderSide(color: Colors.red));
    });

    test('equality works correctly', () {
      const a = LiquidOval();
      const b = LiquidOval();
      const c = LiquidOval(side: BorderSide(color: Colors.red));

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });

  group('LiquidShape.lerp', () {
    test('returns null when both are null', () {
      final result = LiquidShape.lerp(null, null, 0.5);
      expect(result, isNull);
    });

    test('returns b when a is null', () {
      const b = LiquidRoundedSuperellipse(borderRadius: 16);
      final result = LiquidShape.lerp(null, b, 0.5);
      expect(result, equals(b));
    });

    test('returns a when b is null', () {
      const a = LiquidRoundedSuperellipse(borderRadius: 16);
      final result = LiquidShape.lerp(a, null, 0.5);
      expect(result, equals(a));
    });

    test('interpolates same-type LiquidRoundedSuperellipse', () {
      const a = LiquidRoundedSuperellipse(borderRadius: 10);
      const b = LiquidRoundedSuperellipse(borderRadius: 20);

      final result = LiquidShape.lerp(a, b, 0.5)! as LiquidRoundedSuperellipse;

      expect(result.borderRadius, 15);
    });

    test('interpolates same-type LiquidRoundedRectangle', () {
      const a = LiquidRoundedRectangle(borderRadius: 10);
      const b = LiquidRoundedRectangle(borderRadius: 20);

      final result = LiquidShape.lerp(a, b, 0.5)! as LiquidRoundedRectangle;

      expect(result.borderRadius, 15);
    });

    test('returns first shape for t < 0.5 with different types', () {
      const a = LiquidRoundedSuperellipse(borderRadius: 10);
      const b = LiquidOval();

      final result = LiquidShape.lerp(a, b, 0.49);

      expect(result, equals(a));
    });

    test('returns second shape for t >= 0.5 with different types', () {
      const a = LiquidRoundedSuperellipse(borderRadius: 10);
      const b = LiquidOval();

      final result = LiquidShape.lerp(a, b, 0.5);

      expect(result, equals(b));
    });
  });
}
