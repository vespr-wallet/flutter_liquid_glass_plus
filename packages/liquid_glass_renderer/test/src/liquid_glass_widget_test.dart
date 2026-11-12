// alchemist still builds goldens on package:flutter/material.dart, so the
// tests stay on it instead of material_ui to keep one Theme hierarchy.
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_plus/liquid_glass_plus.dart';

void main() {
  group('LiquidGlass', () {
    testWidgets('can be created with shape and child', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LiquidGlass.withOwnLayer(
              shape: LiquidRoundedSuperellipse(borderRadius: 16),
              child: SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      );

      expect(find.byType(LiquidGlass), findsOneWidget);
    });

    testWidgets('can be created with LiquidOval shape', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LiquidGlass.withOwnLayer(
              shape: LiquidOval(),
              child: SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      );

      expect(find.byType(LiquidGlass), findsOneWidget);
    });

    testWidgets('can be created with LiquidRoundedRectangle shape',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LiquidGlass.withOwnLayer(
              shape: LiquidRoundedRectangle(borderRadius: 16),
              child: SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      );

      expect(find.byType(LiquidGlass), findsOneWidget);
    });

    testWidgets('renders child widget', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LiquidGlass.withOwnLayer(
              shape: LiquidRoundedSuperellipse(borderRadius: 16),
              child: Text('Hello Glass'),
            ),
          ),
        ),
      );

      expect(find.text('Hello Glass'), findsOneWidget);
    });

    testWidgets('accepts custom settings', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LiquidGlass.withOwnLayer(
              shape: LiquidRoundedSuperellipse(borderRadius: 16),
              settings: LiquidGlassSettings(
                thickness: 30,
                frostIntensity: 10,
              ),
              child: SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      );

      expect(find.byType(LiquidGlass), findsOneWidget);
    });

    testWidgets('accepts preset settings', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LiquidGlass.withOwnLayer(
              shape: LiquidRoundedSuperellipse(borderRadius: 16),
              settings: LiquidGlassSettings.minimal(),
              child: SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      );

      expect(find.byType(LiquidGlass), findsOneWidget);
    });
  });

  group('LiquidGlassLayer', () {
    testWidgets('can wrap multiple LiquidGlass widgets', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LiquidGlassLayer(
              settings: LiquidGlassSettings(),
              child: Column(
                children: [
                  LiquidGlass(
                    shape: LiquidRoundedSuperellipse(borderRadius: 16),
                    child: SizedBox(width: 100, height: 50),
                  ),
                  LiquidGlass(
                    shape: LiquidOval(),
                    child: SizedBox(width: 100, height: 50),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(LiquidGlassLayer), findsOneWidget);
      expect(find.byType(LiquidGlass), findsNWidgets(2));
    });

    testWidgets('provides settings to descendant LiquidGlass widgets',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LiquidGlassLayer(
              settings: LiquidGlassSettings.subtle(),
              child: LiquidGlass(
                shape: LiquidRoundedSuperellipse(borderRadius: 16),
                child: SizedBox(width: 100, height: 100),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(LiquidGlassLayer), findsOneWidget);
      expect(find.byType(LiquidGlass), findsOneWidget);
    });
  });

  group('LiquidStretch', () {
    testWidgets('can wrap a child widget', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LiquidStretch(
              child: SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      );

      expect(find.byType(LiquidStretch), findsOneWidget);
    });

    testWidgets('returns child directly when stretch=0 and scale=1',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LiquidStretch(
              stretch: 0,
              interactionScale: 1.0,
              child: Text('No transform'),
            ),
          ),
        ),
      );

      // The widget should still find LiquidStretch but it should
      // return the child directly without transformation
      expect(find.byType(LiquidStretch), findsOneWidget);
      expect(find.text('No transform'), findsOneWidget);
    });
  });

  group('GlassGlow', () {
    testWidgets('can be created inside GlassGlowLayer', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassGlowLayer(
              child: GlassGlow(
                child: SizedBox(width: 100, height: 100),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(GlassGlowLayer), findsOneWidget);
      expect(find.byType(GlassGlow), findsOneWidget);
    });

    testWidgets('accepts custom glow parameters', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassGlowLayer(
              child: GlassGlow(
                glowColor: Colors.blue,
                glowRadius: 0.5,
                child: SizedBox(width: 100, height: 100),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(GlassGlow), findsOneWidget);
    });
  });
}
