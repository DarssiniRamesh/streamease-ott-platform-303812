import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ott_frontend/core/services/app_bootstrap.dart';
import 'package:ott_frontend/features/home/controllers/home_controller.dart';
import 'package:ott_frontend/features/player/controllers/mini_player_controller.dart';
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
  bool _muted = false;
  bool _captionsEnabled = false;

  // Scrubbing state (primitive) + derived UI.
  bool _scrubbing = false;
  double _scrubValue = 0; // 0..durationSeconds
  int _lastHapticSecond = -1;

  // This stub "video" duration is fixed (5 min) to power scrubber and previews.
  static const int _durationSeconds = 300;

  @override
  void initState() {
    super.initState();
    _positionSeconds = widget.startPositionSeconds ?? 0;
    _startTicker();
    _lockLandscape();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _restoreOrientation();
    super.dispose();
  }

  void _startTicker() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_playing) return;
      if (_scrubbing) return;
      setState(() => _positionSeconds = (_positionSeconds + 1).clamp(0, _durationSeconds));
    });
  }

  void _lockLandscape() {
    // Best-effort: lock to landscape while this screen is visible.
    // No BuildContext needed, and Future is intentionally not awaited.
    SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  void _restoreOrientation() {
    // Best-effort restore: allow all orientations.
    SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  void _syncMiniPlayer() {
    final MiniPlayerController mini = context.read<MiniPlayerController>();
    mini.startOrUpdateSession(
      contentId: widget.contentId,
      positionSeconds: _positionSeconds,
      playing: _playing,
    );
  }

  // PUBLIC_INTERFACE
  void togglePlayPause() {
    /// Toggle play/pause in the lightweight player simulation.
    setState(() => _playing = !_playing);
    _syncMiniPlayer();
  }

  // PUBLIC_INTERFACE
  void seekBy(int deltaSeconds) {
    /// Seek the simulated playback position by `deltaSeconds`.
    final int next = (_positionSeconds + deltaSeconds).clamp(0, _durationSeconds);
    setState(() => _positionSeconds = next);
    _syncMiniPlayer();
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
    _syncMiniPlayer();
    messenger.showSnackBar(const SnackBar(content: Text('Marked completed')));
  }

  // PUBLIC_INTERFACE
  void minimizeToMiniPlayer() {
    /// Minimizes the full player into the persistent mini-player.
    ///
    /// This updates the global mini-player state then pops this route.
    _syncMiniPlayer();
    Navigator.of(context).maybePop();
  }

  static String _format(int seconds) {
    final int m = seconds ~/ 60;
    final int s = seconds % 60;
    if (m <= 0) return '${s}s';
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  Color _previewColorForSecond(ColorScheme cs, int second) {
    // Basic "thumbnail" preview: colored tile derived from time.
    final int bucket = (second ~/ 5) % 6;
    return switch (bucket) {
      0 => cs.primary.withAlpha(40),
      1 => cs.secondary.withAlpha(36),
      2 => cs.tertiary.withAlpha(30),
      3 => cs.primaryContainer.withAlpha(36),
      4 => cs.secondaryContainer.withAlpha(30),
      _ => cs.surfaceContainerHighest.withAlpha(40),
    };
  }

  void _onScrubHapticIfNeeded(int second) {
    if (second == _lastHapticSecond) return;
    _lastHapticSecond = second;
    // Subtle feedback while scrubbing.
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    final int effectiveSeconds = _scrubbing ? _scrubValue.round() : _positionSeconds;
    final double progress = effectiveSeconds / _durationSeconds;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Player'),
        leading: IconButton(
          tooltip: 'Minimize',
          onPressed: minimizeToMiniPlayer,
          icon: const Icon(Icons.keyboard_arrow_down),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: _captionsEnabled ? 'Captions (placeholder): On' : 'Captions (placeholder): Off',
            onPressed: () {
              setState(() => _captionsEnabled = !_captionsEnabled);
              // Keep mini state in sync.
              context.read<MiniPlayerController>().toggleCaptionsPlaceholder();
            },
            icon: Icon(_captionsEnabled ? Icons.closed_caption : Icons.closed_caption_off),
          ),
          IconButton(
            tooltip: _muted ? 'Unmute' : 'Mute',
            onPressed: () {
              setState(() => _muted = !_muted);
              context.read<MiniPlayerController>().toggleMute();
            },
            icon: Icon(_muted ? Icons.volume_off : Icons.volume_up),
          ),
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
                child: Stack(
                  children: <Widget>[
                    DecoratedBox(
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

                    // Scrub preview bubble (basic thumbnail simulation).
                    if (_scrubbing)
                      Positioned(
                        left: 12,
                        top: 12,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: cs.surface,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                blurRadius: 18,
                                spreadRadius: 0,
                                offset: const Offset(0, 8),
                                color: Colors.black.withAlpha(26),
                              ),
                            ],
                            border: Border.all(color: cs.primary.withAlpha(18)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: _previewColorForSecond(cs, effectiveSeconds),
                                  ),
                                  child: const SizedBox(width: 52, height: 36),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _format(effectiveSeconds),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Content ID: ${widget.contentId}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),

              // Scrubber with feedback.
              Row(
                children: <Widget>[
                  Text(_format(effectiveSeconds), style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3.5,
                        activeTrackColor: cs.primary,
                        inactiveTrackColor: cs.primary.withAlpha(18),
                        thumbColor: cs.primary,
                        overlayColor: cs.primary.withAlpha(20),
                      ),
                      child: Slider(
                        value: (progress * _durationSeconds).clamp(0, _durationSeconds).toDouble(),
                        min: 0,
                        max: _durationSeconds.toDouble(),
                        onChangeStart: (double v) {
                          setState(() {
                            _scrubbing = true;
                            _scrubValue = v;
                            _lastHapticSecond = v.round();
                          });
                          HapticFeedback.selectionClick();
                        },
                        onChanged: (double v) {
                          final int second = v.round();
                          setState(() => _scrubValue = v);
                          _onScrubHapticIfNeeded(second);
                        },
                        onChangeEnd: (double v) {
                          final int second = v.round().clamp(0, _durationSeconds);
                          setState(() {
                            _scrubbing = false;
                            _positionSeconds = second;
                          });
                          _syncMiniPlayer();
                          HapticFeedback.selectionClick();
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(_format(_durationSeconds), style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),

              const SizedBox(height: 12),

              // Standard controls row.
              Row(
                children: <Widget>[
                  IconButton(
                    tooltip: 'Back 10s',
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      seekBy(-10);
                    },
                    icon: const Icon(Icons.replay_10),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        togglePlayPause();
                      },
                      icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
                      label: Text(_playing ? 'Pause' : 'Play'),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: 'Forward 10s',
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      seekBy(10);
                    },
                    icon: const Icon(Icons.forward_10),
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
