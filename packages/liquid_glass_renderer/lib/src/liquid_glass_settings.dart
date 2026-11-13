import 'dart:math';
import 'dart:ui' as ui;

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:liquid_glass_plus/liquid_glass_plus.dart';
import 'package:liquid_glass_plus/src/internal/lerp.dart';
import 'package:liquid_glass_plus/src/liquid_glass_render_scope.dart';

/// Configuration specific to Impeller/shader-based liquid glass rendering.
///
/// These settings control the shader-based glass effects that require Impeller.
/// Liquid glass using these settings provides superior visual quality and
/// better performance compared to fake glass rendering.
class LiquidGlassConfigs with Equatable {
  /// Creates [LiquidGlassConfigs] with the given values.
  const LiquidGlassConfigs({
    this.chromaticAberration = 0.01,
    this.refractiveIndex = 1.2,
  })  : assert(chromaticAberration >= 0, 'chromaticAberration must be >= 0'),
        assert(refractiveIndex >= 1.0, 'refractiveIndex must be >= 1.0');

  /// The chromatic aberration of the glass effect.
  ///
  /// Creates color fringes around refracted content. Higher values create more
  /// pronounced color separation.
  ///
  /// Defaults to 0.01.
  final double chromaticAberration;

  /// The refractive index of the glass material.
  ///
  /// Controls how much light bends when passing through the glass.
  /// Higher values create more pronounced distortion.
  ///
  /// Defaults to 1.2.
  final double refractiveIndex;

  /// Creates a copy with the given values replaced.
  LiquidGlassConfigs copyWith({
    double? chromaticAberration,
    double? refractiveIndex,
  }) =>
      LiquidGlassConfigs(
        chromaticAberration: chromaticAberration ?? this.chromaticAberration,
        refractiveIndex: refractiveIndex ?? this.refractiveIndex,
      );

  /// Linearly interpolates between two [LiquidGlassConfigs].
  // ignore: prefer_constructors_over_static_methods
  static LiquidGlassConfigs lerp(
    LiquidGlassConfigs a,
    LiquidGlassConfigs b,
    double t,
  ) {
    return LiquidGlassConfigs(
      chromaticAberration:
          lerpDoubleNonNull(a.chromaticAberration, b.chromaticAberration, t),
      refractiveIndex:
          lerpDoubleNonNull(a.refractiveIndex, b.refractiveIndex, t),
    );
  }

  @override
  List<Object?> get props => [chromaticAberration, refractiveIndex];
}

/// Configuration specific to fake glass rendering (Skia fallback).
///
/// These settings control the backdrop filter-based glass effects used when
/// Impeller is not available. Fake glass uses standard Flutter backdrop filters
/// to approximate the glass effect.
///
/// **Why fake glass exists:** The liquid glass effect requires custom fragment
/// shaders for the refraction calculations. Skia does not support shader-based
/// backdrop filters, meaning the only way to achieve similar effects would be
/// to render the backdrop to an image first - which would be prohibitively
/// expensive. Fake glass approximates the effect using standard blur and scale
/// transforms, which Skia handles efficiently.
///
/// Note: Fake glass is a fallback for non-Impeller environments. Impeller-based
/// liquid glass provides better visual fidelity AND better performance.
class FakeGlassConfigs with Equatable {
  /// Creates [FakeGlassConfigs] with the given values.
  const FakeGlassConfigs({
    this.forceEnabled = false,
    this.refraction = 5.0,
  });

  /// Whether to force fake glass rendering even on Impeller.
  ///
  /// When true, fake glass rendering will be used regardless of whether
  /// Impeller is available. This is useful for testing and demos where you
  /// want to compare liquid glass vs fake glass side by side.
  ///
  /// Defaults to false (auto-detect based on platform support).
  final bool forceEnabled;

  /// The fake refraction edge offset in pixels.
  ///
  /// This creates a non-uniform scale effect to simulate refraction when
  /// custom shaders are not available (non-Impeller devices).
  ///
  /// The value specifies how many pixels the edges should appear to shift
  /// inward. Each axis is scaled independently, so wide buttons and tall
  /// buttons will have consistent edge displacement.
  ///
  /// Set to 0 to disable.
  ///
  /// Defaults to 5.0 pixels.
  final double refraction;

  /// Creates a copy with the given values replaced.
  FakeGlassConfigs copyWith({
    bool? forceEnabled,
    double? refraction,
  }) =>
      FakeGlassConfigs(
        forceEnabled: forceEnabled ?? this.forceEnabled,
        refraction: refraction ?? this.refraction,
      );

