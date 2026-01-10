import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ott_frontend/core/motion/motion_tokens.dart';
import 'package:ott_frontend/core/routing/app_router.dart';
import 'package:ott_frontend/core/routing/app_routes.dart';
import 'package:ott_frontend/features/player/controllers/mini_player_controller.dart';
import 'package:provider/provider.dart';

class MiniPlayerSheet extends StatelessWidget {
  const MiniPlayerSheet({super.key});

  static String _format(int seconds) {
    final int m = seconds ~/ 60;
    final int s = seconds % 60;
    if (m <= 0) return '${s}s';
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  void _openFullPlayer(BuildContext context, MiniPlayerController c) {
    final String? id = c.contentId;
    if (id == null) return;

    // Immediate use of context; no async gaps.
    Navigator.of(context).pushNamed(
      AppRoutes.player,
      arguments: PlayerArgs(
        contentId: id,
        startPositionSeconds: c.positionSeconds,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final MiniPlayerController c = context.watch<MiniPlayerController>();
    if (!c.isActive) return const SizedBox.shrink();

    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    final Duration d = MotionTokens.reduceMotionDuration(context, MotionTokens.modal);

    return SafeArea(
      top: false,
      child: AnimatedSlide(
        duration: d,
        curve: MotionTokens.standard,
        offset: const Offset(0, 0),
        child: AnimatedOpacity(
          duration: d,
          curve: MotionTokens.standard,
          opacity: 1,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Material(
              color: cs.surface,
              elevation: 6,
              shadowColor: Colors.black.withAlpha(30),
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => _openFullPlayer(context, c),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                  child: Row(
                    children: <Widget>[
                      // Thumbnail placeholder.
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: <Color>[
                                cs.primary.withAlpha(36),
                                cs.secondary.withAlpha(18),
                                cs.surface,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: const SizedBox(
                            width: 56,
                            height: 40,
                            child: Icon(Icons.play_circle_fill),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              c.contentId ?? 'Now playing',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: <Widget>[
                                Icon(Icons.schedule, size: 14, color: cs.onSurfaceVariant),
                                const SizedBox(width: 4),
                                Text(
                                  _format(c.positionSeconds),
                                  style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: c.muted ? 'Unmute' : 'Mute',
                        onPressed: c.toggleMute,
                        icon: Icon(c.muted ? Icons.volume_off : Icons.volume_up),
                      ),
                      IconButton(
                        tooltip: 'Back 10s',
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          c.seekBy(-10);
                        },
                        icon: const Icon(Icons.replay_10),
                      ),
                      IconButton(
                        tooltip: c.playing ? 'Pause' : 'Play',
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          c.togglePlayPause();
                        },
                        icon: Icon(c.playing ? Icons.pause : Icons.play_arrow),
                      ),
                      IconButton(
                        tooltip: 'Forward 10s',
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          c.seekBy(10);
                        },
                        icon: const Icon(Icons.forward_10),
                      ),
                      IconButton(
                        tooltip: 'Close mini-player',
                        onPressed: c.stop,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
