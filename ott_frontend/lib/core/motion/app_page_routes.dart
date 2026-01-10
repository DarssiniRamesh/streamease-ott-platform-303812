import 'package:flutter/material.dart';
import 'package:ott_frontend/core/motion/motion_tokens.dart';

/// A simple "fade-through" page transition (Material motion inspired).
///
/// Outgoing page fades out quickly; incoming fades in slightly delayed.
/// This keeps navigation feeling premium without being heavy.
///
/// Use for most push/pop transitions in StreamEase.
class FadeThroughPageRoute<T> extends PageRouteBuilder<T> {
  FadeThroughPageRoute({
    required this.builder,
    super.settings,
  }) : super(
          pageBuilder: (BuildContext context, Animation<double> a, Animation<double> s) =>
              builder(context),
          transitionDuration: MotionTokens.reduceMotionDuration(
            // context not available here; use baseline and rely on system-level disableAnimations
            // within transitions by clamping opacity/transform amount below.
            // ignore: use_build_context_synchronously
            _NoContext.instance,
            MotionTokens.route,
          ),
          reverseTransitionDuration: MotionTokens.route,
          transitionsBuilder: (BuildContext context, Animation<double> animation,
              Animation<double> secondaryAnimation, Widget child) {
            final bool reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

            // Incoming opacity with slight delay.
            final Animation<double> fadeIn = CurvedAnimation(
              parent: animation,
              curve: const Interval(0.15, 1.0, curve: Curves.easeOutCubic),
            );

            // Outgoing opacity (secondary) on pop.
            final Animation<double> fadeOut = CurvedAnimation(
              parent: secondaryAnimation,
              curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
            );

            Widget incoming = FadeTransition(opacity: fadeIn, child: child);

            // A very subtle scale gives polish; disabled under reduce motion.
            if (!reduce) {
              incoming = ScaleTransition(
                scale: Tween<double>(begin: 1.01, end: 1.0).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
                ),
                child: incoming,
              );
            }

            // For pop, we also slightly fade the previous route using secondaryAnimation.
            return FadeTransition(
              opacity: Tween<double>(begin: 1.0, end: 0.0).animate(fadeOut),
              child: incoming,
            );
          },
        );

  final WidgetBuilder builder;
}

/// Helper to satisfy reduceMotionDuration signature without BuildContext.
class _NoContext implements BuildContext {
  static final _NoContext instance = _NoContext._();
  _NoContext._();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
