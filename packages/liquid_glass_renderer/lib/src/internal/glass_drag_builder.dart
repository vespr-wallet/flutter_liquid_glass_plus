import 'package:flutter/widgets.dart';
import 'package:liquid_glass_plus/src/internal/glass_pan_region.dart';
import 'package:meta/meta.dart';

/// {@template gesture_mode}
/// Controls which gesture handling mechanism is used to detect interactions.
///
/// [GestureMode.listener] (the default) uses a [Listener], which responds to
/// raw pointer events before they are consumed by any gesture recognizer. This
/// means the effect triggers regardless of what nested widgets do with the
/// gesture.
///
/// [GestureMode.gestureDetector] uses a [GestureDetector] instead, which
/// participates in the gesture arena. Nested widgets such as buttons can claim
/// the gesture so the parent pan never wins. The drag state only begins in
/// [GestureDetector.onPanStart] (after the pan wins the arena), not on the
/// preliminary [GestureDetector.onPanDown], so the effect will **not** trigger
/// when a descendant handles the interaction. [GestureDetector.onPanCancel]
/// clears the drag when the pan loses the arena.
///
/// A `LiquidStretch` and a `GlassGlow` nested directly in each other, both in
/// [GestureMode.gestureDetector], share a single pan recognizer, so both
/// effects follow the same drag.
/// {@endtemplate}
enum GestureMode {
  /// Responds to all raw pointer events via a [Listener], including those
  /// consumed by nested widgets.
  listener,

  /// Participates in gesture disambiguation via a [GestureDetector], allowing
  /// nested interactive widgets (e.g. buttons) to claim the gesture and
  /// suppress the effect.
  gestureDetector,
}

@internal
class GlassDragBuilder extends StatefulWidget {
  const GlassDragBuilder({
    required this.builder,
    this.behavior = HitTestBehavior.opaque,
    this.gestureMode = GestureMode.listener,
    this.child,
    super.key,
  });

  final HitTestBehavior behavior;

  final GestureMode gestureMode;

  final ValueWidgetBuilder<Offset?> builder;

  final Widget? child;

  @override
  State<GlassDragBuilder> createState() => _GlassDragBuilderState();
}

class _GlassDragBuilderState extends State<GlassDragBuilder> {
  Offset? currentDragOffset;

  bool get isDragging => currentDragOffset != null;

  // Pointer callbacks can still arrive after this state was disposed, for
  // example when the widget is removed from the tree while a gesture is
  // active. Calling setState then throws, so every update checks [mounted].
  void _startDrag() {
    if (!mounted) return;
    setState(() {
      currentDragOffset = Offset.zero;
    });
  }

  void _updateDrag(Offset delta) {
    if (!mounted) return;
    setState(() {
      currentDragOffset = (currentDragOffset ?? Offset.zero) + delta;
    });
  }

  void _endDrag() {
    if (!mounted) return;
    setState(() {
      currentDragOffset = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.builder(context, currentDragOffset, widget.child);
    switch (widget.gestureMode) {
      case GestureMode.listener:
        return Listener(
          behavior: widget.behavior,
          onPointerDown: (event) => _startDrag(),
          onPointerMove: (event) => _updateDrag(event.delta),
          onPointerUp: (event) => _endDrag(),
          onPointerCancel: (event) => _endDrag(),
          child: child,
        );
      case GestureMode.gestureDetector:
        return GlassPanRegion(
          role: GlassPanRole.stretch,
          behavior: widget.behavior,
          onStart: (position) => _startDrag(),
          onUpdate: (position, delta) => _updateDrag(delta),
          onEnd: _endDrag,
          child: child,
        );
    }
  }
}
