// ignore_for_file: require_trailing_commas

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:liquid_glass_plus/liquid_glass_plus.dart';
import 'package:meta/meta.dart';

// =============================================================================
// TUNING CONSTANTS - Hot reload friendly! Adjust and save to see changes.
// =============================================================================

// -- Inner Edge Shadow --
/// Divisor for shadow width (higher = thinner). shadowWidth = thickness / this
const kFakeGlassShadowWidthDivisor = 5.0;

/// Minimum shadow width in pixels.
const kFakeGlassShadowWidthMin = 1.0;

/// Maximum shadow width in pixels.
const kFakeGlassShadowWidthMax = 4.0;

/// Divisor for shadow alpha (higher = more transparent). alpha = thickness / this
const kFakeGlassShadowAlphaDivisor = 200.0;

/// Minimum shadow alpha (0.0 - 1.0).
const kFakeGlassShadowAlphaMin = 0.02;

/// Maximum shadow alpha (0.0 - 1.0).
const kFakeGlassShadowAlphaMax = 0.08;

// -- Specular Highlights --
/// Minimum stroke width for sharp specular line.
const kFakeGlassSpecularStrokeMin = 2.0;

/// Maximum stroke width for sharp specular line.
const kFakeGlassSpecularStrokeMax = 2.7;

/// Alpha multiplier for sharp specular (0.0 - 1.0)
const kFakeGlassSpecularAlpha = 0.7;

/// Divisor for overlay blur sigma (higher = less blur)
const kFakeGlassSpecularBlurDivisor = 5.0;

/// Divisor for overlay stroke width (higher = thinner)
const kFakeGlassSpecularOverlayWidthDivisor = 1.9;

/// Alpha multiplier for blurred overlay (0.0 - 1.0)
const kFakeGlassSpecularOverlayAlpha = 1.0;

// -- Saturation --
/// Multiplier to boost saturation effect to match real glass shader.
/// The shader-based saturation appears more pronounced, so we compensate.
const kFakeGlassSaturationMultiplier = 1.5;

// -- Depth Gradient --
/// Debug toggle for FakeGlass depth gradient effect.
/// Set to false to disable and compare the visual difference.
const kFakeGlassEnableDepthGradient = true;

/// Multiplier for gradient alpha based on light intensity
const kFakeGlassDepthGradientAlphaMultiplier = .1;

/// Minimum gradient alpha (0.0 - 1.0).
const kFakeGlassDepthGradientAlphaMin = 0.2;

/// Maximum gradient alpha (0.0 - 1.0).
const kFakeGlassDepthGradientAlphaMax = 0.9;

/// Ratio for dark side alpha relative to light side (0.0 - 1.0)
const kFakeGlassDepthGradientDarkRatio = 0.7;

