import 'package:flutter/material.dart';
import 'package:ott_frontend/core/motion/motion_tokens.dart';

class AnimatedBanner extends StatelessWidget {
  const AnimatedBanner({
    super.key,
    required this.visible,
    required this.child,
  });

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final Duration d = MotionTokens.reduceMotionDuration(context, MotionTokens.ui);

    return AnimatedSize(
      duration: d,
      curve: MotionTokens.standard,
      alignment: Alignment.topCenter,
      child: AnimatedOpacity(
        duration: d,
        curve: MotionTokens.standard,
        opacity: visible ? 1.0 : 0.0,
        child: visible ? child : const SizedBox.shrink(),
      ),
    );
  }
}