  /// Linearly interpolates between two [FakeGlassConfigs].
  ///
  /// Note: [forceEnabled] switches at t >= 0.5 (boolean lerp).
  // ignore: prefer_constructors_over_static_methods
  static FakeGlassConfigs lerp(
    FakeGlassConfigs a,
    FakeGlassConfigs b,
    double t,
  ) {
    return FakeGlassConfigs(
      forceEnabled: t < 0.5 ? a.forceEnabled : b.forceEnabled,
      refraction: lerpDoubleNonNull(a.refraction, b.refraction, t),
    );
  }

  @override
  List<Object?> get props => [forceEnabled, refraction];
}

/// Represents the settings for a liquid glass effect.
///
/// Liquid glass rendering requires Impeller to be enabled. On non-Impeller
/// devices, the effect automatically falls back to fake glass rendering using
/// standard backdrop filters.
///
/// **Performance note:** Impeller-based liquid glass actually provides better
/// performance than fake glass, in addition to superior visual quality.
class LiquidGlassSettings with Equatable {
  /// Creates a new [LiquidGlassSettings] with the given settings.
  ///
  /// Set [frostIntensity] > 0 to enable backdrop blur (frosted glass).
  /// Set [frostIntensity] to 0 for clear glass (no blur).
  const LiquidGlassSettings({
    this.glassColor = const Color.fromARGB(0, 255, 255, 255),
    this.thickness = 20,
    this.frostIntensity = 5,
    this.lightAngle = pi / 4,
    this.lightIntensity = .5,
    this.ambientStrength = 0,
    this.saturation = 1.5,
    this.liquidGlassConfigs = const LiquidGlassConfigs(),
    this.fakeGlassConfigs = const FakeGlassConfigs(),
    this.animationDuration = const Duration(milliseconds: 300),
    this.animationCurve = Curves.easeInOut,
  })  : assert(thickness >= 0, 'thickness must be >= 0'),
        assert(frostIntensity >= 0, 'frostIntensity must be >= 0'),
        assert(saturation > 0, 'saturation must be > 0');

  /// Creates a new [LiquidGlassSettings] with the given settings where each
  /// setting works like it does in Figma, where it is a percentage from
  /// 0 to 100.
  LiquidGlassSettings.figma({
    required double refraction,
    required double depth,
    required double dispersion,
    required double frost,
    double lightIntensity = 50,
    double lightAngle = pi / 4,
    Color glassColor = const Color.fromARGB(0, 255, 255, 255),
    double saturation = 1.5,
    FakeGlassConfigs fakeGlassConfigs = const FakeGlassConfigs(
      refraction: 5.0,
    ),
    Duration animationDuration = const Duration(milliseconds: 300),
    Curve animationCurve = Curves.easeInOut,
  }) : this(
          thickness: depth,
          lightIntensity: lightIntensity / 100,
          frostIntensity: frost,
          lightAngle: lightAngle,
          ambientStrength: 0.1,
          saturation: saturation,
          glassColor: glassColor,
          liquidGlassConfigs: LiquidGlassConfigs(
            refractiveIndex: 1 + (refraction / 100) * 0.2,
            chromaticAberration: 4 * (dispersion / 100),
          ),
          fakeGlassConfigs: fakeGlassConfigs,
          animationDuration: animationDuration,
          animationCurve: animationCurve,
        );

  /// A minimal glass effect with no lighting or chromatic aberration.
  ///
  /// Good for subtle, unobtrusive glass effects where you just want
  /// refraction and blur without decorative lighting.
  const LiquidGlassSettings.minimal({
    this.glassColor = const Color.fromARGB(0, 255, 255, 255),
    this.thickness = 15,
    this.frostIntensity = 4,
    this.saturation = 1.2,
    this.liquidGlassConfigs = const LiquidGlassConfigs(
      chromaticAberration: 0,
      refractiveIndex: 1.15,
    ),
    this.fakeGlassConfigs = const FakeGlassConfigs(
      refraction: 5.0,
    ),
    this.animationDuration = const Duration(milliseconds: 300),
    this.animationCurve = Curves.easeInOut,
  })  : lightAngle = 0,
        lightIntensity = 0,
        ambientStrength = 0;

