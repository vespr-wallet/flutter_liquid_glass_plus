import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:liquid_glass_plus/src/internal/glass_drag_builder.dart';
import 'package:motor/motor.dart';

/// {@template glass_glow}
/// If placed as a descendant of a [GlassGlowLayer], this widget will
/// send touch updates to that layer to create a glow effect.
/// {@endtemplate}
class GlassGlow extends StatelessWidget {
  /// {@macro glass_glow}
  const GlassGlow({
    required this.child,
    this.glowColor = const Color(0x3DFFFFFF),
    this.glowRadius = 1,
    this.hitTestBehavior = HitTestBehavior.opaque,
    this.gestureMode = GestureMode.listener,
    super.key,
  });

  /// The radius of the glow effect relative to the layer's shortest side.
  ///
  /// A value of 0.8 means the glow radius will be 80% of the shortest
  /// dimension (width or height) of the [GlassGlowLayer].
  ///
  /// Defaults to 1.
  final double glowRadius;

  /// The color of the glow effect.
  ///
  /// The glow will have this colors opacity at the center, and will fade out
  /// to fully transparent at the edge of the glow.
  final Color glowColor;

  /// The hit test behavior of this gesture listener.
  ///
  /// Defaults to [HitTestBehavior.opaque].
  final HitTestBehavior hitTestBehavior;

  /// {@macro gesture_mode}
  ///
  /// Defaults to [GestureMode.listener].
  final GestureMode gestureMode;

  /// The child that will be painted above the glow effect.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    switch (gestureMode) {
      case GestureMode.listener:
        return Listener(
          behavior: hitTestBehavior,
          onPointerDown: (event) =>
              _handlePointer(context, event.localPosition),
          onPointerMove: (event) =>
              _handlePointer(context, event.localPosition),
          onPointerUp: (event) => _removeTouch(context),
          onPointerCancel: (event) => _removeTouch(context),
          child: child,
        );
      case GestureMode.gestureDetector:
        return GestureDetector(
          behavior: hitTestBehavior,
          onPanStart: (details) =>
              _handlePointer(context, details.localPosition),
          onPanUpdate: (details) =>
              _handlePointer(context, details.localPosition),
          onPanEnd: (details) => _removeTouch(context),
          onPanCancel: () => _removeTouch(context),
          child: child,
        );
    }
  }

  void _handlePointer(BuildContext context, Offset position) {
    final layerState = GlassGlowLayer.maybeOf(context);

    layerState?.updateTouch(
      position,
      radius: glowRadius,
      color: glowColor,
    );
  }

  void _removeTouch(BuildContext context) {
    GlassGlowLayer.maybeOf(context)?.removeTouch();
  }
}

/// {@template glass_glow}
/// Represents a layer that can paint a glowing effect below its child.
///
/// Any child [GlassGlow] will send touch updates to this layer to
/// update the glow effect.
///
/// This is similar to how an `InkWell` works with a `Material` widget.
/// {@endtemplate}
class GlassGlowLayer extends StatefulWidget {
  /// {@macro glass_glow}
  const GlassGlowLayer({
    required this.child,
    super.key,
  });

  /// The child that will be painted above the glow effect.
  final Widget child;

  @override
  State<GlassGlowLayer> createState() => GlassGlowLayerState();

  /// Returns the [GlassGlowLayerState] from the closest [GlassGlowLayer]
  /// ancestor, or null if none exists.
  ///
  /// This is used by [GlassGlow] widgets to send touch updates to their
  /// parent layer.
  static GlassGlowLayerState? maybeOf(BuildContext context) {
    if (!context.mounted) return null;
    return context.findAncestorStateOfType<GlassGlowLayerState>();
  }
}

