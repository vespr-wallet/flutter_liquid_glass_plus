// alchemist still builds goldens on package:flutter/material.dart, so the
// tests stay on it instead of material_ui to keep one Theme hierarchy.
// ignore_for_file: deprecated_member_use

import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_plus/liquid_glass_plus.dart';
import 'package:liquid_glass_plus/src/glass_shadow.dart';

import 'shared.dart';

const _shadows = [
  BoxShadow(
    blurStyle: BlurStyle.outer,
    color: Color(0x40000000),
    blurRadius: 20,
    spreadRadius: 4,
  ),
];

Widget _glass(
  LiquidShape shape, {
  List<BoxShadow> shadows = _shadows,
  LiquidGlassSettings settings = settingsWithoutLighting,
}) {
  return LiquidGlass.withOwnLayer(
    settings: settings.copyWith(thickness: 20),
    shape: shape,
    shadows: shadows,
    child: const SizedBox.square(dimension: 200),
  );
}

Widget _app(Widget child) => Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: child),
    );

void main() {
  group('LiquidGlass clip', () {
    List<Clip> clips(WidgetTester tester) => [
          tester
              .widget<ClipRSuperellipse>(
                find.byWidgetPredicate((w) => w is ClipRSuperellipse),
              )
              .clipBehavior,
          tester.widget<ClipRRect>(find.byType(ClipRRect)).clipBehavior,
        ];

    testWidgets('clips with ClipRSuperellipse for LiquidRoundedSuperellipse',
        (tester) async {
      await tester.pumpWidget(
        _app(_glass(const LiquidRoundedSuperellipse(borderRadius: 30))),
      );
      expect(clips(tester), [Clip.hardEdge, Clip.none]);
      expect(find.byType(ClipPath), findsNothing);
    });

    testWidgets('clips with ClipRRect for LiquidRoundedRectangle',
        (tester) async {
      await tester.pumpWidget(
        _app(_glass(const LiquidRoundedRectangle(borderRadius: 30))),
      );
      expect(clips(tester), [Clip.none, Clip.hardEdge]);
      expect(find.byType(ClipPath), findsNothing);
    });

    testWidgets('clips with an oval ClipRRect for LiquidOval', (tester) async {
      await tester.pumpWidget(_app(_glass(const LiquidOval())));
      expect(clips(tester), [Clip.none, Clip.hardEdge]);
      expect(find.byType(ClipOval), findsNothing);
      expect(find.byType(ClipPath), findsNothing);
      final clip = tester.widget<ClipRRect>(find.byType(ClipRRect));
      expect(
        clip.clipper?.getClip(const Size(200, 100)),
        const RRect.fromLTRBXY(0, 0, 200, 100, 100, 50),
      );
    });

    testWidgets('keeps the clipBehavior', (tester) async {
      await tester.pumpWidget(
        _app(
          const LiquidGlass.withOwnLayer(
            shape: LiquidRoundedRectangle(borderRadius: 30),
            clipBehavior: Clip.antiAlias,
            child: SizedBox.square(dimension: 200),
          ),
        ),
      );
      expect(clips(tester), [Clip.none, Clip.antiAlias]);
    });

    group('hit tests the shape', () {
      Future<int> tapAt(
        WidgetTester tester,
        LiquidShape shape,
        Offset fromTopLeft,
      ) async {
        var taps = 0;
        await tester.pumpWidget(
          _app(
            LiquidGlass.withOwnLayer(
              shape: shape,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => taps++,
                child: const SizedBox.square(dimension: 200),
              ),
            ),
          ),
        );
        await tester.tapAt(
          tester.getTopLeft(find.byType(GestureDetector)) + fromTopLeft,
        );
        return taps;
      }

      for (final (name, shape) in const [
        ('LiquidRoundedRectangle', LiquidRoundedRectangle(borderRadius: 0)),
        (
          'LiquidRoundedSuperellipse',
          LiquidRoundedSuperellipse(borderRadius: 0),
        ),
      ]) {
        testWidgets('$name: a square corner is tappable', (tester) async {
          expect(await tapAt(tester, shape, const Offset(5, 5)), 1);
        });
      }

      testWidgets('LiquidOval: the center is tappable', (tester) async {
        expect(
          await tapAt(tester, const LiquidOval(), const Offset(100, 100)),
          1,
        );
      });

      testWidgets('LiquidOval: a corner outside the oval is not tappable',
          (tester) async {
        expect(await tapAt(tester, const LiquidOval(), const Offset(5, 5)), 0);
      });

      testWidgets('LiquidRoundedSuperellipse: the center is tappable',
          (tester) async {
        expect(
          await tapAt(
            tester,
            const LiquidRoundedSuperellipse(borderRadius: 50),
            const Offset(100, 100),
          ),
          1,
        );
      });

      testWidgets(
          'LiquidRoundedSuperellipse: a corner outside the shape is not '
          'tappable', (tester) async {
        const shape = LiquidRoundedSuperellipse(borderRadius: 50);
        const corner = Offset(5, 5);
        // The corner is inside the bounding rect but outside the shape.
        expect(
          RSuperellipse.fromRectAndRadius(
            Offset.zero & const Size.square(200),
            const Radius.circular(50),
          ).contains(corner),
          isFalse,
        );
        expect(await tapAt(tester, shape, corner), 0);
      });

      testWidgets(
          'LiquidRoundedSuperellipse: a point inside the shape near the '
          'corner is tappable', (tester) async {
        const shape = LiquidRoundedSuperellipse(borderRadius: 50);
        const nearCorner = Offset(25, 25);
        expect(
          RSuperellipse.fromRectAndRadius(
            Offset.zero & const Size.square(200),
            const Radius.circular(50),
          ).contains(nearCorner),
          isTrue,
        );
        expect(await tapAt(tester, shape, nearCorner), 1);
      });

      testWidgets('LiquidRoundedRectangle: a cut corner is not tappable',
          (tester) async {
        expect(
          await tapAt(
            tester,
            const LiquidRoundedRectangle(borderRadius: 50),
            const Offset(5, 5),
          ),
          0,
        );
      });
    });

    testWidgets('keeps the child state when the shape type changes',
        (tester) async {
      var initCount = 0;
      Widget build(LiquidShape shape) => _app(
            LiquidGlass.withOwnLayer(
              shape: shape,
              child: _Stateful(onInit: () => initCount++),
            ),
          );

      await tester.pumpWidget(
        build(const LiquidRoundedRectangle(borderRadius: 30)),
      );
      for (final shape in const [
        LiquidOval(),
        LiquidRoundedSuperellipse(borderRadius: 30),
        LiquidRoundedRectangle(borderRadius: 30),
      ]) {
        await tester.pumpWidget(build(shape));
        // Shape changes animate; settle so the new shape type is built.
        await tester.pumpAndSettle();
        expect(find.byType(_Stateful), findsOneWidget);
      }
      expect(initCount, 1);
    });
  });

  group('LiquidGlass shadows', () {
    testWidgets('paints a superellipse shadow for LiquidRoundedSuperellipse',
        (tester) async {
      await tester.pumpWidget(
        _app(_glass(const LiquidRoundedSuperellipse(borderRadius: 30))),
      );
      expect(
        tester.renderObject(find.byType(GlassShadow)),
        paints..rsuperellipse(),
      );
    });

    testWidgets('paints a rounded rect shadow for LiquidRoundedRectangle',
        (tester) async {
      await tester.pumpWidget(
        _app(_glass(const LiquidRoundedRectangle(borderRadius: 30))),
      );
      expect(tester.renderObject(find.byType(GlassShadow)), paints..rrect());
    });

    testWidgets('paints an oval shadow for LiquidOval', (tester) async {
      await tester.pumpWidget(_app(_glass(const LiquidOval())));
      expect(
        tester.renderObject(find.byType(GlassShadow)),
        paints..something((method, arguments) => method == #drawOval),
      );
    });

    testWidgets('paints one primitive per shadow, inflated by spread',
        (tester) async {
      await tester.pumpWidget(
        _app(
          _glass(
            const LiquidRoundedRectangle(borderRadius: 30),
            shadows: const [
              BoxShadow(spreadRadius: 4),
              BoxShadow(offset: Offset(0, 10), blurRadius: 8),
            ],
          ),
        ),
      );
      final box = tester.renderObject<RenderBox>(find.byType(GlassShadow));
      final rect = Offset.zero & box.size;
      expect(
        box,
        paints
          ..rrect(
            rrect: RRect.fromRectAndRadius(
              rect.inflate(4),
              const Radius.circular(30),
            ),
          )
          ..rrect(
            rrect: RRect.fromRectAndRadius(
              rect.shift(const Offset(0, 10)),
              const Radius.circular(30),
            ),
          ),
      );
    });

    testWidgets('paints nothing without shadows', (tester) async {
      await tester.pumpWidget(
        _app(
          _glass(
            const LiquidRoundedRectangle(borderRadius: 30),
            shadows: const [],
          ),
        ),
      );
      expect(
        tester.renderObject(find.byType(GlassShadow)),
        isNot(paints..rrect()),
      );
    });

    goldenTest(
      'renders shadows around each shape',
      skip: skipPlatformGoldens,
      fileName: 'glass_shadows',
      pumpBeforeTest: pumpOnce,
      builder: () => GoldenTestGroup(
        scenarioConstraints: testScenarioConstraints,
        children: [
          for (final (name, shape) in const [
            ('superellipse', LiquidRoundedSuperellipse(borderRadius: 50)),
            ('rounded rectangle', LiquidRoundedRectangle(borderRadius: 50)),
            ('oval', LiquidOval()),
          ]) ...[
            GoldenTestScenario(
              name: name,
              child: buildWithGridPaper(_glass(shape)),
            ),
            GoldenTestScenario(
              name: '$name, fake glass',
              child: buildWithGridPaper(
                _glass(
                  shape,
                  settings: settingsWithoutLighting.copyWith(
                    fakeGlassConfigs: const FakeGlassConfigs(
                      forceEnabled: true,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  });
}

class _Stateful extends StatefulWidget {
  const _Stateful({required this.onInit});

  final VoidCallback onInit;

  @override
  State<_Stateful> createState() => _StatefulState();
}

class _StatefulState extends State<_Stateful> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.square(dimension: 200);
}
