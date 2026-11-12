import 'dart:math' as math;

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

      Widget buildCombo({
        required bool stretchOutside,
        Widget? child,
        Widget Function(Widget inner)? between,
      }) {
        final content =
            child ?? const SizedBox(key: childKey, width: 100, height: 100);
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
                  ? stretch((between ?? (w) => w)(glow(content)))
                  : glow((between ?? (w) => w)(stretch(content))),
            ),
          ),
        );
      }

      for (final stretchOutside in [true, false]) {
        final nesting =
            stretchOutside ? 'stretch around glow' : 'glow around stretch';

        testWidgets('$nesting: a drag drives both effects', (tester) async {
          await tester.pumpWidget(buildCombo(stretchOutside: stretchOutside));

          final gesture =
              await tester.startGesture(tester.getCenter(find.byKey(childKey)));
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

        Widget padded(Widget inner) =>
            Padding(padding: const EdgeInsets.all(50), child: inner);

        // A competing tap keeps the arena open until the pan crosses the
        // slop, so the pan wins away from where the pointer went down.
        final tappable = GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {},
          child: const SizedBox(key: childKey, width: 100, height: 100),
        );

        bool innerActive(WidgetTester tester) => stretchOutside
            ? hasActiveTouch(tester)
            : childSize(tester).width > 100;

        testWidgets(
            '$nesting: the inner effect follows a pan that leaves it '
            'before winning', (tester) async {
          await tester.pumpWidget(
            buildCombo(
              stretchOutside: stretchOutside,
              between: padded,
              child: tappable,
            ),
          );

          // Down 5px inside the inner region's right edge. The pan wins after
          // the pointer has already left the inner region.
          final gesture = await tester.startGesture(
            tester.getRect(find.byKey(childKey)).centerRight -
                const Offset(5, 0),
          );
          await gesture.moveBy(const Offset(40, 0));
          await tester.pump();
          await gesture.moveBy(const Offset(100, 0));
          await tester.pumpAndSettle();

          expect(innerActive(tester), isTrue);

          await gesture.up();
          await tester.pumpAndSettle();
        });

        testWidgets(
            '$nesting: the inner effect ignores a pan that starts outside it',
            (tester) async {
          await tester.pumpWidget(
            buildCombo(
              stretchOutside: stretchOutside,
              between: (inner) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
                child: padded(inner),
              ),
              child: tappable,
            ),
          );

          // Down in the padding, then move onto the inner region before the
          // pan wins.
          final gesture = await tester.startGesture(
            tester.getRect(find.byKey(childKey)).centerLeft -
                const Offset(25, 0),
          );
          await gesture.moveBy(const Offset(45, 0));
          await tester.pump();
          await gesture.moveBy(const Offset(10, 0));
          await tester.pumpAndSettle();

          expect(innerActive(tester), isFalse);

          await gesture.up();
          await tester.pumpAndSettle();
        });

        testWidgets('$nesting: can handle unmount while dragging',
            (tester) async {
          await tester.pumpWidget(buildCombo(stretchOutside: stretchOutside));

          final gesture =
              await tester.startGesture(tester.getCenter(find.byKey(childKey)));
          await gesture.moveBy(const Offset(200, 0));
          await tester.pumpAndSettle();

          await tester.pumpWidget(const SizedBox());
          await gesture.moveBy(const Offset(10, 0));
          await gesture.up();
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
        });
      }

      testWidgets(
          'glow around stretch: the stretch follows the drag direction '
          'through a rotation', (tester) async {
        await tester.pumpWidget(
          buildCombo(
            stretchOutside: false,
            between: (inner) =>
                Transform.rotate(angle: math.pi / 2, child: inner),
          ),
        );

        final gesture =
            await tester.startGesture(tester.getCenter(find.byKey(childKey)));
        await gesture.moveBy(const Offset(200, 0));
        await tester.pumpAndSettle();

        // A horizontal drag on screen stretches the child horizontally on
        // screen, even though the stretch's own axes are rotated.
        final size = childSize(tester);
        expect(size.width, greaterThan(size.height));

        await gesture.up();
        await tester.pumpAndSettle();
      });
    });
  });
}
