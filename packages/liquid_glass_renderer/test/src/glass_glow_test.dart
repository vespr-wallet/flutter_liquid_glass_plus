import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_plus/liquid_glass_plus.dart';
import 'package:liquid_glass_plus/src/glass_glow.dart' show GlassGlowLayerState;

void main() {
  group('$GlassGlow', () {
    const childKey = Key('child');
    const buttonKey = Key('button');

    Widget build({required GestureMode gestureMode, required Widget child}) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: GlassGlowLayer(
            child: GlassGlow(gestureMode: gestureMode, child: child),
          ),
        ),
      );
    }

    bool hasActiveTouch(WidgetTester tester) => tester
        .state<GlassGlowLayerState>(find.byType(GlassGlowLayer))
        .hasActiveTouch;

    group('gesture modes', () {
      testWidgets('listener mode glows on pointer down', (tester) async {
        await tester.pumpWidget(
          build(
            gestureMode: GestureMode.listener,
            child: const SizedBox(key: childKey, width: 100, height: 100),
          ),
        );

        final gesture =
            await tester.startGesture(tester.getCenter(find.byKey(childKey)));
        await tester.pump();
        expect(hasActiveTouch(tester), isTrue);

        await gesture.up();
        await tester.pumpAndSettle();
        expect(hasActiveTouch(tester), isFalse);
      });

      testWidgets('listener mode glows even when a nested tap wins',
          (tester) async {
        var tapCount = 0;
        await tester.pumpWidget(
          build(
            gestureMode: GestureMode.listener,
            child: GestureDetector(
              key: buttonKey,
              behavior: HitTestBehavior.opaque,
              onTap: () => tapCount++,
              child: const SizedBox(width: 100, height: 100),
            ),
          ),
        );

        final gesture =
            await tester.startGesture(tester.getCenter(find.byKey(buttonKey)));
        await tester.pump();
        expect(hasActiveTouch(tester), isTrue);

        await gesture.up();
        await tester.pumpAndSettle();
        expect(tapCount, 1);
        expect(hasActiveTouch(tester), isFalse);
      });

      testWidgets('gestureDetector mode does not glow when a nested tap wins',
          (tester) async {
        var tapCount = 0;
        await tester.pumpWidget(
          build(
            gestureMode: GestureMode.gestureDetector,
            child: GestureDetector(
              key: buttonKey,
              behavior: HitTestBehavior.opaque,
              onTap: () => tapCount++,
              child: const SizedBox(width: 100, height: 100),
            ),
          ),
        );

        final gesture =
            await tester.startGesture(tester.getCenter(find.byKey(buttonKey)));
        await tester.pump(const Duration(milliseconds: 100));
        expect(hasActiveTouch(tester), isFalse);

        await gesture.up();
        await tester.pumpAndSettle();
        expect(tapCount, 1);
        expect(hasActiveTouch(tester), isFalse);
      });

      testWidgets('gestureDetector mode glows once the pan wins',
          (tester) async {
        await tester.pumpWidget(
          build(
            gestureMode: GestureMode.gestureDetector,
            child: const SizedBox(key: childKey, width: 100, height: 100),
          ),
        );

        final gesture =
            await tester.startGesture(tester.getCenter(find.byKey(childKey)));
        await gesture.moveBy(const Offset(50, 0));
        await tester.pump();
        expect(hasActiveTouch(tester), isTrue);

        await gesture.up();
        await tester.pumpAndSettle();
        expect(hasActiveTouch(tester), isFalse);
      });
    });

    group('combined with LiquidStretch in gestureDetector mode', () {
      Size childSize(WidgetTester tester) {
        final ro = tester.renderObject<RenderBox>(find.byKey(childKey));
        return MatrixUtils.transformRect(
          ro.getTransformTo(null),
          ro.paintBounds,
        ).size;
      }

      Widget buildCombo({required bool stretchOutside, Widget? child}) {
        final content = child ??
            const SizedBox(key: childKey, width: 100, height: 100);
        Widget stretch(Widget child) => LiquidStretch(
              interactionScale: 1,
              gestureMode: GestureMode.gestureDetector,
              child: child,
            );
        Widget glow(Widget child) => GlassGlow(
              gestureMode: GestureMode.gestureDetector,
              child: child,
            );
        return Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: GlassGlowLayer(
              child: stretchOutside
                  ? stretch(glow(content))
                  : glow(stretch(content)),
            ),
          ),
        );
      }

      for (final stretchOutside in [true, false]) {
        final nesting =
            stretchOutside ? 'stretch around glow' : 'glow around stretch';

        testWidgets('$nesting: a drag drives both effects', (tester) async {
          await tester.pumpWidget(buildCombo(stretchOutside: stretchOutside));

          final gesture = await tester
              .startGesture(tester.getCenter(find.byKey(childKey)));
          await gesture.moveBy(const Offset(200, 0));
          await tester.pumpAndSettle();

          expect(hasActiveTouch(tester), isTrue);
          expect(childSize(tester).width, greaterThan(100));

          await gesture.up();
          await tester.pumpAndSettle();

          expect(hasActiveTouch(tester), isFalse);
          expect(childSize(tester), const Size(100, 100));
        });

        testWidgets('$nesting: a nested tap suppresses both effects',
            (tester) async {
          var tapCount = 0;
          await tester.pumpWidget(
            buildCombo(
              stretchOutside: stretchOutside,
              child: GestureDetector(
                key: buttonKey,
                behavior: HitTestBehavior.opaque,
                onTap: () => tapCount++,
                child: const SizedBox(key: childKey, width: 100, height: 100),
              ),
            ),
          );

          final gesture = await tester
              .startGesture(tester.getCenter(find.byKey(buttonKey)));
          await tester.pump(const Duration(milliseconds: 100));
          expect(hasActiveTouch(tester), isFalse);
          expect(childSize(tester), const Size(100, 100));

          await gesture.up();
          await tester.pumpAndSettle();
          expect(tapCount, 1);
        });

        testWidgets('$nesting: can handle unmount while dragging',
            (tester) async {
          await tester.pumpWidget(buildCombo(stretchOutside: stretchOutside));

          final gesture = await tester
              .startGesture(tester.getCenter(find.byKey(childKey)));
          await gesture.moveBy(const Offset(200, 0));
          await tester.pumpAndSettle();

          await tester.pumpWidget(const SizedBox());
          await gesture.moveBy(const Offset(10, 0));
          await gesture.up();
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
        });
      }
    });
  });
}
