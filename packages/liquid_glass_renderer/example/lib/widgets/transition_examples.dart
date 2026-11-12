// The example's third-party UI packages still build on package:flutter's
// material/cupertino libraries, so it stays on them for now.
// ignore_for_file: deprecated_member_use

// Isolated transition examples demonstrating LiquidGlass animations
// These examples showcase flat-to-glass, settings, and shape transitions
// Includes performance measurement for A/B testing real vs fake glass

import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';
import 'package:liquid_glass_plus/liquid_glass_plus.dart';

// =============================================================================
// ENUMS AND GLOBAL STATE
// =============================================================================

/// Controls which glass type to display.
enum DisplayMode {
  both('Both'),
  realOnly('Real Only'),
  fakeOnly('Fake Only');

  const DisplayMode(this.label);
  final String label;
}

/// Controls frost setting across all examples.
enum FrostMode {
  individual('Individual'),
  allFrosted('All Frosted'),
  allClear('All Clear');

  const FrostMode(this.label);
  final String label;
}

/// Provides global settings to descendant widgets.
class _GlobalSettings extends InheritedWidget {
  const _GlobalSettings({
    required this.displayMode,
    required this.frostMode,
    required super.child,
  });

  final DisplayMode displayMode;
  final FrostMode frostMode;

  static _GlobalSettings of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_GlobalSettings>()!;
  }

  @override
  bool updateShouldNotify(_GlobalSettings oldWidget) =>
      displayMode != oldWidget.displayMode || frostMode != oldWidget.frostMode;
}

// =============================================================================
// PERFORMANCE MEASUREMENT
// =============================================================================

/// Tracks frame timing statistics.
class FrameStats {
  final List<Duration> _frameTimes = [];
  static const int _maxSamples = 120; // ~2 seconds at 60fps

  void addFrame(Duration frameTime) {
    _frameTimes.add(frameTime);
    if (_frameTimes.length > _maxSamples) {
      _frameTimes.removeAt(0);
    }
  }

  void clear() => _frameTimes.clear();

  int get sampleCount => _frameTimes.length;

  double get averageMs {
    if (_frameTimes.isEmpty) return 0;
    final total = _frameTimes.fold<int>(0, (sum, d) => sum + d.inMicroseconds);
    return total / _frameTimes.length / 1000;
  }

  double get maxMs {
    if (_frameTimes.isEmpty) return 0;
    return _frameTimes
            .map((d) => d.inMicroseconds)
            .reduce((a, b) => a > b ? a : b) /
        1000;
  }

  double get minMs {
    if (_frameTimes.isEmpty) return 0;
    return _frameTimes
            .map((d) => d.inMicroseconds)
            .reduce((a, b) => a < b ? a : b) /
        1000;
  }

  int get droppedFrames {
    // Count frames over 16.67ms (60fps threshold)
    return _frameTimes.where((d) => d.inMicroseconds > 16667).length;
  }

  double get fps {
    if (averageMs <= 0) return 0;
    return 1000 / averageMs;
  }
}

/// Widget that measures and displays frame performance.
class _PerformanceMonitor extends StatefulWidget {
  const _PerformanceMonitor({required this.child});

  final Widget child;

  @override
  State<_PerformanceMonitor> createState() => _PerformanceMonitorState();
}

class _PerformanceMonitorState extends State<_PerformanceMonitor> {
  final FrameStats _stats = FrameStats();
  Duration? _lastFrameTime;
  bool _isTracking = false;

  void _onFrame(Duration timestamp) {
    if (!_isTracking) return;

    if (_lastFrameTime != null) {
      final frameTime = timestamp - _lastFrameTime!;
      _stats.addFrame(frameTime);
      // Update UI every 10 frames to reduce overhead
      if (_stats.sampleCount % 10 == 0) {
        setState(() {});
      }
    }
    _lastFrameTime = timestamp;
    SchedulerBinding.instance.scheduleFrameCallback(_onFrame);
  }

  void _startTracking() {
    if (_isTracking) return;
    _isTracking = true;
    _stats.clear();
    _lastFrameTime = null;
    SchedulerBinding.instance.scheduleFrameCallback(_onFrame);
  }

  void _stopTracking() {
    _isTracking = false;
  }

  void _resetStats() {
    _stats.clear();
    setState(() {});
  }

