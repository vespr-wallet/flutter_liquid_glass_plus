// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// A callback used by [MultiShaderBuilder].
typedef MultiShaderBuilderCallback = Widget Function(
  BuildContext,
  List<ui.FragmentShader>,
  Widget?,
);

/// A widget that loads and caches [ui.FragmentProgram]s based on asset keys.
///
/// Usage of this widget avoids the need for a user authored stateful widget
/// for managing the lifecycle of loading shaders. Once shaders are cached,
/// subsequent usages of them via a [MultiShaderBuilder] will always be
/// available synchronously. These shaders can also be precached imperatively
/// with [MultiShaderBuilder.precacheShader].
///
/// If the shaders are not yet loaded, the provided child widget or a [SizedBox]
/// is returned instead of invoking the builder callback.
///
/// Example: providing access to [ui.FragmentShader] instances.
///
/// ```dart
/// Widget build(BuildContext context) {
///  return ShaderBuilder(
///    builder: (BuildContext context, List<ui.FragmentShader> shaders, Widget?
/// child) {
///      return WidgetThatUsesFragmentShaders(
///        shaders: shaders,
///        child: child,
///      );
///    },
///    assetKeys: ['shader1.frag', 'shader2.frag'],
///    child: Text('Hello, Shaders'),
///  );
/// }
/// ```
class MultiShaderBuilder extends StatefulWidget {
  /// Create a new [MultiShaderBuilder].
  const MultiShaderBuilder(
    this.builder, {
    required this.assetKeys,
    super.key,
    this.child,
  });

  /// The asset keys used to lookup shaders.
  final List<String> assetKeys;

  /// The child widget to pass through to the [builder], optional.
  final Widget? child;

  /// The builder that provides access to [ui.FragmentShader]s.
  final MultiShaderBuilderCallback builder;

  @override
  State<StatefulWidget> createState() {
    return _MultiShaderBuilderState();
  }

  /// Precache a [ui.FragmentProgram] based on its [assetKey].
  ///
  /// When this future has completed, any newly created [MultiShaderBuilder]s
  /// that reference this asset will be guaranteed to immediately have access to
  /// the shader.
  static Future<void> precacheShader(String assetKey) {
    if (_MultiShaderBuilderState._shaderCache.containsKey(assetKey)) {
      return Future<void>.value();
    }
    return ui.FragmentProgram.fromAsset(assetKey).then(
      (ui.FragmentProgram program) {
        _MultiShaderBuilderState._shaderCache[assetKey] = program;
      },
      onError: (Object error, StackTrace stackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(exception: error, stack: stackTrace),
        );
      },
    );
  }

  /// Precache multiple [ui.FragmentProgram]s based on their [assetKeys].
  ///
  /// When this future has completed, any newly created [MultiShaderBuilder]s
  /// that reference these assets will be guaranteed to immediately have access
  /// to the shaders.
  static Future<void> precacheShaders(List<String> assetKeys) {
    return Future.wait(
      assetKeys.map(precacheShader),
    );
  }

  /// Clears the shader cache.
  ///
  /// This is primarily useful for testing or for releasing memory when shaders
  /// are no longer needed. Note that clearing the cache does NOT dispose of
  /// the underlying [ui.FragmentProgram]s - they are managed by Flutter's
  /// asset system.
  ///
  /// After calling this method, newly created [MultiShaderBuilder]s (or
  /// existing ones that trigger `_loadShaders` again) will reload their shaders
  /// asynchronously. Existing instances keep their current shaders in memory.
  /// In-flight loads may repopulate the cache after this call.
  static void clearCache() {
    _MultiShaderBuilderState._shaderCache.clear();
  }

  /// Returns true if the shader with the given [assetKey] is cached.
  static bool isCached(String assetKey) {
    return _MultiShaderBuilderState._shaderCache.containsKey(assetKey);
  }
}

class _MultiShaderBuilderState extends State<MultiShaderBuilder> {
  final Map<String, ui.FragmentProgram> _programs = {};
  final Map<String, ui.FragmentShader> _shaders = {};

  static final Map<String, ui.FragmentProgram> _shaderCache =
      <String, ui.FragmentProgram>{};

  @override
  void initState() {
    super.initState();
    _loadShaders(widget.assetKeys);
  }

  @override
  void didUpdateWidget(covariant MultiShaderBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetKeys != widget.assetKeys) {
      _loadShaders(widget.assetKeys);
    }
  }

  void _loadShaders(List<String> assetKeys) {
    _programs.clear();
    _shaders.clear();

    // Check which shaders are already cached
    final uncachedKeys = <String>[];
    for (final assetKey in assetKeys) {
      if (_shaderCache[assetKey] case final program?) {
        _programs[assetKey] = program;
        _shaders[assetKey] = program.fragmentShader();
      } else {
        uncachedKeys.add(assetKey);
      }
    }

    // If all shaders are cached, we're done
    if (uncachedKeys.isEmpty) {
      return;
    }

    // Load uncached shaders
    for (final assetKey in uncachedKeys) {
      ui.FragmentProgram.fromAsset(assetKey).then(
        (ui.FragmentProgram program) {
          if (!mounted) {
            return;
          }
          setState(() {
            _programs[assetKey] = program;
            _shaders[assetKey] = program.fragmentShader();
            _shaderCache[assetKey] = program;
          });
        },
        onError: (Object error, StackTrace stackTrace) {
          FlutterError.reportError(
            FlutterErrorDetails(exception: error, stack: stackTrace),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Build the shader list in the same order as assetKeys, showing only the
    // child until all of them are loaded.
    final shaders = <ui.FragmentShader>[];
    for (final key in widget.assetKeys) {
      final shader = _shaders[key];
      if (shader == null) return widget.child ?? const SizedBox.shrink();
      shaders.add(shader);
    }

    return widget.builder(context, shaders, widget.child);
  }
}
