import 'package:flutter/material.dart';
import 'package:ott_frontend/core/motion/motion_tokens.dart';

class Shimmer extends StatefulWidget {
  const Shimmer({
    super.key,
    required this.child,
    required this.baseColor,
    required this.highlightColor,
    this.borderRadius,
  });

  final Widget child;
  final Color baseColor;
  final Color highlightColor;
  final BorderRadius? borderRadius;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: MotionTokens.shimmerLoop)..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduce) return widget.child;

    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (BuildContext context, Widget? child) {
        final double t = _c.value;
        // Move gradient from left->right beyond bounds.
        final double dx = (t * 2.0) - 1.0;

        return ClipRRect(
          borderRadius: widget.borderRadius ?? BorderRadius.zero,
          child: ShaderMask(
            shaderCallback: (Rect bounds) {
              return LinearGradient(
                begin: Alignment(-1.0 + dx, 0),
                end: Alignment(1.0 + dx, 0),
                colors: <Color>[
                  widget.baseColor,
                  widget.highlightColor,
                  widget.baseColor,
                ],
                stops: const <double>[0.0, 0.5, 1.0],
              ).createShader(bounds);
            },
            blendMode: BlendMode.srcATop,
            child: child,
          ),
        );
      },
    );
  }
}
