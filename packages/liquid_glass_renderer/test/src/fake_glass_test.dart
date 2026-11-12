// alchemist still builds goldens on package:flutter/material.dart, so the
// tests stay on it instead of material_ui to keep one Theme hierarchy.
// ignore_for_file: deprecated_member_use

import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_plus/liquid_glass_plus.dart';

import 'shared.dart';

/// Fake glass settings with lighting turned off so goldens only show the
/// backdrop filter, the tint and the child.
LiquidGlassSettings fakeSettings({
  double frostIntensity = 0,
  double saturation = 1,
  double refraction = 0,
  Color glassColor = const Color.fromARGB(128, 0, 0, 255),
}) {
  return LiquidGlassSettings(
    thickness: 20,
    frostIntensity: frostIntensity,
    saturation: saturation,
    lightIntensity: 0,
    ambientStrength: 0,
    glassColor: glassColor,
    fakeGlassConfigs: FakeGlassConfigs(
      forceEnabled: true,
      refraction: refraction,
    ),
  );
}

Widget fakeGlass(LiquidGlassSettings settings, {Widget? child}) {
  return LiquidGlass.withOwnLayer(
    settings: settings,
    shape: const LiquidRoundedSuperellipse(borderRadius: 40),
    child: SizedBox.square(dimension: 300, child: child),
  );
}

int backdropFilterLayerCount(WidgetTester tester) =>
    tester.layers.whereType<BackdropFilterLayer>().length;

void main() {
  group('Fake glass', () {
    group('backdrop filter layer', () {
      Widget build(LiquidGlassSettings settings) => Directionality(
            textDirection: TextDirection.ltr,
            child: Center(child: fakeGlass(settings)),
          );

      testWidgets('is skipped when the filter has no effect', (tester) async {
        await tester.pumpWidget(build(fakeSettings()));
        await tester.pump();
        expect(backdropFilterLayerCount(tester), 0);
      });

      testWidgets('is used for blur', (tester) async {
        await tester.pumpWidget(build(fakeSettings(frostIntensity: 5)));
        await tester.pump();
        expect(backdropFilterLayerCount(tester), 1);
      });

      testWidgets('is used for a saturation change', (tester) async {
        await tester.pumpWidget(build(fakeSettings(saturation: 1.5)));
        await tester.pump();
        expect(backdropFilterLayerCount(tester), 1);
      });

      testWidgets('is used for refraction', (tester) async {
        await tester.pumpWidget(build(fakeSettings(refraction: 5)));
        await tester.pump();
        expect(backdropFilterLayerCount(tester), 1);
      });

      testWidgets('comes back when an effect is turned on', (tester) async {
        await tester.pumpWidget(build(fakeSettings()));
        await tester.pump();
        expect(backdropFilterLayerCount(tester), 0);

        await tester.pumpWidget(build(fakeSettings(frostIntensity: 5)));
        await tester.pumpAndSettle();
        expect(backdropFilterLayerCount(tester), 1);
      });
    });

    goldenTest(
      'renders with zero blur',
      skip: skipPlatformGoldens,
      fileName: 'fake_glass_zero_blur',
      pumpBeforeTest: pumpOnce,
      builder: () => GoldenTestGroup(
        scenarioConstraints: testScenarioConstraints,
        children: [
          GoldenTestScenario(
            name: 'no backdrop effect, glass color',
            child: buildWithGridPaper(fakeGlass(fakeSettings())),
          ),
          GoldenTestScenario(
            name: 'no backdrop effect, child content',
            child: buildWithGridPaper(
              fakeGlass(
                fakeSettings(glassColor: const Color(0x00FFFFFF)),
                child: const ColoredBox(color: Colors.red),
              ),
            ),
          ),
          GoldenTestScenario(
            name: 'zero blur, saturation 1.5',
            child: buildWithGridPaper(
              fakeGlass(fakeSettings(saturation: 1.5)),
            ),
          ),
          GoldenTestScenario(
            name: 'zero blur, refraction 5',
            child: buildWithGridPaper(
              fakeGlass(fakeSettings(refraction: 5)),
            ),
          ),
          GoldenTestScenario(
            name: 'blur 5',
            child: buildWithGridPaper(
              fakeGlass(fakeSettings(frostIntensity: 5)),
            ),
          ),
        ],
      ),
    );
  });
}
