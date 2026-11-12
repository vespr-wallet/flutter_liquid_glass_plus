/// Liquid Glass Effect for Flutter
///
/// A high-performance glass/frosted effect renderer using custom shaders.
///
/// **Impeller Required:** Liquid glass rendering requires Impeller to be
/// enabled. On non-Impeller devices (Skia), the effect automatically falls
/// back to fake glass rendering using standard backdrop filters.
///
/// **Performance:** Impeller-based liquid glass provides better visual quality
/// AND better performance than fake glass, because it uses custom shaders that
/// run entirely on the GPU.
///
/// ## Quick Start
///
/// ```dart
/// LiquidGlassLayer(
///   child: LiquidGlass(
///     shape: LiquidRoundedRectangle(borderRadius: 20),
///     child: Container(width: 100, height: 100),
///   ),
/// )
/// ```
///
/// ## Optional Features
///
/// - `LiquidStretch` - Squash/stretch on drag (not required for basic glass)
library liquid_glass_plus;

import 'package:flutter/foundation.dart' show kDebugMode;

export 'src/glass_glow.dart' show GlassGlow, GlassGlowLayer;
export 'src/internal/glass_drag_builder.dart' show GestureMode;
export 'src/liquid_glass.dart' show LiquidGlass;
export 'src/liquid_glass_settings.dart'
    show FakeGlassConfigs, LiquidGlassConfigs, LiquidGlassSettings;
export 'src/liquid_shape.dart';
export 'src/logging.dart' show LgrLogs;
export 'src/rendering/liquid_glass_layer.dart' show LiquidGlassLayer;
export 'src/stretch.dart'
    show
        LiquidStretch,
        LiquidTransform,
        OffsetResistanceExtension,
        RawLiquidStretch;

/// Whether to paint the liquid glass geometry texture for debugging purposes.
///
/// When enabled, geometry textures will be drawn directly instead of the
/// liquid glass effect.
///
/// Will be set to `false` in release builds.
@pragma('vm:platform-const-if', !kDebugMode)
bool debugPaintLiquidGlassGeometry = false;
