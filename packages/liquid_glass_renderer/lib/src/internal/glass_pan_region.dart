import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

/// The effect a [GlassPanRegion] drives.
@internal
enum GlassPanRole {
  /// A `GlassGlow`.
  glow,

  /// A `LiquidStretch`.
  stretch,
}

/// Receives pan events from a [GlassPanHub].
@internal
abstract interface class GlassPanListener {
  void onHubPanStart(Offset globalPosition);
  void onHubPanUpdate(Offset globalPosition, Offset delta);
  void onHubPanEnd();
}

/// Broadcasts the pan of one [GlassPanRegion] to a nested region of the other
/// role, so a glow and a stretch on the same element share one recognizer.
@internal
class GlassPanHub {
  final _listeners = <GlassPanListener>{};

  void addListener(GlassPanListener listener) => _listeners.add(listener);

  void removeListener(GlassPanListener listener) => _listeners.remove(listener);

  void start(Offset globalPosition) {
    for (final listener in List.of(_listeners)) {
      listener.onHubPanStart(globalPosition);
    }
  }

  void update(Offset globalPosition, Offset delta) {
    for (final listener in List.of(_listeners)) {
      listener.onHubPanUpdate(globalPosition, delta);
    }
  }

  void end() {
    for (final listener in List.of(_listeners)) {
      listener.onHubPanEnd();
    }
  }
}

class _GlassPanScope extends InheritedWidget {
  const _GlassPanScope({
    required this.hub,
    required this.role,
    required super.child,
  });

  /// The hub to join, or null when nested regions must use their own
  /// recognizer.
  final GlassPanHub? hub;

  final GlassPanRole role;

  @override
  bool updateShouldNotify(_GlassPanScope oldWidget) =>
      hub != oldWidget.hub || role != oldWidget.role;
}

/// Detects pans through a [GestureDetector] that takes part in the gesture
/// arena, for `GestureMode.gestureDetector`.
///
/// Two nested pan detectors compete in the arena and only one of them wins,
/// so a `LiquidStretch` around a `GlassGlow` (or the other way around) would
/// lose one of the two effects. To avoid that, the outer region shares its
/// pan with the nearest nested region of the other role, which then adds no
/// recognizer of its own. Only one pair shares a recognizer: regions nested
/// deeper (for example in a nested glass element) use their own, so nested
/// interactive widgets can still claim the gesture.
@internal
class GlassPanRegion extends StatefulWidget {
  const GlassPanRegion({
    required this.role,
    required this.behavior,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
    required this.child,
    super.key,
  });

  final GlassPanRole role;

  final HitTestBehavior behavior;

  /// Called with the local position when a pan starts on this region.
  final ValueChanged<Offset> onStart;

  /// Called with the local position and the delta when the pan moves.
  final void Function(Offset localPosition, Offset delta) onUpdate;

  /// Called when the pan ends, is cancelled, or loses the arena.
  final VoidCallback onEnd;

  final Widget child;

  @override
  State<GlassPanRegion> createState() => _GlassPanRegionState();
}

class _GlassPanRegionState extends State<GlassPanRegion>
    implements GlassPanListener {
  final _ownHub = GlassPanHub();

  /// The hub of an outer region of the other role that this region joined.
  GlassPanHub? _joinedHub;

  /// Whether the shared pan started inside this region.
  bool _trackingSharedPan = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = context.dependOnInheritedWidgetOfExactType<_GlassPanScope>();
    final hub = scope != null && scope.role != widget.role ? scope.hub : null;
    if (hub == _joinedHub) return;
    _joinedHub?.removeListener(this);
    _joinedHub = hub;
    hub?.addListener(this);
    _trackingSharedPan = false;
  }

  @override
  void dispose() {
    _joinedHub?.removeListener(this);
    super.dispose();
  }

  RenderBox? get _box => switch (context.findRenderObject()) {
        final RenderBox box when box.attached && box.hasSize => box,
        _ => null,
      };

  @override
  void onHubPanStart(Offset globalPosition) {
    if (!mounted) return;
    final box = _box;
    if (box == null) return;
    final local = box.globalToLocal(globalPosition);
    // Only follow shared pans that start on this region.
    if (!(Offset.zero & box.size).contains(local)) return;
    _trackingSharedPan = true;
    widget.onStart(local);
  }

  @override
  void onHubPanUpdate(Offset globalPosition, Offset delta) {
    if (!mounted || !_trackingSharedPan) return;
    final box = _box;
    if (box == null) return;
    widget.onUpdate(box.globalToLocal(globalPosition), delta);
  }

  @override
  void onHubPanEnd() {
    if (!mounted || !_trackingSharedPan) return;
    _trackingSharedPan = false;
    widget.onEnd();
  }

  void _handleStart(DragStartDetails details) {
    if (!mounted) return;
    widget.onStart(details.localPosition);
    _ownHub.start(details.globalPosition);
  }

  void _handleUpdate(DragUpdateDetails details) {
    if (!mounted) return;
    widget.onUpdate(details.localPosition, details.delta);
    _ownHub.update(details.globalPosition, details.delta);
  }

  void _handleEnd() {
    if (!mounted) return;
    widget.onEnd();
    _ownHub.end();
  }

  @override
  Widget build(BuildContext context) {
    if (_joinedHub != null) {
      // Driven by the outer region. Hide the hub from deeper regions so they
      // use their own recognizer.
      return _GlassPanScope(
        hub: null,
        role: widget.role,
        child: widget.child,
      );
    }

    return GestureDetector(
      behavior: widget.behavior,
      onPanStart: _handleStart,
      onPanUpdate: _handleUpdate,
      onPanEnd: (details) => _handleEnd(),
      onPanCancel: _handleEnd,
      child: _GlassPanScope(
        hub: _ownHub,
        role: widget.role,
        child: widget.child,
      ),
    );
  }
}
