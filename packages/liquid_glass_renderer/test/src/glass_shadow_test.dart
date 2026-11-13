// alchemist still builds goldens on package:flutter/material.dart, so the
// tests stay on it instead of material_ui to keep one Theme hierarchy.
// ignore_for_file: deprecated_member_use

import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
              .widget<ClipRSuperellipse>(find.byType(ClipRSuperellipse))
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

    group('clips the shadows out of the shape', () {
      const shapes = [
        (
          'LiquidRoundedSuperellipse',
          LiquidRoundedSuperellipse(borderRadius: 50)
        ),
        ('LiquidRoundedRectangle', LiquidRoundedRectangle(borderRadius: 50)),
        ('LiquidOval', LiquidOval()),
      ];

      for (final (name, shape) in shapes) {
        testWidgets('$name: clips the shape out before painting shadows',
            (tester) async {
          await tester.pumpWidget(_app(_glass(shape)));
          final box = tester.renderObject<RenderBox>(find.byType(GlassShadow));
          // `paints` paints at Offset.zero. The glass is 200x200, and the
          // shadow reaches ~40px out.
          expect(
            box,
            paints
              ..clipPath(
                pathMatcher: isPathThat(
                  includes: [
                    const Offset(-10, 100),
                    const Offset(100, 230),
                  ],
                  excludes: [
                    const Offset(100, 100),
                    const Offset(100, 3),
                    const Offset(197, 100),
                  ],
                ),
              ),
          );
        });

        testWidgets(
            '$name: leaves the inside of the shape untouched, whatever the '
            'blur style', (tester) async {
          const background = Color(0xFFFFFFFF);
          final key = GlobalKey();
          await tester.pumpWidget(
            Directionality(
              textDirection: TextDirection.ltr,
              child: Center(
                child: RepaintBoundary(
                  key: key,
                  child: ColoredBox(
                    color: background,
                    child: Padding(
                      padding: const EdgeInsets.all(50),
                      child: GlassShadow(
                        shape: shape,
                        shadows: const [
                          BoxShadow(
                            color: Color(0xFF000000),
                            blurRadius: 20,
                            spreadRadius: 4,
                          ),
                          BoxShadow(
                            color: Color(0xFF000000),
                            offset: Offset(10, 10),
                            blurStyle: BlurStyle.solid,
                            blurRadius: 10,
                          ),
                          BoxShadow(
                            color: Color(0xFF000000),
                            offset: Offset(-6, 0),
                            blurStyle: BlurStyle.inner,
                            blurRadius: 10,
                          ),
                        ],
                        child: const SizedBox.square(dimension: 200),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );

          final pixels = await _capture(tester, key);
          // Offsets from the shape's top left, which is at (50, 50).
          Color at(double x, double y) => pixels(Offset(50 + x, 50 + y));

          // Inside the shape, including close to its edges: untouched.
          for (final point in const [
            Offset(100, 100),
            Offset(100, 3),
            Offset(3, 100),
            Offset(197, 100),
            Offset(100, 197),
          ]) {
            expect(at(point.dx, point.dy), background, reason: '$point');
          }
          // Just outside the shape: shadowed.
          expect(at(100, 205), isNot(background));
          expect(at(205, 100), isNot(background));
        });
      }
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

    goldenTest(
      'paints shadows only outside the glass, whatever the blur style',
      skip: skipPlatformGoldens,
      fileName: 'glass_shadows_outside_only',
      pumpBeforeTest: pumpOnce,
      builder: () => GoldenTestGroup(
        scenarioConstraints: testScenarioConstraints,
        children: [
          for (final (name, style, offset) in const [
            ('normal, offset', BlurStyle.normal, Offset(16, 24)),
            ('solid, offset', BlurStyle.solid, Offset(16, 24)),
            ('inner, offset', BlurStyle.inner, Offset(16, 24)),
          ])
            for (final fake in [false, true])
              GoldenTestScenario(
                name: fake ? '$name, fake glass' : name,
                child: buildWithGridPaper(
                  _glass(
                    const LiquidRoundedSuperellipse(borderRadius: 50),
                    shadows: [
                      BoxShadow(
                        blurStyle: style,
                        color: const Color(0xA0000000),
                        offset: offset,
                        blurRadius: 24,
                        spreadRadius: 6,
                      ),
                    ],
                    settings: fake
                        ? settingsWithoutLighting.copyWith(
                            fakeGlassConfigs: const FakeGlassConfigs(
                              forceEnabled: true,
                            ),
                          )
                        : settingsWithoutLighting,
                  ),
                ),
              ),
        ],
      ),
    );
  });
}

/// Renders the [RepaintBoundary] with [key] and returns a pixel lookup in its
/// logical coordinates (the test device pixel ratio is applied).
Future<Color Function(Offset)> _capture(
  WidgetTester tester,
  GlobalKey key,
) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  final captured = await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData();
    final width = image.width;
    image.dispose();
    return (width: width, data: data);
  });
  if (captured == null) throw StateError('Capturing the boundary timed out');
  final (:width, :data) = captured;
  if (data == null) throw StateError('The boundary image has no pixel data');

  final scale = width / boundary.size.width;
  return (Offset offset) {
    final x = (offset.dx * scale).floor();
    final y = (offset.dy * scale).floor();
    final i = (y * width + x) * 4;
    return Color.fromARGB(
      data.getUint8(i + 3),
      data.getUint8(i),
      data.getUint8(i + 1),
      data.getUint8(i + 2),
    );
  };
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
