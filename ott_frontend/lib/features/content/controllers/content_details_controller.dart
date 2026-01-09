import 'package:flutter/foundation.dart';
import 'package:ott_frontend/core/services/simple_cache.dart';
import 'package:ott_frontend/data/models/content_models.dart';
import 'package:ott_frontend/data/repositories/content_repository.dart';
import 'package:ott_frontend/persistence/app_database.dart';

enum ContentDetailsState { loading, ready, notFound, error }

class ContentDetailsController extends ChangeNotifier {
  ContentDetailsController({
    required this.repository,
    required this.cache,
    required this.contentId,
    this.db,
  }) {
    _cacheListener = () {
      // Re-load from cache when SWR refresh completes.
      refreshFromCache();
    };
    repository.cacheBuster.addListener(_cacheListener!);
  }

  final ContentRepository repository;
  final SimpleCache cache;
  final String contentId;

  /// Optional DB to read durable download state (enqueue/completed/etc).
  final AppDatabase? db;

  VoidCallback? _cacheListener;

  ContentDetailsState _state = ContentDetailsState.loading;
  ContentDetailsState get state => _state;

  ContentItem? _item;
  ContentItem? get item => _item;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _refreshing = false;
  bool get refreshing => _refreshing;

  bool _hasEverLoaded = false;

  bool _inFlight = false;

  int? _lastWatchedSeconds;
  int? get lastWatchedSeconds => _lastWatchedSeconds;

  static const String _watchlistKey = 'watchlist:ids';

  bool _inWatchlist = false;
  bool get inWatchlist => _inWatchlist;

  bool _hasDownload = false;
  bool get hasDownload => _hasDownload;

  String? _downloadStatus;
  String? get downloadStatus => _downloadStatus;

  // PUBLIC_INTERFACE
  Future<void> load() async {
    if (_inFlight) return;
    _inFlight = true;

    _errorMessage = null;
    _refreshing = _hasEverLoaded;
    _state = _hasEverLoaded ? _state : ContentDetailsState.loading;
    notifyListeners();

    try {
      // Fetch cached (or stale) details immediately; refresh happens in background.
      final ContentItem? it = await repository.getById(contentId);
      _item = it;

      // Load watch progress from DB (best-effort; cache-decorated repo uses SQLite).
      _lastWatchedSeconds = await repository.getPlaybackProgressSeconds(contentId: contentId);

      // Load watchlist membership from preferences cache.
      _inWatchlist = _isInWatchlist(contentId);

      // Load durable download state (if DB present).
      final AppDatabase? d = db;
      if (d != null) {
        _hasDownload = await d.hasDownload(contentId: contentId);
        _downloadStatus = await d.getDownloadStatus(contentId: contentId);
      } else {
        _hasDownload = false;
        _downloadStatus = null;
      }

      if (it == null) {
        _state = ContentDetailsState.notFound;
      } else {
        _state = ContentDetailsState.ready;
      }

      _refreshing = false;
      _hasEverLoaded = true;
      _inFlight = false;
      notifyListeners();
    } catch (_) {
      _refreshing = false;
      _inFlight = false;

      if (_item != null) {
        _errorMessage = 'Failed to refresh content.';
        notifyListeners();
        return;
      }

      _state = ContentDetailsState.error;
      _errorMessage = 'Failed to load content.';
      notifyListeners();
    }
  }

  bool _isInWatchlist(String id) {
    final List<String> existing = cache.getStringList(_watchlistKey);
    return existing.contains(id);
  }

  // PUBLIC_INTERFACE
  Future<void> toggleWatchlist() async {
    final List<String> existing = cache.getStringList(_watchlistKey);
    final List<String> next = List<String>.of(existing);

    if (next.contains(contentId)) {
      next.removeWhere((String e) => e == contentId);
      _inWatchlist = false;
    } else {
      next.insert(0, contentId);
      _inWatchlist = true;
    }

    await cache.setStringList(_watchlistKey, next.take(200).toList());
    notifyListeners();
  }

  // PUBLIC_INTERFACE
  Future<void> refreshFromCache() async {
    // Cache-buster events can arrive frequently; avoid changing UX state beyond
    // re-reading from the repository (which will be cache-first).
    await load();
  }

  // PUBLIC_INTERFACE
  Future<void> recordPlaybackProgressSeconds(int positionSeconds) async {
    await repository.recordPlaybackProgress(
      contentId: contentId,
      positionSeconds: positionSeconds,
    );

    // Keep UI in sync with persisted position.
    _lastWatchedSeconds = positionSeconds;
    notifyListeners();
  }

  // PUBLIC_INTERFACE
  Future<void> recordPlaybackCompleted() async {
    await repository.recordPlaybackCompleted(contentId: contentId);
    _lastWatchedSeconds = 0;
    notifyListeners();
  }

  // PUBLIC_INTERFACE
  void markDownloadEnqueuedLocally() {
    // Used by UI right after enqueue to reflect state immediately without
    // waiting for DB reload / navigation.
    _hasDownload = true;
    _downloadStatus = 'downloading';
    notifyListeners();
  }

  @override
  void dispose() {
    final VoidCallback? l = _cacheListener;
    if (l != null) {
      repository.cacheBuster.removeListener(l);
    }
    super.dispose();
  }
}