/// A mixin that provides fake glass painting effects.
///
/// This mixin provides visual effects painting logic for fake glass mode,
/// used by RenderLiquidGlassLayer when rendering without shaders.
@internal
mixin FakeGlassEffectsMixin {
  /// The settings used to configure the fake glass effects.
  LiquidGlassSettings get fakeGlassSettings;

  // Cache for expensive computeLuminance() call
  double? _fakeGlassCachedLuminance;
  double get _glassColorLuminance {
    return _fakeGlassCachedLuminance ??=
        fakeGlassSettings.glassColor.computeLuminance();
  }

  /// Invalidates the cached luminance value.
  /// Call this when settings change.
  void invalidateFakeGlassCache() {
    _fakeGlassCachedLuminance = null;
  }

  /// Paints all glass visual effects (color, depth, shadow, specular).
  void paintFakeGlassEffects(
    Canvas canvas,
    Path path,
    Rect bounds,
  ) {
    _paintColor(canvas, path);
    _paintDepthGradient(canvas, path, bounds);
    _paintInnerEdgeShadow(canvas, path, bounds);
    _paintSpecular(canvas, path, bounds);
  }

  void _paintColor(Canvas canvas, Path path) {
    final color = fakeGlassSettings.glassColor;

    // Multiply for dark tints (absorption), screen for light (transmission)
    final blendMode =
        _glassColorLuminance < 0.5 ? BlendMode.multiply : BlendMode.screen;

    final paint = Paint()
      ..color = color
      ..blendMode = blendMode
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);

    paint
      ..blendMode = BlendMode.overlay
      ..color = color.withValues(alpha: color.a * .2);
    canvas.drawPath(path, paint);
  }

  /// Paints an approximation for specular highlights by using a linear
  /// gradient that is aligned with the light angle and painting a stroke with
  /// that gradient.
  void _paintSpecular(
    Canvas canvas,
    Path path,
    Rect bounds,
  ) {
    // Expand bounds to a square to make sure the gradient angle will match the
    // light angle correctly. A squashed gradient would change the angle.
    final squareBounds = Rect.fromCircle(
      center: bounds.center,
      radius: bounds.size.longestSide / 2,
    );

    final lightIntensity = fakeGlassSettings.lightIntensity.clamp(0.0, 1.0);
    final ambientStrength = fakeGlassSettings.ambientStrength.clamp(0.0, 1.0);

    final thicknessFactor = (fakeGlassSettings.thickness / 5).clamp(0.0, 1.0);
    final alpha = Curves.easeOut.transform(lightIntensity);

    // Create specular color from glass tint - brighter version of glass color
    final glassColor = fakeGlassSettings.glassColor;
    final baseSpecularColor = _brightenColor(glassColor);
    final color = baseSpecularColor.withValues(
      alpha: alpha * thicknessFactor,
    );
    final rad = fakeGlassSettings.lightAngle;

    final x = math.cos(rad);
    final y = math.sin(rad);

    // How far the light covers the glass, used to adjust the gradient stops
    final lightCoverage = ui.lerpDouble(.3, .5, lightIntensity)!;

    // How perpendicular we are to the shortest side of the box, 1 means the
    // light is hitting the shortest side directly, 0 means it's hitting the
    // longest side directly.
    final alignmentWithShortestSide =
        (bounds.size.aspectRatio < 1 ? y : x).abs();

    // How far we are from a square aspect ratio, used to adjust the gradient
    final aspectAdjustment = 1 - 1 / bounds.size.aspectRatio;

    // We scale the gradient when we are at a non-square aspect ratio, and the
    // light is aligned with the longest side.
    final gradientScale = aspectAdjustment * (1 - alignmentWithShortestSide);

    // How far the outer stops are inset
    final inset = ui.lerpDouble(0, .5, gradientScale.clamp(0, 1))!;

    // How far the second stops are inset
    final secondInset =
        ui.lerpDouble(lightCoverage, .5, gradientScale.clamp(0, 1))!;

    final shader = LinearGradient(
      colors: [
        color,
        color.withValues(alpha: ambientStrength),
        color.withValues(alpha: ambientStrength),
        color,
      ],
      stops: [
        inset,
        secondInset,
        1 - secondInset,
        1 - inset,
      ],
      begin: Alignment(x, y),
      end: Alignment(-x, -y),
    ).createShader(squareBounds);

    final paint = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = ui.lerpDouble(kFakeGlassSpecularStrokeMin,
          kFakeGlassSpecularStrokeMax, lightIntensity)!
      ..color = color.withValues(alpha: color.a * kFakeGlassSpecularAlpha)
      ..blendMode = BlendMode.hardLight;
    canvas.drawPath(path, paint);

    final overlay = Paint()
      ..shader = shader
      ..color =
          color.withValues(alpha: color.a * kFakeGlassSpecularOverlayAlpha)
      ..style = PaintingStyle.stroke
      ..maskFilter = MaskFilter.blur(BlurStyle.normal,
          fakeGlassSettings.thickness / kFakeGlassSpecularBlurDivisor)
      ..strokeWidth =
          fakeGlassSettings.thickness / kFakeGlassSpecularOverlayWidthDivisor
      ..blendMode = BlendMode.overlay;
    canvas.drawPath(path, overlay);
  }

  /// Paints an inner shadow along the edges to give the glass depth.
  ///
  /// This creates the illusion of thickness by darkening the inner edges.
  void _paintInnerEdgeShadow(Canvas canvas, Path path, Rect bounds) {
    final thickness = fakeGlassSettings.thickness;
    if (thickness <= 0) return;

    // Inner shadow - subtle darkening at edges
    final shadowWidth = (thickness / kFakeGlassShadowWidthDivisor)
        .clamp(kFakeGlassShadowWidthMin, kFakeGlassShadowWidthMax);
    final shadowAlpha = (thickness / kFakeGlassShadowAlphaDivisor)
        .clamp(kFakeGlassShadowAlphaMin, kFakeGlassShadowAlphaMax);

    final innerShadow = Paint()
      ..color = const Color(0xFF000000).withValues(alpha: shadowAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = shadowWidth
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadowWidth / 2);

    canvas.drawPath(path, innerShadow);
  }

  /// Paints a subtle depth gradient to enhance the 3D appearance.
  ///
  /// Creates a gradient from top-left (lighter) to bottom-right (darker)
  /// based on the light angle to simulate light passing through glass.
  void _paintDepthGradient(Canvas canvas, Path path, Rect bounds) {
    if (!kFakeGlassEnableDepthGradient) return;

    final thickness = fakeGlassSettings.thickness;
    if (thickness <= 0) return;

    final lightIntensity = fakeGlassSettings.lightIntensity.clamp(0.0, 1.0);
    final gradientAlpha =
        (lightIntensity * kFakeGlassDepthGradientAlphaMultiplier).clamp(
            kFakeGlassDepthGradientAlphaMin, kFakeGlassDepthGradientAlphaMax);

    if (gradientAlpha <= 0) return;

    final rad = fakeGlassSettings.lightAngle;
    final x = math.cos(rad);
    final y = math.sin(rad);

    // Create a gradient that follows the light direction
    final gradient = LinearGradient(
      colors: [
        const Color(0xFFFFFFFF).withValues(alpha: gradientAlpha),
        const Color(0x00000000),
        const Color(0xFF000000).withValues(
          alpha: gradientAlpha * kFakeGlassDepthGradientDarkRatio,
        ),
      ],
      stops: const [0.0, 0.5, 1.0],
      begin: Alignment(x, y),
      end: Alignment(-x, -y),
    ).createShader(bounds);

    final paint = Paint()
      ..shader = gradient
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.softLight;

    canvas
      ..save()
      ..clipPath(path)
      ..drawRect(bounds, paint)
      ..restore();
  }

  /// Creates a brighter version of the given color for specular highlights.
  ///
  /// Uses HSL color space to increase lightness while preserving hue.
  /// Only considers RGB values (ignores alpha which controls tint intensity).
  /// Falls back to white if the color has very low saturation.
  Color _brightenColor(Color color) {
    // Use RGB only - make opaque for HSL conversion
    final opaqueColor = color.withValues(alpha: 1);
    final hsl = HSLColor.fromColor(opaqueColor);

    // Lerp lightness 75% - 90% towards white - very bright but keeps hue
    // Use 90% for nearly grayscale colors, 75% for more colorful colors.
    final lerpFactor = hsl.saturation < 0.05 ? 0.9 : 0.75;

    final brighterLightness = ui.lerpDouble(hsl.lightness, 1.0, lerpFactor)!;
    return hsl.withLightness(brighterLightness.clamp(0.0, 1.0)).toColor();
  }

  /// Creates a saturation adjustment matrix.
  /// saturation = 0 -> grayscale (using Rec. 709 luma coefficients)
  /// saturation = 1 -> original color (no change)
  /// saturation > 1 -> over-saturated
  List<double> createSaturationMatrix(double saturation) {
    // Rec. 709 luma coefficients for RGB to grayscale conversion
    const lumR = 0.299;
    const lumG = 0.587;
    const lumB = 0.114;

    // Saturation matrix that interpolates between grayscale and original color
    // Based on: result = luminance + (color - luminance) * saturation
    final s = saturation;
    final invSat = 1.0 - s;

    return [
      lumR * invSat + s, lumG * invSat, lumB * invSat, 0, 0, // R
      lumR * invSat, lumG * invSat + s, lumB * invSat, 0, 0, // G
      lumR * invSat, lumG * invSat, lumB * invSat + s, 0, 0, // B
      0, 0, 0, 1, 0, // A
    ];
  }

  /// Creates a non-uniform scale filter to simulate refraction.
  ///
  /// The [refractionPixels] value specifies the target edge offset in pixels.
  /// Each axis is scaled independently to achieve consistent edge displacement
  /// regardless of widget aspect ratio.
  ///
  /// Uses magnification (scale > 1) to simulate glass lens effect where
  /// the background appears larger/closer through the glass.
  ui.ImageFilter createRefractionFilter(
    Offset center,
    double refractionPixels,
    Size size,
  ) {
    // Calculate per-axis scale to achieve target pixel offset at edges.
    // For a widget of width W, to shift edges by P pixels:
    // scaleX = 1 + P / (W / 2) = 1 + 2P / W (magnification)
    final scaleX =
        size.width > 0 ? 1.0 + (2 * refractionPixels / size.width) : 1.0;
    final scaleY =
        size.height > 0 ? 1.0 + (2 * refractionPixels / size.height) : 1.0;

    // Scale around center point
    final matrix = Matrix4.identity()
      ..translateByDouble(center.dx, center.dy, 0, 1)
      ..scaleByDouble(scaleX, scaleY, 1, 1)
      ..translateByDouble(-center.dx, -center.dy, 0, 1);

    return ui.ImageFilter.matrix(matrix.storage);
  }
}