  @override
  void dispose() {
    _isTracking = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Performance stats bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: CupertinoColors.systemBackground.resolveFrom(context),
          child: Row(
            children: [
              // Stats display
              Expanded(
                child: Text(
                  _isTracking
                      ? 'FPS: ${_stats.fps.toStringAsFixed(1)} | '
                            'Avg: ${_stats.averageMs.toStringAsFixed(2)}ms | '
                            'Max: ${_stats.maxMs.toStringAsFixed(2)}ms | '
                            'Drops: ${_stats.droppedFrames}'
                      : 'Performance tracking stopped',
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Menlo',
                    color: _stats.droppedFrames > 5
                        ? CupertinoColors.systemRed
                        : CupertinoColors.label.resolveFrom(context),
                  ),
                ),
              ),
              // Control buttons
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(28, 28),
                onPressed: _isTracking ? _stopTracking : _startTracking,
                child: Icon(
                  _isTracking
                      ? CupertinoIcons.pause_fill
                      : CupertinoIcons.play_fill,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(28, 28),
                onPressed: _resetStats,
                child: const Icon(CupertinoIcons.refresh, size: 18),
              ),
            ],
          ),
        ),
        Expanded(child: widget.child),
      ],
    );
  }
}

// =============================================================================
// MAIN PAGE
// =============================================================================

/// A page showcasing various glass transition examples.
///
/// Each example is isolated in its own widget for easy review.
class TransitionExamplesPage extends StatefulWidget {
  const TransitionExamplesPage({super.key});

  @override
  State<TransitionExamplesPage> createState() => _TransitionExamplesPageState();
}

