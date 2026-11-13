# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Flutter melos workspace for liquid glass/frosted glass effects in Flutter applications. It is VESPR's fork of `whynotmake-it/flutter_liquid_glass`. Works best with Impeller (Flutter's new rendering engine), but Skia is also supported using an approximation that produces similar but not identical visual results.

**Package:** `liquid_glass_plus`, in `packages/liquid_glass_renderer/` (the directory keeps the upstream name; the package, its imports and its CHANGELOG all use `liquid_glass_plus`). It is not on pub.dev: consumers depend on it through a git `ref: vX.Y.Z` tag. Its example app is `packages/liquid_glass_renderer/example/` (`liquid_glass_plus_example`). All paths below are relative to `packages/liquid_glass_renderer/` unless they start at the repo root.

**Platform Support:**
- Best quality: macOS, iOS, Android with Impeller
- Supported with approximation: All platforms (including Web, Windows, Linux) use a linear approximation that produces similar but not identical visual results

## Common Commands

### Package Management
```bash
# Bootstrap the workspace (run after cloning)
melos bootstrap

# Get dependencies for all packages
melos clean && melos bootstrap
```

### Development
```bash
# Analyze all packages with --fatal-infos (concurrency=1 to avoid crashes on low-end machines)
melos run analyze

# Check formatting (CI fails on unformatted code). Use the Flutter SDK's bundled
# dart, not an asdf `dart` shim, so the formatter matches CI.
dart format --output=none --set-exit-if-changed .
```

### Testing
```bash
# Run all tests (requires --enable-impeller flag)
melos run test

# Run tests for specific packages
melos run test:select

# Run tests without golden tests (what the Linux CI job runs)
melos run test-without-goldens

# Update golden test images
melos run update-goldens

# Generate coverage for all packages
melos run coverage
```

### Releasing
The version lives in `packages/liquid_glass_renderer/pubspec.yaml`, and every
change gets an entry in `packages/liquid_glass_renderer/CHANGELOG.md` (under
`## Unreleased` until a release moves it into a version section). A release is a
PR that bumps the version; after it merges, `main` is tagged with an annotated
`vX.Y.Z` tag and a GitHub Release is created whose notes are that CHANGELOG
section. Tags are created by hand; don't use `melos version`, which creates
melos-style tags.

### Running the Example App
```bash
cd packages/liquid_glass_renderer/example
flutter run --enable-impeller
```

## Architecture

### Rendering Pipeline

The liquid glass effect works by capturing and distorting background pixels through a multi-stage rendering pipeline:

1. **LiquidGlassLayer** (`lib/src/rendering/liquid_glass_layer.dart`): Container widget that manages rendering context for all glass effects within it. Creates textures covering its entire area.

2. **LiquidGlass** (`lib/src/liquid_glass.dart`): Individual glass shapes that must be inside a LiquidGlassLayer.

3. **Geometry Rendering** (`lib/src/internal/render_liquid_glass_geometry.dart`): Renders glass shape geometry into textures for shader processing. Caches geometry to avoid re-rendering on every frame.

4. **Shader Pipeline** (`lib/src/shaders.dart` and `lib/assets/shaders/`):
   - `liquid_glass_geometry_blended.frag`: Renders blended glass geometry
   - `liquid_glass_final_render.frag`: Final composition (refraction, blur, lighting)

### Key Components

- **Shapes** (`lib/src/liquid_shape.dart`): Defines glass shape types (RoundedSuperellipse, Oval, RoundedRectangle)
- **Settings** (`lib/src/liquid_glass_settings.dart`): Configures glass appearance (thickness, blur, color, lighting)
- **GlassGlow** (`lib/src/glass_glow.dart`): Touch-responsive glow effects
- **LiquidStretch** (`lib/src/stretch.dart`): Squash and stretch animations
- **GlassShadow** (`lib/src/glass_shadow.dart`): Shadows around a glass shape, drawn with shape primitives
- **OptimizedClip** (`lib/src/internal/optimized_clip.dart`): Clips glass children with the shape's clip primitive
- **Fake glass** (`lib/src/rendering/fake_glass_effects_mixin.dart`): The non-shader approximation used without Impeller or when forced via settings

### Performance Considerations

The package aggressively caches geometry in textures to minimize GPU work. However, due to [Flutter issue #138627](https://github.com/flutter/flutter/issues/138627), textures cannot be disposed immediately, causing memory spikes during animations.

**When working on performance:**
- Minimize LiquidGlassLayer pixel coverage
- Cache static geometry - re-rendering on every frame is expensive
- Moving shapes forces the package to re-render their glass effect every frame

## Testing

### Golden Tests
Golden tests verify visual output and are tagged with `golden` in `dart_test.yaml`. The goldens are macOS platform goldens (`test/flutter_test_config.dart`), so they can't be compared on Linux. In CI (`.github/workflows/goldens.yaml`) they run on a macOS-15 runner only:
- On pushes to main
- On PRs labeled with "goldens"

The Linux CI job runs `melos run test-without-goldens`. Every `goldenTest` must pass `skip: skipPlatformGoldens` (from `test/src/shared.dart`): off macOS alchemist has no variant to run, and the whole test file would fail to load. Failure diffs land in `test/src/failures/` (gitignored).

All tests must use the `--enable-impeller` flag for consistent golden test results (Skia uses an approximation that produces different visuals).

### Test Structure
- Tests are in `packages/liquid_glass_renderer/test/`
- Test config: `dart_test.yaml` at root and package level
- Uses `alchemist` for golden testing

## CI/CD Workflows

- **main.yaml**: PR title check, format check, `analyze --fatal-infos`, tests without goldens (Linux)
- **goldens.yaml**: golden tests (macOS), on main and on PRs labeled `goldens`
- **benchmark.yaml**: Performance benchmarking

## Debugging

Set `debugPaintLiquidGlassGeometry = true` (exported from `liquid_glass_plus.dart`) to visualize geometry textures instead of the glass effect. Only works in debug mode.

## Shader Development

Shader source files are in `packages/liquid_glass_renderer/lib/assets/shaders/`:
- Main shader files: `*.frag`
- Shared utilities: `*.glsl` (sdf.glsl, displacement_encoding.glsl, render.glsl)

Shaders are compiled by Flutter and loaded via `flutter_shaders` package. Edit `.frag` files and run `flutter run` to hot reload changes (though shaders typically require full restart).