  /// A subtle glass effect suitable for general UI use.
  ///
  /// Balanced settings with moderate refraction, light blur, and
  /// subtle lighting. A good starting point for most applications.
  const LiquidGlassSettings.subtle({
    this.glassColor = const Color.fromARGB(0, 255, 255, 255),
    this.thickness = 12,
    this.frostIntensity = 3,
    this.saturation = 1.3,
    this.liquidGlassConfigs = const LiquidGlassConfigs(
      chromaticAberration: 0.005,
      refractiveIndex: 1.1,
    ),
    this.fakeGlassConfigs = const FakeGlassConfigs(
      refraction: 5.0,
    ),
    this.animationDuration = const Duration(milliseconds: 300),
    this.animationCurve = Curves.easeInOut,
  })  : lightAngle = pi / 4,
        lightIntensity = 0.3,
        ambientStrength = 0;

  /// A flat, non-glass appearance with all effects disabled.
  ///
  /// Use this as a starting or ending point when animating between a flat
  /// surface and a glass effect using [LiquidGlassSettings.lerp].
  ///
  /// Example:
  /// ```dart
  /// // Animate from flat to glass
  /// final settings = LiquidGlassSettings.lerp(
  ///   const LiquidGlassSettings.flat(),
  ///   const LiquidGlassSettings(thickness: 20, frostIntensity: 8),
  ///   animationValue,
  /// );
  /// ```
  const LiquidGlassSettings.flat({
    this.animationDuration = const Duration(milliseconds: 300),
    this.animationCurve = Curves.easeInOut,
  })  : glassColor = const Color.fromARGB(0, 255, 255, 255),
        thickness = 0,
        frostIntensity = 0,
        lightAngle = 0,
        lightIntensity = 0,
        ambientStrength = 0,
        saturation = 1,
        liquidGlassConfigs = const LiquidGlassConfigs(
          chromaticAberration: 0,
          refractiveIndex: 1,
        ),
        fakeGlassConfigs = const FakeGlassConfigs(
          refraction: 0,
        );

  /// Retrieves the nearest [LiquidGlassSettings] from the widget tree.
  ///
  /// This will look for the nearest ancestor [LiquidGlassLayer] or
  /// [LiquidGlassRenderScope] widget in the widget tree.
  static LiquidGlassSettings of(BuildContext context) {
    return LiquidGlassRenderScope.of(context).settings;
  }

  /// The color tint of the glass effect.
  ///
  /// Opacity defines the intensity of the tint.
  final Color glassColor;

  /// The thickness of the glass surface.
  ///
  /// Thicker surfaces refract the light more intensely.
  final double thickness;

  /// The blur intensity of the frosted glass effect.
  ///
  /// Higher values create a more frosted appearance.
  /// Set to 0 for clear glass (no blur).
  ///
  /// Defaults to 5.
  final double frostIntensity;

  /// The angle of the light source in radians.
  ///
  /// This determines where the highlights on shapes will come from.
  final double lightAngle;

  /// The intensity of the light source.
  ///
  /// Higher values create more pronounced highlights.
  final double lightIntensity;

  /// The strength of the ambient light.
  ///
  /// Higher values create more pronounced ambient light.
  final double ambientStrength;

  /// The saturation adjustment for pixels that shine through the glass.
  ///
  /// 1.0 means no change, values < 1.0 desaturate the background,
  /// values > 1.0 increase saturation.
  ///
  /// This setting is used by both liquid glass (Impeller) and fake glass
  /// (Skia).
  ///
  /// Defaults to 1.5.
  final double saturation;

  /// Whether this glass is frosted (blur applied).
  ///
  /// Returns true when [frostIntensity] > 0.
  bool get isFrosted => frostIntensity > 0;

  /// Impeller/shader-specific liquid glass configuration.
  ///
  /// These settings control the shader-based glass effects that require
  /// Impeller to be enabled. Liquid glass provides superior visual quality
  /// and better performance compared to fake glass rendering.
  final LiquidGlassConfigs liquidGlassConfigs;

  /// Fake glass (Skia fallback) configuration.
  ///
  /// These settings control the backdrop filter-based glass effects used
  /// when Impeller is not available, or when [FakeGlassConfigs.forceEnabled]
  /// is true. Fake glass uses standard Flutter backdrop filters to
  /// approximate the glass effect.
  ///
  /// Note: Fake glass is a fallback for non-Impeller environments.
  /// Impeller-based liquid glass provides better visual fidelity AND
  /// better performance.
  final FakeGlassConfigs fakeGlassConfigs;