class _TransitionExamplesPageState extends State<TransitionExamplesPage> {
  DisplayMode _displayMode = DisplayMode.both;
  FrostMode _frostMode = FrostMode.individual;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Transition Examples'),
      ),
      child: _GlobalSettings(
        displayMode: _displayMode,
        frostMode: _frostMode,
        child: SafeArea(
          child: _PerformanceMonitor(
            child: Column(
              children: [
                // Global controls
                _GlobalControls(
                  displayMode: _displayMode,
                  frostMode: _frostMode,
                  onDisplayModeChanged: (mode) =>
                      setState(() => _displayMode = mode),
                  onFrostModeChanged: (mode) =>
                      setState(() => _frostMode = mode),
                ),
                // Examples list
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Stress test sections first for easy benchmarking
                      _Section(
                        title: 'Many Individual Layers (Stress Test)',
                        description:
                            'Each glass item has its own LiquidGlassLayer. '
                            'Tests per-layer overhead.',
                        realChildBuilder: (frosted) =>
                            ManyIndividualLayersExample(
                              frosted: frosted,
                              fake: false,
                            ),
                        fakeChildBuilder: (frosted) =>
                            ManyIndividualLayersExample(
                              frosted: frosted,
                              fake: true,
                            ),
                      ),
                      const SizedBox(height: 32),
                      _Section(
                        title: 'Shared Layer (Stress Test)',
                        description:
                            'Many glass items share a single LiquidGlassLayer. '
                            'Tests shader complexity with multiple shapes.',
                        realChildBuilder: (frosted) =>
                            SharedLayerExample(frosted: frosted, fake: false),
                        fakeChildBuilder: (frosted) =>
                            SharedLayerExample(frosted: frosted, fake: true),
                      ),
                      const SizedBox(height: 32),
                      _Section(
                        title: 'Bouncing Glass',
                        description:
                            'Glass element bouncing around like a DVD screensaver, '
                            'showcasing refraction and reflection during movement.',
                        realChildBuilder: (frosted) =>
                            BouncingGlassExample(frosted: frosted, fake: false),
                        fakeChildBuilder: (frosted) =>
                            BouncingGlassExample(frosted: frosted, fake: true),
                      ),
                      const SizedBox(height: 32),
                      _Section(
                        title: 'Flat to Glass Transition',
                        description:
                            'Transitions from a solid colored container to a glass '
                            'effect by animating blur and thickness.',
                        realChildBuilder: (frosted) =>
                            FlatToGlassExample(frosted: frosted, fake: false),
                        fakeChildBuilder: (frosted) =>
                            FlatToGlassExample(frosted: frosted, fake: true),
                      ),
                      const SizedBox(height: 32),
                      _Section(
                        title: 'Glass Intensity',
                        description:
                            'Animates glass intensity from subtle to prominent by '
                            'changing blur, thickness, and saturation.',
                        realChildBuilder: (frosted) => GlassIntensityExample(
                          frosted: frosted,
                          fake: false,
                        ),
                        fakeChildBuilder: (frosted) =>
                            GlassIntensityExample(frosted: frosted, fake: true),
                      ),
                      const SizedBox(height: 32),
                      _Section(
                        title: 'Border Radius Animation',
                        description:
                            'Animates the shape borderRadius from sharp (8) to '
                            'rounded (64) using LiquidShape.lerp.',
                        realChildBuilder: (frosted) =>
                            BorderRadiusAnimationExample(
                              frosted: frosted,
                              fake: false,
                            ),
                        fakeChildBuilder: (frosted) =>
                            BorderRadiusAnimationExample(
                              frosted: frosted,
                              fake: true,
                            ),
                      ),
                      const SizedBox(height: 32),
                      _Section(
                        title: 'Combined Transition',
                        description:
                            'Combines shape, settings, and size animations together.',
                        realChildBuilder: (frosted) =>
                            CombinedTransitionExample(
                              frosted: frosted,
                              fake: false,
                            ),
                        fakeChildBuilder: (frosted) =>
                            CombinedTransitionExample(
                              frosted: frosted,
                              fake: true,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Global controls for display mode and frost mode.
class _GlobalControls extends StatelessWidget {
  const _GlobalControls({
    required this.displayMode,
    required this.frostMode,
    required this.onDisplayModeChanged,
    required this.onFrostModeChanged,
  });

  final DisplayMode displayMode;
  final FrostMode frostMode;
  final ValueChanged<DisplayMode> onDisplayModeChanged;
  final ValueChanged<FrostMode> onFrostModeChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
        border: Border(
          bottom: BorderSide(
            color: CupertinoColors.separator.resolveFrom(context),
          ),
        ),
      ),
      child: Row(
        children: [
          // Display mode dropdown
          Expanded(
            child: _DropdownButton<DisplayMode>(
              label: 'Show',
              value: displayMode,
              items: DisplayMode.values,
              onChanged: onDisplayModeChanged,
            ),
          ),
          const SizedBox(width: 16),
          // Frost mode dropdown
          Expanded(
            child: _DropdownButton<FrostMode>(
              label: 'Frost',
              value: frostMode,
              items: FrostMode.values,
              onChanged: onFrostModeChanged,
            ),
          ),
        ],
      ),
    );
  }
}

/// A styled dropdown button.
class _DropdownButton<T extends Enum> extends StatelessWidget {
  const _DropdownButton({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 13,
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
        ),
        Expanded(
          child: CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: CupertinoColors.tertiarySystemBackground.resolveFrom(
              context,
            ),
            borderRadius: BorderRadius.circular(8),
            minimumSize: Size.zero,
            onPressed: () => _showPicker(context),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  (value as dynamic).label as String,
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.label.resolveFrom(context),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  CupertinoIcons.chevron_down,
                  size: 12,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showPicker(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: items.map((item) {
          return CupertinoActionSheetAction(
            onPressed: () {
              onChanged(item);
              Navigator.pop(context);
            },
            child: Text((item as dynamic).label as String),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }
}

// =============================================================================
// SECTION COMPONENT
// =============================================================================

/// A complete section with header, description, and example row.
class _Section extends StatefulWidget {
  const _Section({
    required this.title,
    required this.description,
    required this.realChildBuilder,
    required this.fakeChildBuilder,
  });

  final String title;
  final String description;
  final Widget Function(bool frosted) realChildBuilder;
  final Widget Function(bool frosted) fakeChildBuilder;

  @override
  State<_Section> createState() => _SectionState();
}

class _SectionState extends State<_Section> {
  int _imageId = Random().nextInt(1000);
  bool _localFrosted = true;

  void _refreshImage() {
    setState(() {
      _imageId = Random().nextInt(10000);
    });
  }

  @override
  Widget build(BuildContext context) {
    final globalSettings = _GlobalSettings.of(context);
    final displayMode = globalSettings.displayMode;
    final frostMode = globalSettings.frostMode;

    // Determine effective frost setting
    final effectiveFrosted = switch (frostMode) {
      FrostMode.individual => _localFrosted,
      FrostMode.allFrosted => true,
      FrostMode.allClear => false,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: widget.title,
          onRefresh: _refreshImage,
          trailing: frostMode == FrostMode.individual
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Frost',
                      style: TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.systemGrey.resolveFrom(context),
                      ),
                    ),
                    const SizedBox(width: 4),
                    CupertinoSwitch(
                      value: _localFrosted,
                      onChanged: (value) =>
                          setState(() => _localFrosted = value),
                    ),
                  ],
                )
              : null,
        ),
        _SectionDescription(text: widget.description),
        _buildExampleRow(displayMode, effectiveFrosted),
      ],
    );
  }

  Widget _buildExampleRow(DisplayMode displayMode, bool frosted) {
    return _SharedImageId(
      imageId: _imageId,
      child: switch (displayMode) {
        DisplayMode.both => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _ColumnLabel(text: 'Real Glass'),
                  widget.realChildBuilder(frosted),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _ColumnLabel(text: 'Fake Glass'),
                  widget.fakeChildBuilder(frosted),
                ],
              ),
            ),
          ],
        ),
        DisplayMode.realOnly => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _ColumnLabel(text: 'Real Glass'),
            widget.realChildBuilder(frosted),
          ],
        ),
        DisplayMode.fakeOnly => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _ColumnLabel(text: 'Fake Glass'),
            widget.fakeChildBuilder(frosted),
          ],
        ),
      },
    );
  }
}

