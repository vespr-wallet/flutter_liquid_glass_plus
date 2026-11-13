import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_plus/src/internal/multi_shader_builder.dart';
import 'package:liquid_glass_plus/src/shaders.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await MultiShaderBuilder.precacheShaders([
    ShaderKeys.blendedGeometry,
    ShaderKeys.liquidGlassRender,
  ]);

  if (goldenFileComparator case final LocalFileComparator comparator) {
    goldenFileComparator = _TolerantGoldenFileComparator(comparator.basedir);
  }

  return AlchemistConfig.runWithConfig(
    config: AlchemistConfig(
      ciGoldensConfig: const CiGoldensConfig(enabled: false),
      platformGoldensConfig: PlatformGoldensConfig(
        platforms: {HostPlatform.macOS},
      ),
    ),
    run: testMain,
  );
}

/// Accepts golden diffs of up to [_tolerance] percent of the pixels.
///
/// GitHub's macOS runners render the goldens with antialiasing differences
/// of up to 0.02% against a local Mac. Real changes seen so far were 0.1% and
/// more.
// ponytail: one global tolerance; a change below it slips through, so lower
// it or make it per test if a real regression ever hides under it.
const _tolerance = 0.05;

class _TolerantGoldenFileComparator extends LocalFileComparator {
  // LocalFileComparator takes a test file and compares against its directory.
  _TolerantGoldenFileComparator(Uri basedir)
      : super(basedir.resolve('flutter_test_config.dart'));

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    try {
      if (result.passed || result.diffPercent * 100 <= _tolerance) {
        return true;
      }
      throw FlutterError(await generateFailureOutput(result, golden, basedir));
    } finally {
      result.dispose();
    }
  }
}
