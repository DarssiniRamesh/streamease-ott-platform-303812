import 'package:flutter/material.dart';
import 'package:ott_frontend/core/motion/motion_tokens.dart';

class RevealOnBuild extends StatelessWidget {
  const RevealOnBuild({
    super.key,
    required this.child,
    required this.index,
    this.baseDelay = const Duration(milliseconds: 0),
  });

  final Widget child;
  final int index;
  final Duration baseDelay;

  @override
  Widget build(BuildContext context) {
    final bool reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduce) return child;

    final Duration total = MotionTokens.reduceMotionDuration(context, MotionTokens.ui);
    final int stepMs = (total.inMilliseconds * 0.18).round().clamp(0, 80);
    final Duration delay = baseDelay + Duration(milliseconds: index * stepMs);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: total + delay,
      curve: MotionTokens.standard,
      builder: (BuildContext context, double v, Widget? c) {
        final double t = (v - (delay.inMilliseconds / (total.inMilliseconds + delay.inMilliseconds)))
            .clamp(0.0, 1.0);
        final double opacity = t;
        final double dy = (1.0 - t) * 10.0;

        return Opacity(
          opacity: opacity,
          child: Transform.translate(offset: Offset(0, dy), child: c),
        );
      },
      child: child,
    );
  }
}