/// Provides a shared image ID to descendant widgets.
class _SharedImageId extends InheritedWidget {
  const _SharedImageId({required this.imageId, required super.child});

  final int imageId;

  static int of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_SharedImageId>()!
        .imageId;
  }

  @override
  bool updateShouldNotify(_SharedImageId oldWidget) =>
      imageId != oldWidget.imageId;
}

class _ColumnLabel extends StatelessWidget {
  const _ColumnLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: CupertinoColors.systemGrey.resolveFrom(context),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.onRefresh, this.trailing});

  final String title;
  final VoidCallback? onRefresh;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          ?trailing,
          if (onRefresh != null)
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(24, 24),
              onPressed: onRefresh,
              child: const Icon(CupertinoIcons.refresh, size: 18),
            ),
        ],
      ),
    );
  }
}

class _SectionDescription extends StatelessWidget {
  const _SectionDescription({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: CupertinoColors.systemGrey.resolveFrom(context),
        ),
      ),
    );
  }
}

// =============================================================================
// STRESS TEST: Many Individual Layers
// =============================================================================

/// Stress test with many glass items, each with its own layer.
/// Tap items to toggle them on/off.
class ManyIndividualLayersExample extends StatefulWidget {
  const ManyIndividualLayersExample({
    super.key,
    required this.frosted,
    required this.fake,
  });
  final bool frosted;
  final bool fake;

  @override
  State<ManyIndividualLayersExample> createState() =>
      _ManyIndividualLayersExampleState();
}