  /// Duration for implicit animations when shape or settings change.
  ///
  /// When set to a non-zero duration (the default is 300ms), changes to
  /// [LiquidShape] and [LiquidGlassSettings] will animate smoothly over this
  /// duration. Set to [Duration.zero] to disable animations and make changes
  /// instant with no animation overhead.
  ///
  /// This field is not interpolated during [lerp] - it controls animation
  /// behavior rather than being animated itself.
  final Duration animationDuration;

  /// The curve to use for implicit animations.
  ///
  /// Only applies when [animationDuration] is non-zero.
  ///
  /// Defaults to [Curves.easeInOut].
  ///
  /// This field is not interpolated during [lerp] - it controls animation
  /// behavior rather than being animated itself.
  final Curve animationCurve;

  /// Whether fake glass mode should be used.
  ///
  /// Returns true if [FakeGlassConfigs.forceEnabled] is true or if Impeller
  /// is not available (shader filters not supported).
  bool get shouldUseFakeGlass =>
      fakeGlassConfigs.forceEnabled || !ui.ImageFilter.isShaderFilterSupported;

  /// Creates a new [LiquidGlassSettings] with the given settings.
  LiquidGlassSettings copyWith({
    Color? glassColor,
    double? thickness,
    double? frostIntensity,
    double? lightAngle,
    double? lightIntensity,
    double? ambientStrength,
    double? saturation,
    LiquidGlassConfigs? liquidGlassConfigs,
    FakeGlassConfigs? fakeGlassConfigs,
    Duration? animationDuration,
    Curve? animationCurve,
  }) =>
      LiquidGlassSettings(
        glassColor: glassColor ?? this.glassColor,
        thickness: thickness ?? this.thickness,
        frostIntensity: frostIntensity ?? this.frostIntensity,
        lightAngle: lightAngle ?? this.lightAngle,
        lightIntensity: lightIntensity ?? this.lightIntensity,
        ambientStrength: ambientStrength ?? this.ambientStrength,
        saturation: saturation ?? this.saturation,
        liquidGlassConfigs: liquidGlassConfigs ?? this.liquidGlassConfigs,
        fakeGlassConfigs: fakeGlassConfigs ?? this.fakeGlassConfigs,
        animationDuration: animationDuration ?? this.animationDuration,
        animationCurve: animationCurve ?? this.animationCurve,
      );

  /// Linearly interpolates between two [LiquidGlassSettings].
  ///
  /// The [t] parameter represents the interpolation progress from 0.0 to 1.0,
  /// where 0.0 returns [a] and 1.0 returns [b].
  ///
  /// Note: [animationDuration] and [animationCurve] are not interpolated -
  /// the destination (b) values are always used since they control animation
  /// behavior rather than being animated themselves.
  ///
  /// Example:
  /// ```dart
  /// // Animate from flat to glass
  /// final settings = LiquidGlassSettings.lerp(
  ///   const LiquidGlassSettings.flat(),
  ///   const LiquidGlassSettings(thickness: 20, frostIntensity: 8),
  ///   animationValue,
  /// );
  /// ```
  // ignore: prefer_constructors_over_static_methods
  static LiquidGlassSettings lerp(
    LiquidGlassSettings a,
    LiquidGlassSettings b,
    double t,
  ) {
    return LiquidGlassSettings(
      glassColor: lerpColorNonNull(a.glassColor, b.glassColor, t),
      thickness: lerpDoubleNonNull(a.thickness, b.thickness, t),
      frostIntensity: lerpDoubleNonNull(a.frostIntensity, b.frostIntensity, t),
      lightAngle: lerpDoubleNonNull(a.lightAngle, b.lightAngle, t),
      lightIntensity: lerpDoubleNonNull(a.lightIntensity, b.lightIntensity, t),
      ambientStrength:
          lerpDoubleNonNull(a.ambientStrength, b.ambientStrength, t),
      saturation: lerpDoubleNonNull(a.saturation, b.saturation, t),
      liquidGlassConfigs: LiquidGlassConfigs.lerp(
        a.liquidGlassConfigs,
        b.liquidGlassConfigs,
        t,
      ),
      fakeGlassConfigs: FakeGlassConfigs.lerp(
        a.fakeGlassConfigs,
        b.fakeGlassConfigs,
        t,
      ),
      // Animation fields use destination values (not interpolated)
      animationDuration: b.animationDuration,
      animationCurve: b.animationCurve,
    );
  }

  @override
  List<Object?> get props => [
        glassColor,
        thickness,
        frostIntensity,
        lightAngle,
        lightIntensity,
        ambientStrength,
        saturation,
        liquidGlassConfigs,
        fakeGlassConfigs,
        animationDuration,
        animationCurve,
      ];
}