/// The state for a [GlassGlowLayer].
///
/// This class is public to allow [GlassGlow] widgets to update the glow
/// effect via [updateTouch] and [removeTouch]. You typically don't need to
/// interact with this class directly.
class GlassGlowLayerState extends State<GlassGlowLayer>
    with TickerProviderStateMixin {
  late final _offsetController = MotionController<Offset>(
    vsync: this,
    converter: const OffsetMotionConverter(),
    initialValue: Offset.zero,
    motion: const Motion.smoothSpring(
      duration: Duration(seconds: 1),
      snapToEnd: true,
    ),
  );

  late final _alphaController = BoundedSingleMotionController(
    vsync: this,
    motion: const Motion.smoothSpring(snapToEnd: true),
  );

  late final _radiusController = SingleMotionController(
    vsync: this,
    motion: const Motion.smoothSpring(snapToEnd: true),
    initialValue: 10,
  );

  bool _dragging = false;

  /// Whether a [GlassGlow] descendant currently has an active touch.
  @visibleForTesting
  bool get hasActiveTouch => _dragging;

  double _baseRadius = 0;
  Color _baseColor = const Color.fromARGB(0, 0, 0, 0);

  @override
  void dispose() {
    _offsetController.dispose();
    _alphaController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  /// Updates the glow effect position and appearance.
  ///
  /// Called by [GlassGlow] when the user touches or drags on the widget.
  /// The [offset] is the local position within the layer, [radius] is the
  /// glow radius relative to the layer's shortest side, and [color] is
  /// the glow color.
  void updateTouch(
    Offset offset, {
    required double radius,
    required Color color,
  }) {
    setState(() {
      _baseRadius = radius;
      _baseColor = color;
    });

    if (!_dragging) {
      _dragging = true;
      _radiusController.motion = _alphaController.motion =
          const Motion.interactiveSpring(snapToEnd: true);
      _radiusController.animateTo(1, from: 0);
      _alphaController.animateTo(1, from: 0);
    }

    _offsetController.value = offset;
  }

  /// Removes the active touch and animates the glow out.
  ///
  /// Called by [GlassGlow] when the user lifts their finger or the
  /// touch is cancelled.
  void removeTouch() {
    if (!_dragging) return;
    _radiusController.motion =
        _alphaController.motion = const Motion.smoothSpring(snapToEnd: true);
    _dragging = false;
    _offsetController.animateTo(Offset.zero);
    _radiusController.animateTo(10);
    _alphaController.animateTo(0);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        _offsetController,
        _alphaController,
        _radiusController,
      ]),
      builder: (context, child) {
        return _RenderGlassGlowLayerWidget(
          glowRadius: _baseRadius * _radiusController.value,
          glowColor: _baseColor.withValues(
            alpha: _baseColor.a * _alphaController.value,
          ),
          glowOffset: _offsetController.value,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _RenderGlassGlowLayerWidget extends SingleChildRenderObjectWidget {
  const _RenderGlassGlowLayerWidget({
    required this.glowRadius,
    required this.glowColor,
    required this.glowOffset,
    required super.child,
  });

  final double glowRadius;
  final Color glowColor;
  final Offset glowOffset;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderGlassGlowLayer(
      glowRadius: glowRadius,
      glowColor: glowColor,
      glowOffset: glowOffset,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderGlassGlowLayer renderObject,
  ) {
    renderObject
      ..glowRadius = glowRadius
      ..glowColor = glowColor
      ..glowOffset = glowOffset;
  }
}

class _RenderGlassGlowLayer extends RenderProxyBox {
  _RenderGlassGlowLayer({
    required double glowRadius,
    required Color glowColor,
    required Offset glowOffset,
  })  : _glowRadius = glowRadius,
        _glowColor = glowColor,
        _glowOffset = glowOffset;

  double _glowRadius;
  double get glowRadius => _glowRadius;
  set glowRadius(double value) {
    if (_glowRadius == value) return;
    _glowRadius = value;
    markNeedsPaint();
  }

  Color _glowColor;
  Color get glowColor => _glowColor;
  set glowColor(Color value) {
    if (_glowColor == value) return;
    _glowColor = value;
    markNeedsPaint();
  }

  Offset _glowOffset;
  Offset get glowOffset => _glowOffset;
  set glowOffset(Offset value) {
    if (_glowOffset == value) return;
    _glowOffset = value;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_glowColor.a == 0 || _glowRadius <= 0) {
      // No glow to paint
      super.paint(context, offset);
      return;
    }

    final canvas = context.canvas..save();

    final glowPosition = offset + _glowOffset;

    final gradient = RadialGradient(
      colors: [
        _glowColor,
        _glowColor.withValues(alpha: 0),
      ],
      stops: const [0.0, 1.0],
    );

    final radius = _glowRadius * size.shortestSide;

    final paint = Paint()
      ..shader = gradient.createShader(
        Rect.fromCircle(center: glowPosition, radius: radius),
      )
      ..blendMode = BlendMode.plus;

    canvas
      ..drawCircle(
        glowPosition,
        radius,
        paint,
      )
      ..restore();
    super.paint(context, offset);
  }
}