class _ManyIndividualLayersExampleState
    extends State<ManyIndividualLayersExample> {
  static const int _itemCount = 15;
  final List<bool> _enabled = List.filled(_itemCount, true);

  int get _enabledCount => _enabled.where((e) => e).length;

  void _toggleItem(int index) {
    setState(() {
      _enabled[index] = !_enabled[index];
    });
  }

  void _enableAll() {
    setState(() {
      for (var i = 0; i < _enabled.length; i++) {
        _enabled[i] = true;
      }
    });
  }

  void _disableAll() {
    setState(() {
      for (var i = 0; i < _enabled.length; i++) {
        _enabled[i] = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final imageId = _SharedImageId.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Controls row
        Row(
          children: [
            Text(
              'Active: $_enabledCount/$_itemCount',
              style: TextStyle(
                fontSize: 12,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
            const Spacer(),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              onPressed: _enableAll,
              child: const Text('All On', style: TextStyle(fontSize: 12)),
            ),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              onPressed: _disableAll,
              child: const Text('All Off', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 320,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background
                Image.network(
                  'https://picsum.photos/2000/2000?random=$imageId',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          CupertinoColors.systemPurple.withValues(alpha: 0.5),
                          CupertinoColors.systemBlue.withValues(alpha: 0.5),
                        ],
                      ),
                    ),
                  ),
                ),
                // Grid of glass items
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(_itemCount, (index) {
                      final isEnabled = _enabled[index];
                      return GestureDetector(
                        onTap: () => _toggleItem(index),
                        child: isEnabled
                            ? LiquidGlass.withOwnLayer(
                                shape: const LiquidRoundedSuperellipse(
                                  borderRadius: 12,
                                ),
                                settings: LiquidGlassSettings(
                                  thickness: 12,
                                  frostIntensity: widget.frosted ? 5 : 0,
                                  lightIntensity: 0.4,
                                  glassColor: const Color.fromARGB(
                                    15,
                                    255,
                                    255,
                                    255,
                                  ),
                                  fakeGlassConfigs: FakeGlassConfigs(
                                    forceEnabled: widget.fake,
                                  ),
                                ),
                                child: SizedBox(
                                  width: 50,
                                  height: 50,
                                  child: Center(
                                    child: Text(
                                      '${index + 1}',
                                      style: const TextStyle(
                                        color: CupertinoColors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: CupertinoColors.white.withValues(
                                      alpha: 0.3,
                                    ),
                                    width: 1,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      color: CupertinoColors.white.withValues(
                                        alpha: 0.3,
                                      ),
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// STRESS TEST: Shared Layer
// =============================================================================

/// Stress test with many glass items sharing a single layer.
/// Tap items to toggle them on/off.
class SharedLayerExample extends StatefulWidget {
  const SharedLayerExample({
    super.key,
    required this.frosted,
    required this.fake,
  });
  final bool frosted;
  final bool fake;

  @override
  State<SharedLayerExample> createState() => _SharedLayerExampleState();
}

class _SharedLayerExampleState extends State<SharedLayerExample> {
  static const int _itemCount = 15;
  static const double _itemSize = 80;
  final List<bool> _enabled = List.filled(_itemCount, true);

  int get _enabledCount => _enabled.where((e) => e).length;

  void _toggleItem(int index) {
    setState(() {
      _enabled[index] = !_enabled[index];
    });
  }

  void _enableAll() {
    setState(() {
      for (var i = 0; i < _enabled.length; i++) {
        _enabled[i] = true;
      }
    });
  }

  void _disableAll() {
    setState(() {
      for (var i = 0; i < _enabled.length; i++) {
        _enabled[i] = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final imageId = _SharedImageId.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Controls row
        Row(
          children: [
            Text(
              'Active: $_enabledCount/$_itemCount',
              style: TextStyle(
                fontSize: 12,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
            const Spacer(),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              onPressed: _enableAll,
              child: const Text('All On', style: TextStyle(fontSize: 12)),
            ),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              onPressed: _disableAll,
              child: const Text('All Off', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 320,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background
                Image.network(
                  'https://picsum.photos/2000/2000?random=$imageId',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          CupertinoColors.systemOrange.withValues(alpha: 0.5),
                          CupertinoColors.systemRed.withValues(alpha: 0.5),
                        ],
                      ),
                    ),
                  ),
                ),
                // Single layer with many glass items
                LiquidGlassLayer(
                  settings: LiquidGlassSettings(
                    thickness: 12,
                    frostIntensity: widget.frosted ? 5 : 0,
                    lightIntensity: 0.4,
                    glassColor: const Color.fromARGB(15, 255, 255, 255),
                    fakeGlassConfigs: FakeGlassConfigs(
                      forceEnabled: widget.fake,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      runAlignment: WrapAlignment.center,
                      // crossAxisAlignment: WrapCrossAlignment.center,
                      children: List.generate(_itemCount, (index) {
                        final isEnabled = _enabled[index];
                        return GestureDetector(
                          onTap: () => _toggleItem(index),
                          child: isEnabled
                              ? LiquidStretch(
                                  child: LiquidGlass(
                                    shape: const LiquidRoundedSuperellipse(
                                      borderRadius: 12,
                                    ),
                                    child: GlassGlow(
                                      child: SizedBox(
                                        width: _itemSize,
                                        height: _itemSize,
                                        child: Center(
                                          child: Text(
                                            '${index + 1}',
                                            style: const TextStyle(
                                              color: CupertinoColors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              : Container(
                                  width: _itemSize,
                                  height: _itemSize,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: CupertinoColors.white.withValues(
                                        alpha: 0.3,
                                      ),
                                      width: 1,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        color: CupertinoColors.white.withValues(
                                          alpha: 0.3,
                                        ),
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// EXAMPLE 1: Flat to Glass Transition
// =============================================================================

/// Demonstrates transitioning from a flat colored container to a glass effect.
///
/// The "flat" state shows a semi-transparent colored container.
/// The "glass" state shows the full glass effect with blur and lighting.
/// Uses implicit animations - just change the settings and the widget animates.
class FlatToGlassExample extends StatefulWidget {
  const FlatToGlassExample({
    super.key,
    this.frosted = true,
    required this.fake,
  });
  final bool frosted;
  final bool fake;

  @override
  State<FlatToGlassExample> createState() => _FlatToGlassExampleState();
}

class _FlatToGlassExampleState extends State<FlatToGlassExample> {
  bool _isGlass = true; // Start as glass

  // Flat state: transparent container but no glass effects.
  // Use LiquidGlassSettings.flat() for clean flat-to-glass transitions.
  LiquidGlassSettings get _flatSettings =>
      const LiquidGlassSettings.flat(
        animationDuration: Duration(milliseconds: 600),
      ).copyWith(
        // Use copyWith on fakeGlassConfigs to preserve refraction: 0 from flat
        fakeGlassConfigs: const FakeGlassConfigs(
          refraction: 0,
        ).copyWith(forceEnabled: widget.fake),
      );

  // Glass state: full glass effect
  LiquidGlassSettings get _glassSettings => LiquidGlassSettings(
    thickness: 20,
    frostIntensity: widget.frosted ? 8 : 0,
    lightIntensity: 0.7,
    saturation: 1.5,
    glassColor: const Color.fromARGB(25, 255, 255, 255),
    animationDuration: const Duration(milliseconds: 600),
    fakeGlassConfigs: FakeGlassConfigs(forceEnabled: widget.fake),
  );

  void _toggle() {
    setState(() {
      _isGlass = !_isGlass;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = _isGlass ? _glassSettings : _flatSettings;

    return _ExampleContainer(
      onTap: _toggle,
      label: _isGlass
          ? 'Glass state - tap to flatten'
          : 'Flat state - tap for glass',
      child: LiquidStretch(
        interactionScale: 1.05,
        child: LiquidGlass.withOwnLayer(
          shape: const LiquidRoundedSuperellipse(borderRadius: 24),
          settings: settings,
          child: const GlassGlow(child: _ExampleContent(text: 'Flat ↔ Glass')),
        ),
      ),
    );
  }
}

// =============================================================================
// EXAMPLE 2: Glass Intensity
// =============================================================================

/// Demonstrates animating glass intensity from subtle to prominent.
/// Uses implicit animations - just change the settings and the widget animates.
class GlassIntensityExample extends StatefulWidget {
  const GlassIntensityExample({
    super.key,
    this.frosted = true,
    required this.fake,
  });
  final bool frosted;
  final bool fake;

  @override
  State<GlassIntensityExample> createState() => _GlassIntensityExampleState();
}

class _GlassIntensityExampleState extends State<GlassIntensityExample> {
  bool _intense = false;

  // Subtle glass
  LiquidGlassSettings get _subtleSettings => LiquidGlassSettings(
    thickness: 8,
    frostIntensity: widget.frosted ? 3 : 0,
    lightIntensity: 0.3,
    saturation: 1.2,
    glassColor: const Color.fromARGB(15, 200, 220, 255),
    animationDuration: const Duration(milliseconds: 700),
    fakeGlassConfigs: FakeGlassConfigs(forceEnabled: widget.fake),
  );

  // Intense glass
  LiquidGlassSettings get _intenseSettings => LiquidGlassSettings(
    thickness: 35,
    frostIntensity: widget.frosted ? 15 : 0,
    lightIntensity: 1.0,
    saturation: 1.8,
    glassColor: const Color.fromARGB(50, 255, 200, 150),
    animationDuration: const Duration(milliseconds: 700),
    fakeGlassConfigs: FakeGlassConfigs(forceEnabled: widget.fake),
  );

  void _toggle() {
    setState(() {
      _intense = !_intense;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = _intense ? _intenseSettings : _subtleSettings;

    return _ExampleContainer(
      onTap: _toggle,
      label: _intense ? 'Intense - tap for subtle' : 'Subtle - tap for intense',
      child: LiquidStretch(
        child: LiquidGlass.withOwnLayer(
          shape: const LiquidRoundedSuperellipse(borderRadius: 24),
          settings: settings,
          child: const GlassGlow(child: _ExampleContent(text: 'Intensity')),
        ),
      ),
    );
  }
}

// =============================================================================
// EXAMPLE 3: Border Radius Animation
// =============================================================================

/// Demonstrates animating the shape's border radius.
/// Uses implicit animations - just change the shape and the widget animates.
class BorderRadiusAnimationExample extends StatefulWidget {
  const BorderRadiusAnimationExample({
    super.key,
    this.frosted = true,
    required this.fake,
  });
  final bool frosted;
  final bool fake;

  @override
  State<BorderRadiusAnimationExample> createState() =>
      _BorderRadiusAnimationExampleState();
}

class _BorderRadiusAnimationExampleState
    extends State<BorderRadiusAnimationExample> {
  bool _isRounded = false;

  static const _sharpShape = LiquidRoundedSuperellipse(borderRadius: 8);
  static const _roundedShape = LiquidRoundedSuperellipse(borderRadius: 64);

  void _toggle() {
    setState(() {
      _isRounded = !_isRounded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final shape = _isRounded ? _roundedShape : _sharpShape;

    return _ExampleContainer(
      onTap: _toggle,
      label: _isRounded
          ? 'Rounded (64) - tap to sharpen'
          : 'Sharp (8) - tap to round',
      child: LiquidStretch(
        child: LiquidGlass.withOwnLayer(
          shape: shape,
          settings: LiquidGlassSettings(
            thickness: 20,
            frostIntensity: widget.frosted ? 8 : 0,
            lightIntensity: 0.6,
            glassColor: const Color.fromARGB(20, 255, 255, 255),
            animationDuration: const Duration(milliseconds: 500),
            fakeGlassConfigs: FakeGlassConfigs(forceEnabled: widget.fake),
          ),
          child: const GlassGlow(child: _ExampleContent(text: 'Border Radius')),
        ),
      ),
    );
  }
}

// =============================================================================
// EXAMPLE 4: Combined Transition
// =============================================================================

/// Demonstrates combining shape and settings transitions.
///
/// This example animates both the shape (borderRadius) and settings
/// (visibility, blur, etc.) simultaneously for a complete transformation.
/// Uses implicit animations for shape/settings, AnimatedContainer for size.
class CombinedTransitionExample extends StatefulWidget {
  const CombinedTransitionExample({
    super.key,
    this.frosted = true,
    required this.fake,
  });
  final bool frosted;
  final bool fake;

  @override
  State<CombinedTransitionExample> createState() =>
      _CombinedTransitionExampleState();
}

class _CombinedTransitionExampleState extends State<CombinedTransitionExample> {
  static const _animationDuration = Duration(milliseconds: 700);

  bool _expanded = false;

  // State A: Small, sharp corners, subtle glass
  static const _collapsedShape = LiquidRoundedSuperellipse(borderRadius: 12);
  LiquidGlassSettings get _collapsedSettings => LiquidGlassSettings(
    thickness: 10,
    frostIntensity: widget.frosted ? 4 : 0,
    lightIntensity: 0.3,
    glassColor: const Color.fromARGB(15, 200, 200, 255),
    animationDuration: _animationDuration,
    fakeGlassConfigs: FakeGlassConfigs(forceEnabled: widget.fake),
  );

  // State B: Large, rounded corners, prominent glass
  static const _expandedShape = LiquidRoundedSuperellipse(borderRadius: 48);
  LiquidGlassSettings get _expandedSettings => LiquidGlassSettings(
    thickness: 30,
    frostIntensity: widget.frosted ? 12 : 0,
    lightIntensity: 0.9,
    saturation: 1.6,
    glassColor: const Color.fromARGB(40, 255, 220, 150),
    animationDuration: _animationDuration,
    fakeGlassConfigs: FakeGlassConfigs(forceEnabled: widget.fake),
  );

  void _toggle() {
    setState(() {
      _expanded = !_expanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final shape = _expanded ? _expandedShape : _collapsedShape;
    final settings = _expanded ? _expandedSettings : _collapsedSettings;
    final size = _expanded ? const Size(200, 140) : const Size(120, 80);

    return _ExampleContainer(
      onTap: _toggle,
      label: _expanded
          ? 'Expanded - tap to collapse'
          : 'Collapsed - tap to expand',
      child: Center(
        // AnimatedContainer handles size animation
        child: AnimatedContainer(
          duration: _animationDuration,
          curve: Curves.easeInOut,
          width: size.width,
          height: size.height,
          // LiquidGlass handles shape/settings animation implicitly
          child: LiquidStretch(
            child: LiquidGlass.withOwnLayer(
              shape: shape,
              settings: settings,
              child: const GlassGlow(
                child: Center(
                  child: Text(
                    'Combined',
                    style: TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
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

// =============================================================================
// EXAMPLE 5: Bouncing Glass (DVD Screensaver)
// =============================================================================

/// Demonstrates a glass element bouncing around like a DVD screensaver.
///
/// This showcases how refraction and reflection look during continuous movement.
class BouncingGlassExample extends StatefulWidget {
  const BouncingGlassExample({
    super.key,
    this.frosted = true,
    required this.fake,
  });
  final bool frosted;
  final bool fake;

  @override
  State<BouncingGlassExample> createState() => _BouncingGlassExampleState();
}

class _BouncingGlassExampleState extends State<BouncingGlassExample>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // Position and velocity (1/3 of original speed)
  double _x = 20;
  double _y = 20;
  double _vx = 0.5; // velocity in x direction
  double _vy = 0.33; // velocity in y direction

  // Glass dimensions
  static const double _glassWidth = 80;
  static const double _glassHeight = 50;
  static const double _containerHeight = 180;

  // Container width (updated by LayoutBuilder)
  double _containerWidth = 200;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _controller.addListener(_updatePosition);
  }

  @override
  void dispose() {
    _controller.removeListener(_updatePosition);
    _controller.dispose();
    super.dispose();
  }

  void _updatePosition() {
    setState(() {
      final maxX = _containerWidth - _glassWidth;
      final maxY = _containerHeight - _glassHeight;

      // Update position
      _x += _vx;
      _y += _vy;

      // Bounce off walls
      if (_x <= 0 || _x >= maxX) {
        _vx = -_vx;
        _x = _x.clamp(0, maxX);
      }
      if (_y <= 0 || _y >= maxY) {
        _vy = -_vy;
        _y = _y.clamp(0, maxY);
      }
    });
  }

  void _onContainerWidth(double width) {
    if (width != _containerWidth) {
      _containerWidth = width;
      // Clamp position if container shrunk
      _x = _x.clamp(0, width - _glassWidth);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _BouncingContainer(
      glassX: _x,
      glassY: _y,
      glassWidth: _glassWidth,
      glassHeight: _glassHeight,
      containerHeight: _containerHeight,
      frosted: widget.frosted,
      fake: widget.fake,
      onContainerWidth: _onContainerWidth,
    );
  }
}

/// Container for the bouncing glass example that fills the available space.
class _BouncingContainer extends StatefulWidget {
  const _BouncingContainer({
    required this.glassX,
    required this.glassY,
    required this.glassWidth,
    required this.glassHeight,
    required this.containerHeight,
    required this.frosted,
    required this.fake,
    required this.onContainerWidth,
  });

  final double glassX;
  final double glassY;
  final double glassWidth;
  final double glassHeight;
  final double containerHeight;
  final bool frosted;
  final bool fake;
  final ValueChanged<double> onContainerWidth;

  @override
  State<_BouncingContainer> createState() => _BouncingContainerState();
}

class _BouncingContainerState extends State<_BouncingContainer> {
  double? _lastWidth;

  @override
  Widget build(BuildContext context) {
    final imageId = _SharedImageId.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: widget.containerHeight,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Only notify parent when width actually changes
            if (_lastWidth != constraints.maxWidth) {
              _lastWidth = constraints.maxWidth;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                widget.onContainerWidth(constraints.maxWidth);
              });
            }

            return Stack(
              fit: StackFit.expand,
              children: [
                // Background image
                Image.network(
                  'https://picsum.photos/2000/2000?random=$imageId',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          CupertinoColors.systemPurple.withValues(alpha: 0.5),
                          CupertinoColors.systemBlue.withValues(alpha: 0.5),
                        ],
                      ),
                    ),
                  ),
                ),
                // Bouncing glass element
                Positioned(
                  left: widget.glassX,
                  top: widget.glassY,
                  child: LiquidGlass.withOwnLayer(
                    shape: const LiquidRoundedSuperellipse(borderRadius: 16),
                    settings: LiquidGlassSettings(
                      thickness: 15,
                      frostIntensity: widget.frosted ? 6 : 0,
                      lightIntensity: 0.5,
                      glassColor: const Color.fromARGB(20, 255, 255, 255),
                      fakeGlassConfigs: FakeGlassConfigs(
                        forceEnabled: widget.fake,
                      ),
                    ),
                    child: SizedBox(
                      width: widget.glassWidth,
                      height: widget.glassHeight,
                      child: const Center(
                        child: Text(
                          'DVD',
                          style: TextStyle(
                            color: CupertinoColors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// =============================================================================
// SHARED COMPONENTS
// =============================================================================

/// Container for examples with background and tap handling.
class _ExampleContainer extends StatelessWidget {
  const _ExampleContainer({
    required this.child,
    required this.label,
    this.onTap,
  });

  final Widget child;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Get shared image ID from parent _Section
    final imageId = _SharedImageId.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 180,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Background image
                  Image.network(
                    'https://picsum.photos/2000/2000?random=$imageId',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            CupertinoColors.systemPurple.withValues(alpha: 0.5),
                            CupertinoColors.systemBlue.withValues(alpha: 0.5),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // The glass widget
                  Center(child: child),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: CupertinoColors.systemGrey.resolveFrom(context),
          ),
        ),
      ],
    );
  }
}

/// Default content for glass examples.
class _ExampleContent extends StatelessWidget {
  const _ExampleContent({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 100,
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            color: CupertinoColors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
