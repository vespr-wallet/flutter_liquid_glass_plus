// alchemist still builds goldens on package:flutter/material.dart, so the
// tests stay on it instead of material_ui to keep one Theme hierarchy.
// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:liquid_glass_plus/liquid_glass_plus.dart';

/// Pass as `skip:` to every alchemist `goldenTest`.
///
/// The goldens are macOS platform goldens (see `flutter_test_config.dart`).
/// On any other host alchemist has no golden variant to run, and the test
/// file fails to load (`variant.values.isNotEmpty`) even with
/// `--exclude-tags=golden`, taking the file's other tests down with it.
final skipPlatformGoldens = !Platform.isMacOS;

final testScenarioConstraints = BoxConstraints.tight(const Size(500, 500));

const settingsWithoutLighting = LiquidGlassSettings(
  lightIntensity: 0,
  frostIntensity: 0,
  liquidGlassConfigs: LiquidGlassConfigs(
    chromaticAberration: 0,
  ),
);

Widget buildWithGridPaper(Widget child) {
  return ColoredBox(
    color: Colors.white,
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          const Positioned.fill(
            child: GridPaper(
              color: Colors.black,
            ),
          ),
          Center(
            child: child,
          ),
        ],
      ),
    ),
  );
}
