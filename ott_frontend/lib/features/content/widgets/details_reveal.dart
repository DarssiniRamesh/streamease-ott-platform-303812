import 'package:flutter/material.dart';
import 'package:ott_frontend/core/motion/motion_tokens.dart';

class DetailsReveal extends StatelessWidget {
  const DetailsReveal({
    super.key,
    required this.child,
    required this.order,
  });

  final Widget child;
  final int order;

  @override
  Widget build(BuildContext context) {
    final bool reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduce) return child;

    final Duration total = MotionTokens.reduceMotionDuration(context, const Duration(milliseconds: 320));
    final Duration delay = Duration(milliseconds: (order * 55).clamp(0, 220));

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: total,
      curve: MotionTokens.standard,
      builder: (BuildContext context, double v, Widget? c) {
        // Apply delay by "holding" at 0 for initial period.
        final double t = ((v * total.inMilliseconds - delay.inMilliseconds) / total.inMilliseconds)
            .clamp(0.0, 1.0);
        final double opacity = t;
        final double dy = (1.0 - t) * 12.0;
        return Opacity(opacity: opacity, child: Transform.translate(offset: Offset(0, dy), child: c));
      },
      child: child,
    );
  }
}
