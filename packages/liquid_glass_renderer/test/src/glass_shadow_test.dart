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
    testWidgets('uses ClipRSuperellipse for LiquidRoundedSuperellipse',
        (tester) async {
      await tester.pumpWidget(
        _app(_glass(const LiquidRoundedSuperellipse(borderRadius: 30))),
      );
      expect(find.byType(ClipRSuperellipse), findsOneWidget);
      expect(find.byType(ClipPath), findsNothing);
    });

    testWidgets('uses ClipRRect for LiquidRoundedRectangle', (tester) async {
      await tester.pumpWidget(
        _app(_glass(const LiquidRoundedRectangle(borderRadius: 30))),
      );
      expect(find.byType(ClipRRect), findsOneWidget);
      expect(find.byType(ClipPath), findsNothing);
    });

    testWidgets('uses ClipOval for LiquidOval', (tester) async {
      await tester.pumpWidget(_app(_glass(const LiquidOval())));
      expect(find.byType(ClipOval), findsOneWidget);
      expect(find.byType(ClipPath), findsNothing);
    });

    testWidgets('keeps the clipBehavior', (tester) async {
      await tester.pumpWidget(
        _app(
          const LiquidGlass.withOwnLayer(
            shape: LiquidRoundedRectangle(borderRadius: 30),
            clipBehavior: Clip.none,
            child: SizedBox.square(dimension: 200),
          ),
        ),
      );
      expect(
        tester.widget<ClipRRect>(find.byType(ClipRRect)).clipBehavior,
        Clip.none,
      );
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
