# Liquid Glass Plus

<!-- [![Code Coverage](./coverage.svg)](./test/) -->
[![Pub Version](https://img.shields.io/pub/v/liquid_glass_plus)](https://pub.dev/packages/liquid_glass_plus)
[![Code Coverage](./coverage.svg)](./test/)
[![lints by lintervention][lintervention_badge]][lintervention_link]


A Flutter package for creating a stunning "liquid glass" or "frosted glass" effect. This package allows you to transform your widgets into beautiful, customizable glass-like surfaces that can blend and interact with each other.


![Showcase GIF](https://i.imgur.com/llQIu5W.gif)

## Features

-   🫧 **Implement Glass Effects**: Easily wrap any widget to give it a glass effect.
-   🔀 **Blending Layers**: Create layers where multiple glass shapes can blend together like liquid.
-   🎨 **Highly Customizable**: Adjust thickness, color tint, lighting, and more.
-   🔍 **Background Effects**: Apply background blur and refraction.
-   ✨ **Interactive Glow**: Add touch-responsive glow effects to glass surfaces.
-   🎭 **Fake Glass**: Skia-compatible glass approximation using backdrop filters instead of custom shaders.
-   🤸 **Stretch Effects**: Apply organic squash and stretch animations to glass widgets.
-   🎬 **Implicit Animations**: Shape and settings changes are automatically animated (changing between shape types not yet supported).

![Transitions Demo](https://i.imgur.com/Pj662vB.gif)

*Real glass (left) and fake glass (right) with implicit transitions for frost, intensity, shape, radius, and size.*

## Installation

**In order to start using Flutter Liquid Glass you must have the [Flutter SDK][flutter_install_link] installed on your machine.**

Install via `flutter pub add`:

```sh
flutter pub add liquid_glass_plus
```

And import it in your Dart code:

```dart
import 'package:liquid_glass_plus/liquid_glass_plus.dart';
```

## How To Use

![Example GIF](https://i.imgur.com/2Lz3vfe.gif)

The liquid glass effect is achieved by taking the pixels of the content *behind* the glass widget and distorting them. For the effect to be visible, you **must** place your glass widget on top of other content. The easiest way to do this is with a `Stack`.

Make sure to read the [Performance](#-a-word-on-performance) section for tips on getting the best performance out of the package.

```dart
Stack(
  children: [
    // 1. Your background content goes here
    MyBackgroundContent(),

    // 2. Create a layer for liquid glass effects
    LiquidGlassLayer(
      // 3. Add your LiquidGlass widgets here
      child: LiquidGlass(
        shape: LiquidRoundedSuperellipse(borderRadius: 30),
        child: const SizedBox.square(dimension: 100),
      ),
    ),
  ],
)
```

### What's in the box?

This package provides several widgets to create the glass effect:

| Widget                    | Use Case                                                                                   |
| ------------------------- | ------------------------------------------------------------------------------------------ |
| `LiquidGlassLayer`        | Container for all liquid glass effects. Required parent for `LiquidGlass` widgets.         |
| `LiquidGlass`             | Creates a single glass shape. Must be inside a `LiquidGlassLayer`.                         |
| `GlassGlow`               | Add touch-responsive glow effects to glass surfaces.                                       |
| `LiquidStretch`           | Add interactive squash and stretch effects to glass widgets (optional).                    |

### ⚠️ Limitations

- **Skia uses an approximation**: On non-Impeller platforms (Skia), a linear transformation approximation is used instead of the custom shader which performs non-linear transformations to achieve the glass-like look. The visual result is similar but not identical.
- **Shape type transitions are not animated**: Changing between different shape types (e.g., from `LiquidRoundedSuperellipse` to `LiquidOval`) will happen instantly. Only changes within the same shape type (e.g., border radius) are animated.


### 🚨 A word on Performance

The liquid glass effect is computationally intensive, especially on mobile devices. To save GPU cycles, `liquid_glass_plus` will try to cache geometry in textures wherever possible.


#### Best Practices
To ensure the best performance when using liquid glass effects, consider the following tips:
- **Use `LiquidGlassLayer` for shapes that share the same settings.** Creating many individual layers is expensive.
- **Minimize the amount of pixels covered by `LiquidGlassLayer`**: The layer will create textures that cover its entire area. Try to keep these areas as small as possible. If you have a large area with sparse glass shapes, consider splitting them into multiple smaller layers.
- **Limit animations**: The glass effect is almost free while shapes remain in the same position onscreen. Moving shapes forces the package to re-render their glass effect every frame, which is expensive.

---

## Examples

### `LiquidGlass`: A Single Glass Shape

![Shapes Demo](doc/shapes.png)

To create glass shapes, you must wrap them in a `LiquidGlassLayer`. This layer manages the rendering of all glass effects within it.

```dart
import 'package:flutter/material.dart';
import 'package:liquid_glass_plus/liquid_glass_plus.dart';

class MyGlassWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // This is the content that will be behind the glass
          Positioned.fill(
            child: Image.network(
              'https://picsum.photos/seed/glass/800/800',
              fit: BoxFit.cover,
            ),
          ),
          // The LiquidGlassLayer manages glass rendering
          Center(
            child: LiquidGlassLayer(
              settings: const LiquidGlassSettings(
                thickness: 20,
                frostIntensity: 10,
                glassColor: Color(0x33FFFFFF),
              ),
              child: LiquidGlass(
                shape: LiquidRoundedSuperellipse(
                  borderRadius: 50,
                ),
                child: const SizedBox(
                  height: 200,
                  width: 200,
                  child: Center(
                    child: FlutterLogo(size: 100),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

If you need a single glass shape with custom settings and don't want to create a separate `LiquidGlassLayer`, you can use `LiquidGlass.withOwnLayer`:

```dart
LiquidGlass.withOwnLayer(
  settings: const LiquidGlassSettings(
    thickness: 15,
    frostIntensity: 8,
  ),
  shape: LiquidRoundedSuperellipse(borderRadius: 30),
  child: const SizedBox.square(dimension: 100),
)
```

**Note:** Make sure you have read the [Performance](#-a-word-on-performance) section for tips on getting the best performance out of the package.

#### Supported Shapes

The LiquidGlass widget supports the following shapes:

-   `LiquidRoundedSuperellipse` (recommended) - A smooth, rounded squircle shape
-   `LiquidOval` - A perfect ellipse/circle
-   `LiquidRoundedRectangle` - A rounded rectangle

All shapes take a simple `double` for `borderRadius` instead of `BorderRadius` or `Radius`, since they don't support non-uniform radii.


## Customization

### `LiquidGlassSettings`

You can customize the appearance of the glass by providing `LiquidGlassSettings` to a `LiquidGlassLayer` or `LiquidGlass.withOwnLayer()`. All glass widgets within that layer will share these settings.

```dart
LiquidGlassLayer(
  settings: const LiquidGlassSettings(
    thickness: 10,
    glassColor: Color(0x1AFFFFFF),
    lightIntensity: 1.5,
    outlineIntensity: 0.5,
    saturation: 1.2,
  ),
  child: // ... your LiquidGlass widgets
)
```

Here's a breakdown of the key settings:

-   `glassColor`: The color tint of the glass. The alpha channel controls the intensity.
-   `thickness`: How much the glass refracts the background (higher = more distortion).
-   `frostIntensity`: Background blur/frost strength (0 = no blur).
-   `refractiveIndex`: The refractive index of the glass material (1.0 = no refraction, ~1.5 = realistic glass).
-   `lightAngle`, `lightIntensity`: Control the direction and brightness of the virtual light source, creating highlights.
-   `ambientStrength`: The intensity of ambient light on the glass.
-   `outlineIntensity`: The visibility of the glass outline/edge.
-   `saturation`: Adjusts the color saturation of background pixels visible through the glass (1.0 = no change, <1.0 = desaturated, >1.0 = more saturated).

Increasing saturation when using colored glass helps achieve an Apple-like aesthetic.

**Note:** Changes to `LiquidGlassSettings` or the `LiquidShape` are automatically animated with smooth transitions. Simply update the values and the glass effect will interpolate to the new configuration. However, changing between shape types (e.g., from `LiquidRoundedSuperellipse` to `LiquidOval`) is not yet animated.

### Adding Blur (Frost)

You can apply a background blur using the `frostIntensity` property in `LiquidGlassSettings`. This is independent of the glass refraction effect.

```dart
LiquidGlassLayer(
  settings: const LiquidGlassSettings(
    frostIntensity: 10.0,
    thickness: 20,
  ),
  child: // ... your glass widgets
)
```

### Child Placement

The `child` of a `LiquidGlass` widget can be rendered either "inside" the glass or on top of it using the `glassContainsChild` property.

-   `glassContainsChild: false` (default): The child is rendered normally on top of the glass effect.
-   `glassContainsChild: true`: The child is part of the glass, affected by color tint and refraction.

### Fake Glass Mode: Skia-Compatible Alternative

When Impeller is not available (Skia rendering), fake glass mode is automatically used. It provides a similar visual effect using backdrop filters instead of custom shaders. No configuration is needed - the package detects the rendering backend and switches automatically.

If you want to force fake glass mode even when Impeller is available, you can set `fake: true` on the layer:

```dart
LiquidGlassLayer(
  fake: true, // Force fake glass (normally auto-detected)
  settings: const LiquidGlassSettings(
    frostIntensity: 10,
    glassColor: Color(0x33FFFFFF),
  ),
  child: LiquidGlass(
    shape: LiquidRoundedSuperellipse(borderRadius: 20),
    child: const SizedBox(
      height: 100,
      width: 100,
      child: Center(child: Text('Fake Glass')),
    ),
  ),
)
```

Note that performance is similar or slightly worse than real glass on Impeller, so there's no performance benefit to forcing fake glass.

**Note:** Fake glass mode ignores `refractiveIndex`; `thickness` only affects faux lighting/edge effects, not true refraction.

### `GlassGlow`: Interactive Touch Effects

Add responsive glow effects that follow user touches. Wrap your content with `GlassGlow` inside your glass widget. The `GlassGlowLayer` is automatically included by `LiquidGlass`.

```dart
LiquidGlassLayer(
  child: LiquidGlass(
    shape: LiquidRoundedSuperellipse(
      borderRadius: 20,
    ),
    child: GlassGlow(
      glowColor: Colors.white24,
      glowRadius: 1.0,
      child: const SizedBox(
        height: 100,
        width: 100,
        child: Center(child: Text('Touch Me')),
      ),
    ),
  ),
)
```

The glow effect automatically appears at touch locations and fades out smoothly when interaction ends.

### `LiquidStretch`: Organic Squash and Stretch

Add interactive squash and stretch effects that respond to user gestures, creating an organic, jelly-like feel:

```dart
LiquidStretch(
  stretch: 0.5,
  interactionScale: 1.05,
  child: LiquidGlass(
    shape: LiquidRoundedSuperellipse(
      borderRadius: 20,
    ),
    child: const SizedBox(
      height: 100,
      width: 100,
      child: Center(child: Text('Stretchy')),
    ),
  ),
)
```

The widget listens to drag gestures and applies smooth squash and stretch transformations without interfering with other gestures.

#### Nested interactive widgets

By default, `GlassGlow` and `LiquidStretch` react to raw pointer events (`GestureMode.listener`), so they trigger even when a nested button handles the tap. Pass `gestureMode: GestureMode.gestureDetector` to make them take part in the gesture arena instead: nested widgets such as buttons can then claim the gesture, and the glow or stretch only starts once a drag wins.

```dart
LiquidStretch(
  gestureMode: GestureMode.gestureDetector,
  child: GlassGlow(
    gestureMode: GestureMode.gestureDetector,
    child: IconButton(onPressed: () {}, icon: const Icon(Icons.add)),
  ),
)
```

---

For more details, check out the API documentation in the source code.

---

## Acknowledgments

This package started as a fork of [flutter_liquid_glass](https://github.com/whynotmake-it/flutter_liquid_glass) by [whynotmake.it](https://whynotmake.it).

**Why the fork?**

1. **Platform-agnostic focus**: This package aims to create beautiful glass widgets without replicating the entire iOS glass behaviour (such as cross-widget morphing/blending). We intentionally keep things more platform-agnostic. Replicating actual iOS widgets (like the bottom bar) may be done as a separate package building on top of this one.

2. **Production-ready simplifications**: Some features were simplified to make the package more production-ready, and implicit animations have been added (with more to come).

3. **Improved Skia compatibility**: The fake glass (Skia) implementation looks significantly closer to the Impeller (shader-based) implementation than the original. However, this comes at a slight performance cost when testing on Impeller.

---

[mason_link]: https://github.com/felangel/mason
[mason_badge]: https://img.shields.io/endpoint?url=https%3A%2F%2Ftinyurl.com%2Fmason-badge
[lintervention_link]: https://github.com/whynotmake-it/lintervention
[lintervention_badge]: https://img.shields.io/badge/lints_by-lintervention-3A5A40

[flutter_install_link]: https://docs.flutter.dev/get-started/install

