import 'package:flutter/material.dart';

/// Central motion tokens for StreamEase.
///
/// These values implement the recommended defaults from
/// `animation-plan-video-playback-and-global-motion.md`.
class MotionTokens {
  const MotionTokens._();

  // Durations
  static const Duration micro = Duration(milliseconds: 100);
  static const Duration ui = Duration(milliseconds: 200);
  static const Duration route = Duration(milliseconds: 300);
  static const Duration modal = Duration(milliseconds: 280);
  static const Duration shimmerLoop = Duration(milliseconds: 1400);

  // Curves
  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasis = Curves.easeInOutCubic;
  static const Curve decel = Curves.decelerate;

  /// Returns a duration shortened when the OS requests reduced motion.
  static Duration reduceMotionDuration(BuildContext context, Duration d) {
    final bool reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (!reduce) return d;
    // Keep timing non-zero to avoid sudden "teleporting" state changes.
    final int ms = (d.inMilliseconds * 0.35).round();
    return Duration(milliseconds: ms.clamp(60, d.inMilliseconds));
  }
}
