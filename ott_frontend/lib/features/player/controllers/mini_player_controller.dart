import 'package:flutter/foundation.dart';

/// A minimal global controller for player state that powers the persistent mini-player.
///
/// This app currently uses a lightweight player stub. This controller intentionally
/// stores only primitive state to keep it safe and predictable.
///
/// The UI can:
/// - show/hide the mini-player,
/// - resume full player,
/// - play/pause,
/// - seek +/-10s,
/// - mute toggle,
/// - captions placeholder toggle.
///
/// Note: This does not implement a real video engine. It mirrors the existing
/// `PlayerScreen` stub behavior and centralizes it for the mini-player UI.
class MiniPlayerController extends ChangeNotifier {
  String? _contentId;
  int _positionSeconds = 0;
  bool _playing = false;
  bool _muted = false;
  bool _captionsEnabled = false;

  String? get contentId => _contentId;
  int get positionSeconds => _positionSeconds;
  bool get playing => _playing;
  bool get muted => _muted;
  bool get captionsEnabled => _captionsEnabled;

  bool get isActive => _contentId != null;

  // PUBLIC_INTERFACE
  void startOrUpdateSession({
    required String contentId,
    required int positionSeconds,
    required bool playing,
  }) {
    /// Start (or update) the current mini-player session.
    _contentId = contentId;
    _positionSeconds = positionSeconds;
    _playing = playing;
    notifyListeners();
  }

  // PUBLIC_INTERFACE
  void stop() {
    /// Stop/clear the mini-player session.
    _contentId = null;
    _positionSeconds = 0;
    _playing = false;
    notifyListeners();
  }

  // PUBLIC_INTERFACE
  void setPositionSeconds(int seconds) {
    /// Update playback position (seconds).
    _positionSeconds = seconds.clamp(0, 24 * 60 * 60);
    notifyListeners();
  }

  // PUBLIC_INTERFACE
  void setPlaying(bool playing) {
    /// Update playing flag.
    _playing = playing;
    notifyListeners();
  }

  // PUBLIC_INTERFACE
  void togglePlayPause() {
    /// Toggle play/pause.
    _playing = !_playing;
    notifyListeners();
  }

  // PUBLIC_INTERFACE
  void seekBy(int deltaSeconds) {
    /// Seek by delta seconds.
    _positionSeconds = (_positionSeconds + deltaSeconds).clamp(0, 24 * 60 * 60);
    notifyListeners();
  }

  // PUBLIC_INTERFACE
  void toggleMute() {
    /// Toggle muted state.
    _muted = !_muted;
    notifyListeners();
  }

  // PUBLIC_INTERFACE
  void toggleCaptionsPlaceholder() {
    /// Toggle captions placeholder.
    ///
    /// This is a placeholder until real captions integration exists.
    _captionsEnabled = !_captionsEnabled;
    notifyListeners();
  }
}
