// The example's third-party UI packages still build on package:flutter's
// material/cupertino libraries, so it stays on them for now.
// ignore_for_file: deprecated_member_use

import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:leak_tracker/leak_tracker.dart';
import 'package:liquid_glass_plus/liquid_glass_plus.dart';
import 'package:liquid_glass_plus_example/basic_app.dart';
// ignore: depend_on_referenced_packages
export 'package:logging/logging.dart' show Level, Logger;

void main() {
  FlutterMemoryAllocations.instance.addListener(
    (ObjectEvent event) => LeakTracking.dispatchObjectEvent(event.toMap()),
  );
  LeakTracking.start();
  LeakTracking.phase = PhaseSettings(
    leakDiagnosticConfig: LeakDiagnosticConfig(collectStackTraceOnStart: true),
  );
  LgrLogs.initAllLogs(); // Disabled for benchmarking
  runApp(CupertinoApp(home: BasicApp()));
}

final settingsNotifier = ValueNotifier<LiquidGlassSettings>(
  LiquidGlassSettings(
    thickness: 20,
    lightAngle: 0.5 * pi,
    liquidGlassConfigs: LiquidGlassConfigs(chromaticAberration: 1),
  ),
);

final cornerRadiusNotifier = ValueNotifier<double>(100);

final glassColorNotifier = ValueNotifier<Color>(
  const Color.fromARGB(0, 255, 255, 255),
);
