import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_plus/liquid_glass_plus.dart';

void main() {
  group('$LiquidStretch', () {
    const childKey = Key('child');
    const buttonKey = Key('button');

    Widget build({
      GestureMode gestureMode = GestureMode.listener,
      Widget? child,
    }) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: LiquidStretch(
            interactionScale: 1,
            gestureMode: gestureMode,
            child: child ??
                const SizedBox(
                  key: childKey,
                  width: 100,
                  height: 100,
                ),
          ),
        ),
      );
    }

    Size transformedSize(WidgetTester tester) {
      final ro = tester.renderObject<RenderBox>(find.byKey(childKey));
      return MatrixUtils.transformRect(ro.getTransformTo(null), ro.paintBounds)
          .size;
    }

    group('stretching', () {
      testWidgets(
          'elongates horizontally and compresses vertically on horizontal drag',
          (tester) async {
        await tester.pumpWidget(build());

        expect(
          transformedSize(tester),
          const Size(100, 100),
          reason: 'The child should not be transformed before the gesture.',
        );

        final gesture =
            await tester.startGesture(tester.getCenter(find.byKey(childKey)));
        await gesture.moveBy(const Offset(200, 0));
        await tester.pumpAndSettle();

        final stretchedSize = transformedSize(tester);
        expect(stretchedSize.width, greaterThan(100));
        expect(stretchedSize.height, lessThan(100));

        await gesture.up();
        await tester.pumpAndSettle();

        expect(transformedSize(tester), const Size(100, 100));
      });

      testWidgets('can handle unmount while dragging', (tester) async {
        await tester.pumpWidget(build());

        final gesture =
            await tester.startGesture(tester.getCenter(find.byKey(childKey)));
        await gesture.moveBy(const Offset(200, 0));
        await tester.pumpAndSettle();

        // Remove the widget while the pointer is still down. The remaining
        // pointer events are still routed to the removed Listener, which used
        // to call setState on the disposed state and throw.
        await tester.pumpWidget(const SizedBox());
        await gesture.moveBy(const Offset(10, 0));
        await gesture.up();
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });

      testWidgets('resets when the pointer is cancelled', (tester) async {
        await tester.pumpWidget(build());

        final gesture =
            await tester.startGesture(tester.getCenter(find.byKey(childKey)));
        await gesture.moveBy(const Offset(200, 0));
        await tester.pumpAndSettle();
        expect(transformedSize(tester).width, greaterThan(100));

        await gesture.cancel();
        await tester.pumpAndSettle();

        expect(transformedSize(tester), const Size(100, 100));
      });
    });

    group('gesture modes', () {
      testWidgets('gestureDetector mode allows a nested tap to win',
          (tester) async {
        var tapCount = 0;

        await tester.pumpWidget(
          build(
            gestureMode: GestureMode.gestureDetector,
            child: GestureDetector(
              key: buttonKey,
              behavior: HitTestBehavior.opaque,
              onTap: () => tapCount++,
              child: const SizedBox(key: childKey, width: 100, height: 100),
            ),
          ),
        );

        await tester.tap(find.byKey(buttonKey));
        await tester.pumpAndSettle();

        expect(tapCount, 1);
        expect(transformedSize(tester), const Size(100, 100));
      });

      testWidgets('gestureDetector mode stretches once the pan wins',
          (tester) async {
        await tester.pumpWidget(
          build(gestureMode: GestureMode.gestureDetector),
        );

        final gesture =
            await tester.startGesture(tester.getCenter(find.byKey(childKey)));
        await gesture.moveBy(const Offset(200, 0));
        await tester.pumpAndSettle();
        expect(transformedSize(tester).width, greaterThan(100));

        await gesture.up();
        await tester.pumpAndSettle();
        expect(transformedSize(tester), const Size(100, 100));
      });

      testWidgets('gestureDetector mode can handle unmount while dragging',
          (tester) async {
        await tester.pumpWidget(
          build(gestureMode: GestureMode.gestureDetector),
        );

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
    });
  });
}
