// The example's third-party UI packages still build on package:flutter's
// material/cupertino libraries, so it stays on them for now.
// ignore_for_file: deprecated_member_use

import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:liquid_glass_plus/liquid_glass_plus.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';

Animation<double> useRotatingAnimationController() {
  return useAnimationController(
    duration: const Duration(seconds: 5),
    lowerBound: 0,
    upperBound: 2 * pi,
  )..repeat();
}

class VerticalStripes extends StatelessWidget {
  const VerticalStripes({super.key, this.stripeThickness = 100.0});

  final double stripeThickness;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _VerticalStripesPainter(stripeThickness: stripeThickness),
      size: Size.infinite,
    );
  }
}

class _VerticalStripesPainter extends CustomPainter {
  const _VerticalStripesPainter({required this.stripeThickness});

  final double stripeThickness;

  @override
  void paint(Canvas canvas, Size size) {
    final blackPaint = Paint()..color = Colors.black;
    final whitePaint = Paint()..color = Colors.white;

    double currentX = 0;
    bool isBlack = true;

    while (currentX < size.width) {
      final rect = Rect.fromLTWH(currentX, 0, stripeThickness, size.height);

      canvas.drawRect(rect, isBlack ? blackPaint : whitePaint);

      currentX += stripeThickness;
      isBlack = !isBlack;
    }
  }

  @override
  bool shouldRepaint(covariant _VerticalStripesPainter oldDelegate) {
    return oldDelegate.stripeThickness != stripeThickness;
  }
}

class ImagePageView extends HookWidget {
  const ImagePageView({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PageView.builder(
          itemBuilder: (context, index) {
            return switch (index) {
              <= 0 => Image.asset('assets/wallpaper.webp', fit: BoxFit.cover),
              1 => const Grid(),
              2 => const VerticalStripes(),
              _ => LayoutBuilder(
                builder: (context, constraints) => Image.network(
                  'https://picsum.photos/2000/2000?random=$index',
                  fit: BoxFit.cover,
                ),
              ),
            };
          },
        ),
        child,
      ],
    );
  }
}

class SettingsSheet extends HookWidget {
  const SettingsSheet({
    super.key,
    required this.settingsNotifier,
    required this.lightAngleAnimation,
  });

  final ValueNotifier<LiquidGlassSettings> settingsNotifier;

  final Animation<double> lightAngleAnimation;

  Future<void> show(BuildContext context) {
    return Navigator.push(
      context,
      StupidSimpleSheetRoute(barrierColor: Colors.black26, child: this),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = useValueListenable(settingsNotifier);
    final lightAngle = useValueListenable(lightAngleAnimation);

    return LiquidStretch(
      interactionScale: 1.005,
      stretch: .1,
      child: SafeArea(
        minimum: const EdgeInsets.all(16.0),
        child: LiquidGlass.withOwnLayer(
          settings: LiquidGlassSettings.figma(
            depth: 50,
            refraction: 100,
            lightAngle: lightAngle,
            dispersion: 4,
            frost: 2,
            glassColor: Theme.of(
              context,
            ).colorScheme.surface.withValues(alpha: 0.8),
          ),
          shape: LiquidRoundedSuperellipse(borderRadius: 32),
          child: GlassGlow(
            child: DefaultTextStyle(
              style: Theme.of(context).textTheme.bodyLarge!,
              child: Align(
                alignment: Alignment.topCenter,
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Settings',
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Thickness:'),
                            Text(settings.thickness.toStringAsFixed(2)),
                          ],
                        ),
                        CupertinoSlider(
                          value: settings.thickness,
                          onChanged: (value) {
                            settingsNotifier.value = settings.copyWith(
                              thickness: value,
                            );
                          },
                          min: 0,
                          max: 160,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Light Intensity:'),
                            Text(settings.lightIntensity.toStringAsFixed(2)),
                          ],
                        ),
                        CupertinoSlider(
                          value: settings.lightIntensity,
                          onChanged: (value) {
                            settingsNotifier.value = settings.copyWith(
                              lightIntensity: value,
                            );
                          },
                          min: 0,
                          max: 5,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Ambient Strength:'),
                            Text(settings.ambientStrength.toStringAsFixed(2)),
                          ],
                        ),
                        CupertinoSlider(
                          value: settings.ambientStrength,
                          onChanged: (value) {
                            settingsNotifier.value = settings.copyWith(
                              ambientStrength: value,
                            );
                          },
                          min: 0,
                          max: 5,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Frost Intensity:'),
                            Text(settings.frostIntensity.toStringAsFixed(2)),
                          ],
                        ),
                        CupertinoSlider(
                          value: settings.frostIntensity,
                          onChanged: (value) {
                            settingsNotifier.value = settings.copyWith(
                              frostIntensity: value.clamp(0.1, 40),
                            );
                          },
                          min: 0.1,
                          max: 40,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Chromatic Aberration:'),
                            Text(
                              settings.liquidGlassConfigs.chromaticAberration
                                  .toStringAsFixed(2),
                            ),
                          ],
                        ),
                        CupertinoSlider(
                          value:
                              settings.liquidGlassConfigs.chromaticAberration,
                          onChanged: (value) {
                            settingsNotifier.value = settings.copyWith(
                              liquidGlassConfigs: settings.liquidGlassConfigs
                                  .copyWith(chromaticAberration: value),
                            );
                          },
                          min: 0,
                          max: 10,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Saturation:'),
                            Text(settings.saturation.toStringAsFixed(2)),
                          ],
                        ),
                        CupertinoSlider(
                          value: settings.saturation,
                          onChanged: (value) {
                            settingsNotifier.value = settings.copyWith(
                              saturation: value,
                            );
                          },
                          min: 0,
                          max: 2,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Refractive Index:'),
                            Text(
                              settings.liquidGlassConfigs.refractiveIndex
                                  .toStringAsFixed(2),
                            ),
                          ],
                        ),
                        CupertinoSlider(
                          value: settings.liquidGlassConfigs.refractiveIndex,
                          onChanged: (value) {
                            settingsNotifier.value = settings.copyWith(
                              liquidGlassConfigs: settings.liquidGlassConfigs
                                  .copyWith(refractiveIndex: value),
                            );
                          },
                          min: 1,
                          max: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class Grid extends StatelessWidget {
  const Grid({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFCEC5B4), Color(0xFFF2F0EA)],
        ),
      ),
      child: GridPaper(
        color: Color(0xFF0F0B0A).withValues(alpha: 0.2),
        interval: 100,
      ),
    );
  }
}
