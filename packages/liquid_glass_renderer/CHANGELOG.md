## 0.4.0

- **FEAT**: new `shadows` parameter on `LiquidGlass` and `LiquidGlass.withOwnLayer` (default: none). Shadows are drawn with the canvas primitive that matches the shape (`drawRSuperellipse`, `drawRRect`, `drawOval`) instead of a blurred path (upstream [9599204](https://github.com/whynotmake-it/flutter_liquid_glass/commit/9599204)). They include upstream's later fixes: superellipse shapes get a superellipse shadow, and spread and offset are applied (upstream [77a373c](https://github.com/whynotmake-it/flutter_liquid_glass/commit/77a373c)). Upstream's `FakeGlass` widget and its shadow visibility scaling have no counterpart in this fork, which renders fake glass through `LiquidGlassSettings`.
- **FEAT**: new `gestureMode` option on `GlassGlow` and `LiquidStretch` (`GestureMode.listener` by default, unchanged behaviour; `GestureMode.gestureDetector` lets nested buttons claim the gesture; a `LiquidStretch` and `GlassGlow` nested in each other share one pan recognizer so both effects follow the drag, which is a fork addition) (upstream [916b019](https://github.com/whynotmake-it/flutter_liquid_glass/commit/916b019)).
- **FIX**: removing a `LiquidStretch` while a drag is in progress no longer throws `setState() called after dispose()` (upstream [88dcd26](https://github.com/whynotmake-it/flutter_liquid_glass/commit/88dcd26)). A cancelled pointer now also ends the stretch instead of leaving it stuck (fork addition).
- **PERF**: `LiquidGlass` clips its child with `ClipRSuperellipse` (superellipses) or `ClipRRect` (rounded rectangles, and ovals as elliptical rounded rects) instead of `ClipPath`. Changing the shape type keeps the child mounted, and hit testing stays limited to the shape (upstream [ffcc3bb](https://github.com/whynotmake-it/flutter_liquid_glass/commit/ffcc3bb) does the same for its `FakeGlass` widget; this fork has no such widget, so it applies to the `LiquidGlass` child clip in both real and fake glass mode).
- **PERF**: fake glass skips its `BackdropFilterLayer` when the filter would not change the backdrop (no frost, no saturation change, no fake refraction) and paints the tint, highlights and content directly (upstream [58bc74d](https://github.com/whynotmake-it/flutter_liquid_glass/commit/58bc74d)). On Impeller this also fixes a slightly softened backdrop in that case, because the zero-sigma blur layer wasn't a pure no-op (the fork's counterpart of the zero-blur part of upstream [77a373c](https://github.com/whynotmake-it/flutter_liquid_glass/commit/77a373c)).

## 0.3.3

- Builds cleanly on Flutter 3.50: library code imports `package:flutter/widgets.dart` instead of the deprecated `package:flutter/material.dart` (the minimum Flutter version is unchanged).
- Replaced the deprecated `EquatableMixin` with `Equatable` used as a mixin (same equality semantics); `equatable` now requires `^2.1.0`.
- Dependencies: `equatable` ^2.0.7 → ^2.1.0; dev `alchemist` ^0.12.1 → ^0.14.1; example dependencies moved to versions that resolve on Flutter 3.50 (`rivership` 0.4, `heroine` 0.7, `smooth_sheets` 1.3, `google_fonts` 9, `flex_color_picker` 4). Toolchain: Flutter 3.50.0 (`.fvmrc`, new `.tool-versions`).

## 0.3.2

- Fixed android and web compilation bugs in Flutter 3.44

## 0.3.1+1

- **DOCS**: clarified that Skia is supported using a linear approximation (not unsupported).
- **DOCS**: removed experimental warning section from README.
- **DOCS**: updated platform support documentation to reflect all platforms are supported.

## 0.3.1

> Note: This release has breaking changes.

This is the first stable release of `liquid_glass_plus`, ready for production use.

### Breaking Changes

- **BREAKING** **REFACTOR**: removed experimental `Glassify` widget and `experimental.dart` exports.

  The `Glassify` widget was marked experimental with known performance and quality issues.
  Use `LiquidGlass` with standard shapes (RoundedRectangle, Oval, Superellipse) instead.

- **BREAKING** **REFACTOR**: removed experimental `LiquidGlassFilter` widget.

  This widget was marked as "might be completely broken" and has been removed.

- **BREAKING** **REFACTOR**: removed `apple_liquid_glass` package.

  This package only re-exported `liquid_glass_plus`. Use `liquid_glass_plus` directly.

- **BREAKING** **REFACTOR**: `LiquidGlassSettings.flat` is now a named constructor `LiquidGlassSettings.flat()` for consistency with other presets.

### Features

- **FEAT**: added `LiquidGlassSettings.minimal()` and `LiquidGlassSettings.subtle()` presets.

  Convenience constructors for common glass effect configurations.

- **FEAT**: added implicit animations for shape and settings changes.

  Changes to `LiquidShape` and `LiquidGlassSettings` now animate smoothly by default.
  Set `animationDuration` to `Duration.zero` to disable.

### Improvements

- **DOCS**: improved library documentation with quick start example.
- **DOCS**: clarified `LiquidStretch` as optional feature with disable instructions.
- **DOCS**: updated `LiquidRoundedSuperellipse` documentation to be platform-neutral.
- **DOCS**: improved `glassContainsChild` documentation to clarify behavior.
- **CHORE**: cleaned up dead shader references from codebase.
- **CHORE**: removed debug print statements from production code.
- **CHORE**: added parameter validation assertions.

## 0.2.0-dev.5

> Note: This release has breaking changes.

 - **BREAKING** **REFACTOR**: removed experimental `Glassify` widget and `experimental.dart` exports.

   The `Glassify` widget was marked experimental with known performance and quality issues.
   Use `LiquidGlass` with standard shapes (RoundedRectangle, Oval, Superellipse) instead.

 - **BREAKING** **REFACTOR**: removed experimental `LiquidGlassFilter` widget.

   This widget was marked as "might be completely broken" and has been removed.

 - **BREAKING** **REFACTOR**: removed `apple_liquid_glass` package.

   This package only re-exported `liquid_glass_plus`. Use `liquid_glass_plus` directly.

 - **FEAT**: added `LiquidGlassSettings.minimal()` and `LiquidGlassSettings.subtle()` presets.

   Convenience constructors for common glass effect configurations.

 - **DOCS**: improved library documentation with quick start example.
 - **DOCS**: clarified `LiquidStretch` as optional feature with disable instructions.
 - **DOCS**: updated `LiquidRoundedSuperellipse` documentation to be platform-neutral.
 - **CHORE**: cleaned up dead shader references from codebase.

## 0.2.0-dev.4

> Note: This release has breaking changes.

 - **BREAKING** **FIX**: fake glass didn't render properly on skia and had bad specular highlights (#119).

## 0.2.0-dev.3

 - **FIX**: improve logging readability and names.
 - **FIX**: don't create intermediate images for geometry until it's settled.

    This should decrease memory consumption somewhat, as a layer with one animating geometry would create 2 images per frame before

 - **FEAT**: export `debugPaintLiquidGlassGeometry` (#111).

## 0.2.0-dev.2

 - **FIX**: glass was always grouped no matter which constructor was used.
 - **FIX**: one frame delay in geometry mattes.
 - **FIX**: link doesn't need to notify listeners, we can mark it dirty.

## 0.2.0-dev.1

> Note: This release has breaking changes.

 - **FIX**: adjust `LiquidGlassSettings` defaults to match the look more closely.
 - **FEAT**: cache geometry images as well to make sure we only run the geometry shader when absolutely necessary.
 - **DOCS**: mention Impeller requirement earlier in README.
 - **DOCS**: update README with newest changes and performance tips.
 - **BREAKING** **REFACTOR**: renamed many constructors and default `LiquidGlass` to not creating its own layer.

    Please read the README to understand how to use this package.

 - **BREAKING** **REFACTOR**: `LiquidGlassShape`s now take a simple double as radius.
 - **BREAKING** **FEAT**: adjust fake glass light intensity.
 - **BREAKING** **FEAT**: rewrote rendering pass to use two passes.

    We now cache all geometry into textures first, then render liquid glass in a second pass.
    This allows us to save a lot of cycles while glass shapes are static.


## 0.1.1-dev.26

> Note: This release has breaking changes.

 - **FIX**: only run shader on bounding box pixels.
 - **FIX**: set alwaysNeedsCompositing correctly on `FakeGlass`.
 - **BREAKING** **REFACTOR**: change default blend value to 0 in `LiquidGlassSettings`.
 - **BREAKING** **REFACTOR**: move `fake` parameter to `LiquidGlassLayer` and make entire layer fall back to fake glass on Skia.
 - **BREAKING** **FEAT**: visibility parameter in `LiquidGlassSettings`.

    This can be used to scale all relevant properties of the liquid glass effect
    at once.
    
    If you have made glass appear and disappear manually before, you can now
    simply animate the visibility between 0 and 1.


## 0.1.1-dev.25

 - **FEAT**: add `fake` parameter to `LiquidGlass` to enable it to turn into `FakeGlass` dynamically (#103).

## 0.1.1-dev.24

 - **FIX**: import `@internal` from meta again (#102).
 - **FIX**: scrolling elements work again.
 - **FEAT**: add `FakeGlass.inLayer` which adopts settings from the nearest ancestor layer.

## 0.1.1-dev.23

> Note: This release has breaking changes.

 - **BREAKING** **FEAT**: re-use generated geometry more aggressively (#98).

## 0.1.1-dev.22

> Note: This release has breaking changes.

 - **FIX**: reduce texture samples (#94).
 - **FEAT**: small performance wins in shader (#91).
 - **BREAKING** **REFACTOR**: remove `restrictThickness`.
 - **BREAKING** **FEAT**: rewrote the rendering process to use two passes.

    This significantly improves performance while glass elements
    are static on screen. Moving glass elements will still induce the same
    performance cost as before.


## 0.1.1-dev.21

> Note: This release has breaking changes.

 - **BREAKING** **FIX**: drop support for blur in `Glassify` for significant performance gains (#90).

## 0.1.1-dev.20

 - **FIX**: `resistance` parameter didn't actually get used.

## 0.1.1-dev.19

> Note: This release has breaking changes.

 - **FIX**: revert matrix methods to support older Flutter versions again.
 - **FIX**: `TileMode.mirror` in `FakeGlass` blur.
 - **FEAT**: allow customizing `resistance` in `LiquidStretch`.
 - **FEAT**: expose `RawLiquidStretch` for custom pixel-based stretching.
 - **FEAT**: expose `Offset.withResistance` extension method.
 - **BREAKING** **REFACTOR**: move `Glassify` to an `experimental.dart` import.
 - **BREAKING** **FEAT**: `LiquidStretch` now bases its stretch on the child's size.

## 0.1.1-dev.18

 - **FIX**: removed unused transform from shader (#88).
 - **FIX**: render liquid glass correctly on all Android devices (#82 by @teociaps).

## 0.1.1-dev.17

 - **FEAT**: tried to improve the fidelity of fake light once more.

## 0.1.1-dev.16

 - **FIX**: import annotations from `package:meta` again.

## 0.1.1-dev.15

> Note: This release has breaking changes.

 - **FIX**: settling springs.
 - **FIX**: optimize some painting and transformations with early return.
 - **FEAT**: better specular on all platforms for `FakeGlass` (#83).
 - **BREAKING** **REFACTOR**: rename `StretchGlass` to `LiquidStretch`.

## 0.1.1-dev.14

 - **FIX**: `LiquidGlassLayer` breaks when no child glass widgets are found.

## 0.1.1-dev.13

 - **DOCS**: update README and add better disclaimer (#80).

## 0.1.1-dev.12

> Note: This release has breaking changes.

 - **FIX**: regression in how `LiquidGlass` applies transform to children.
 - **FEAT**: add `GlassGlowLayer` and `GlassGlow` widget for glow effects.
 - **FEAT**: add `StretchGlass` widget that can stretch its child with user gestures.
 - **FEAT**: add `FakeGlass` widget that aims to match `LiquidGlass` appearance while being much more performant.
 - **BREAKING** **REFACTOR**: remove useless `lightness` parameter from shader and `LiquidGlassSettings`.
 - **BREAKING** **REFACTOR**: change default value of `glassContainsChild` to false.

## 0.1.1-dev.11

> Note: This release has breaking changes.

 - **BREAKING** **FEAT**: performance gains and too many changes to cover one by one (#72).

## 0.1.1-dev.10

> Note: This release has breaking changes.

 - **REFACTOR**: move shader to uniform arrays for better shape support.
 - **FIX**: transform children of liquid glass correctly.
 - **FEAT**: add saturation and brightness controls (#47).
 - **FEAT**: better light dispersion.
 - **FEAT**: support up to 64 shapes per layer.
 - **FEAT**: specular highlights now take the background color into account (#43).
 - **DOCS**: updated README with new parameters (#56).
 - **DOCS**: updated example gif (#55).
 - **BREAKING** **FEAT**: cheat lighting that is independent from thickness.

## 0.1.1-dev.9

 - **DOCS**: fix errors in README (#31).

## 0.1.1-dev.8

 - **FEAT**: added experimental `Glassify` widget that turns any child shape into liquid glass.
 - **FIX**: glass now also renders when blend is set to 0.
 - **FIX**: sharper glass edges whithout background shining through.
 - **FEAT**: added refractive index to settings and show values in example.
 - **FEAT**: nicer specular highlights.
 - **DOCS**: update README.md and add better examples (#28)

## 0.1.1-dev.7

 - **FIX**: throw `AssertionError` when used without Impeller.
 - **DOCS**: update pubspec.yaml to reflect minimum SDK and supported platforms.

## 0.1.1-dev.6

 - **FIX**: liquid glass not repainting in route transitions (#16).

## 0.1.1-dev.5

> Note: This release has breaking changes.

 - **FEAT**: decrease precision in shader to mediump, which should increase performance.
 - **BREAKING** **FIX**: shader compilation and removed unused outline strength parameter.

## 0.1.1-dev.4

 - **FIX**: fix shader on flutter stable.
 - **DOCS**: new shape names.

## 0.1.1-dev.3

 - **DOCS**: new shape names.

## 0.1.1-dev.2

> Note: This release has breaking changes.

 - **REFACTOR**: cleaned up shaders.
 - **FIX**: squircle can handle zero radius.
 - **FEAT**: add `clipBehavior` to `LiquidGlass`.
 - **FEAT**: flutter-approved SDF for squircles.
 - **FEAT**: support three shapes per layer.
 - **FEAT**: support all shapes.
 - **FEAT**: better chromatic abberation.
 - **DOCS**: added pub badge to README.
 - **BREAKING** **FEAT**: renamed liquid glass shapes to match their OutlinedBorder counterparts.

## 0.1.1-dev.1

 - **DOCS**: update pubspec and readme.

## 0.1.1-dev.0

 - **FEAT**: initial release.

## 0.1.0

- feat: initial commit 🎉
