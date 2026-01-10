import 'package:flutter/material.dart';
import 'package:ott_frontend/core/motion/motion_tokens.dart';

class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    required this.onTap,
    this.borderRadius,
    this.pressedScale = 0.985,
  });

  final Widget child;
  final VoidCallback onTap;
  final BorderRadius? borderRadius;
  final double pressedScale;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final bool reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final Duration d = MotionTokens.reduceMotionDuration(context, MotionTokens.micro);

    final double scale = (!_pressed || reduce) ? 1.0 : widget.pressedScale;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: scale,
        duration: d,
        curve: MotionTokens.standard,
        child: ClipRRect(
          borderRadius: widget.borderRadius ?? BorderRadius.zero,
          child: widget.child,
        ),
      ),
    );
  }
}
