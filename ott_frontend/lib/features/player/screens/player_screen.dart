import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ott_frontend/core/services/app_bootstrap.dart';
import 'package:ott_frontend/features/home/controllers/home_controller.dart';
import 'package:provider/provider.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    super.key,
    required this.contentId,
    this.startPositionSeconds,
  });

  final String contentId;
  final int? startPositionSeconds;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  Timer? _timer;

  // Primitive-only state that we can safely mutate from async/timers.
  int _positionSeconds = 0;
  bool _playing = true;

  @override
  void initState() {
    super.initState();
    _positionSeconds = widget.startPositionSeconds ?? 0;
    _startTicker();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  void _startTicker() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_playing) return;
      setState(() => _positionSeconds += 1);
    });
  }

  // PUBLIC_INTERFACE
  void togglePlayPause() {
    /// Toggle play/pause in the lightweight player simulation.
    setState(() => _playing = !_playing);
  }

  // PUBLIC_INTERFACE
  void seekBy(int deltaSeconds) {
    /// Seek the simulated playback position by `deltaSeconds`.
    final int next = (_positionSeconds + deltaSeconds).clamp(0, 24 * 60 * 60);
    setState(() => _positionSeconds = next);
  }

  // PUBLIC_INTERFACE
  void persistProgress() {
    /// Persist current playback progress to the repository/DB (write-through).
    // All BuildContext reads must happen synchronously (no awaits).
    final AppDependencies deps = context.read<AppDependencies>();
    final HomeController home = context.read<HomeController>();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    // Do async work without touching BuildContext after awaits.
    () async {
      await deps.contentRepository.recordPlaybackProgress(
        contentId: widget.contentId,
        positionSeconds: _positionSeconds,
      );
      await home.onPlaybackProgressPersisted();
    }();

    messenger.showSnackBar(
      const SnackBar(content: Text('Progress saved')),
    );
  }

  // PUBLIC_INTERFACE
  void markCompleted() {
    /// Mark playback completed and clear Continue Watching state for this item.
    final AppDependencies deps = context.read<AppDependencies>();
    final HomeController home = context.read<HomeController>();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    () async {
      await deps.contentRepository.recordPlaybackCompleted(contentId: widget.contentId);
      await home.onPlaybackProgressPersisted();
    }();

    setState(() => _positionSeconds = 0);
    messenger.showSnackBar(const SnackBar(content: Text('Marked completed')));
  }

  static String _format(int seconds) {
    final int m = seconds ~/ 60;
    final int s = seconds % 60;
    if (m <= 0) return '${s}s';
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Player'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Save progress',
            onPressed: persistProgress,
            icon: const Icon(Icons.save_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Fake video surface
              AspectRatio(
                aspectRatio: 16 / 9,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: <Color>[
                        cs.primary.withAlpha(40),
                        cs.secondary.withAlpha(18),
                        cs.surface,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: cs.primary.withAlpha(20)),
                  ),
                  child: Center(
                    child: Icon(
                      _playing ? Icons.play_circle_fill : Icons.pause_circle_filled,
                      size: 72,
                      color: cs.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Content ID: ${widget.contentId}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: LinearProgressIndicator(
                      value: (_positionSeconds % 300) / 300.0,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(999),
                      backgroundColor: cs.primary.withAlpha(10),
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(_format(_positionSeconds), style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => seekBy(-10),
                      icon: const Icon(Icons.replay_10),
                      label: const Text('Back 10s'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: togglePlayPause,
                      icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
                      label: Text(_playing ? 'Pause' : 'Play'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => seekBy(10),
                      icon: const Icon(Icons.forward_10),
                      label: const Text('Fwd 10s'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: markCompleted,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Mark completed'),
              ),
              const Spacer(),
              Text(
                'Note: This is a lightweight player stub to validate navigation + watch-history persistence until real video playback is integrated.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
