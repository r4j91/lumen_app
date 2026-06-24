import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// Wraps any widget with a 0.97 press-scale + spring-release feedback.
/// Use instead of plain GestureDetector/InkWell on cards and interactive tiles.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final GestureLongPressStartCallback? onLongPressStart;
  final double pressedScale;
  final HitTestBehavior behavior;
  final bool enabled;

  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.onLongPressStart,
    this.pressedScale = 0.97,
    this.behavior = HitTestBehavior.opaque,
    this.enabled = true,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  static const _spring = SpringDescription(mass: 1, stiffness: 380, damping: 22);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
    );
    _scale = Tween<double>(begin: 1.0, end: widget.pressedScale)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  void _press() {
    if (!widget.enabled) return;
    _ctrl.forward();
  }

  void _release() {
    _ctrl.animateWith(
      SpringSimulation(_spring, _ctrl.value, 0.0, -6.0),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: widget.enabled ? (_) => _press() : null,
      onTapUp: widget.enabled
          ? (_) {
              _release();
              widget.onTap?.call();
            }
          : null,
      onTapCancel: widget.enabled ? () => _release() : null,
      onLongPress: widget.onLongPress,
      onLongPressStart: widget.onLongPressStart,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
        child: widget.child,
      ),
    );
  }
}

/// Card-scale feedback: 80ms press-down with easeOut, 200ms spring release.
/// Designed for interactive list items and cards. Provides haptic + visual confirmation.
class PressableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final GestureLongPressStartCallback? onLongPressStart;
  final HitTestBehavior behavior;

  const PressableCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.onLongPressStart,
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  State<PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<PressableCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _down;
  late final Animation<double> _scale;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _down = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _down, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _down.dispose();
    super.dispose();
  }

  void _press() {
    _pressed = true;
    _down.forward();
  }

  void _release({bool callTap = false}) {
    if (!_pressed) return;
    _pressed = false;
    _down.animateBack(0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.elasticOut,
    );
    if (callTap) widget.onTap?.call();
  }

  void _cancel() {
    if (!_pressed) return;
    _pressed = false;
    _down.animateBack(0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.elasticOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: (_) => _press(),
      onTapUp: (_) => _release(callTap: true),
      onTapCancel: _cancel,
      onLongPress: widget.onLongPress,
      onLongPressStart: widget.onLongPressStart,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
        child: widget.child,
      ),
    );
  }
}
