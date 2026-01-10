import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:ott_frontend/core/services/test_config.dart';
import 'package:ott_frontend/data/models/content_models.dart';
import 'package:ott_frontend/data/repositories/content_repository.dart';
import 'package:ott_frontend/features/home/controllers/home_view_models.dart';
import 'package:ott_frontend/persistence/app_database.dart';

enum HomeLoadState { loading, ready, empty, error }

class HomeController extends ChangeNotifier {
  HomeController({required this.repository}) {
    // In widget tests, do not even register cache-buster listeners to prevent
    // any SWR refresh cascades from scheduling frames.
    if (TestConfig.disableAutoStart) return;

    // SWR: when repository updates its cache after a background refresh,
    // reload the home feed and notify listeners.
    _cacheListener = () {
      // Guard against late cache-buster events after disposal.
      if (_disposed) return;

      // No await here; keep callback sync-safe.
      // Debounce to avoid repeated refreshes causing rebuild jank.
      _cacheRefreshDebounce?.cancel();
      _cacheRefreshDebounce = Timer(const Duration(milliseconds: 250), () {
        if (_disposed) return;
        refreshFromCache();
      });
    };
    repository.cacheBuster.addListener(_cacheListener!);
  }

  /// The injected repository is expected to be cache-decorated
  /// (`CachedContentRepository`) so the controller can remain simple while still
  /// benefiting from cache-first + stale-while-revalidate behavior.
  final ContentRepository repository;

  VoidCallback? _cacheListener;

  bool _disposed = false;

  // Debounce SWR cache-buster events; repositories can emit multiple updates
  // during background refresh. Coalescing prevents rapid UI rebuild storms
  // that can manifest as list/hero "glitches" while scrolling.
  Timer? _cacheRefreshDebounce;

  HomeLoadState _state = HomeLoadState.loading;
  HomeLoadState get state => _state;

  HomeFeedPayload? _payload;
  HomeFeedPayload? get payload => _payload;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _refreshing = false;
  bool get refreshing => _refreshing;

  bool _hasEverLoaded = false;

  bool _continueWatchingLoading = false;
  bool get continueWatchingLoading => _continueWatchingLoading;

  final List<ContinueWatchingItem> _continueWatching = <ContinueWatchingItem>[];
  List<ContinueWatchingItem> get continueWatching =>
      List<ContinueWatchingItem>.unmodifiable(_continueWatching);

  void _notifyIfAlive() {
    if (_disposed) return;
    notifyListeners();
  }

  // PUBLIC_INTERFACE
  Future<void> loadHomeFeed() async {
    if (_disposed) return;

    _errorMessage = null;
    _refreshing = _hasEverLoaded; // treat later loads as refresh
    _state = _hasEverLoaded ? _state : HomeLoadState.loading;
    _notifyIfAlive();

    try {
      // Home feed is cache-first and SWR-refreshes in background.
      final HomeFeedPayload payload = await repository.fetchHomeFeed();
      if (_disposed) return;

      _payload = payload;
      _state = payload.rails.isEmpty ? HomeLoadState.empty : HomeLoadState.ready;
      _refreshing = false;
      _hasEverLoaded = true;
      _notifyIfAlive();

      // Kick off continue watching load after we have *some* UI; this is DB-backed,
      // and details are cache-first via repository.getById().
      //
      // In widget tests, auto-start is disabled to prevent background work from
      // continuously scheduling frames.
      if (!TestConfig.disableAutoStart) {
        unawaited(loadContinueWatching());
      }
    } catch (_) {
      if (_disposed) return;

      _refreshing = false;

      // If we have data already (likely cached), keep it and show a soft error.
      if (_payload != null) {
        _errorMessage = 'Failed to refresh home feed.';
        _notifyIfAlive();
        return;
      }

      _state = HomeLoadState.error;
      _errorMessage = 'Failed to load home feed.';
      _notifyIfAlive();
    }
  }

  // PUBLIC_INTERFACE
  Future<void> loadContinueWatching({int limit = 10}) async {
    if (_disposed) return;

    _continueWatchingLoading = true;
    _notifyIfAlive();

    try {
      // Repository delegates to DB when available (CachedContentRepository has db).
      final List<WatchHistoryEntry> history =
          await repository.getRecentWatchHistory(limit: limit);
      if (_disposed) return;

      // Fetch content details for each history entry; repository.getById is cache-first,
      // and will SWR refresh in background.
      final List<ContinueWatchingItem> items = <ContinueWatchingItem>[];
      for (final WatchHistoryEntry h in history) {
        if (_disposed) return;

        final ContentItem? it = await repository.getById(h.contentId);
        if (_disposed) return;

        if (it != null) {
          items.add(
            ContinueWatchingItem(
              content: it,
              positionSeconds: h.positionSeconds,
            ),
          );
        }
      }

      if (_disposed) return;

      _continueWatching
        ..clear()
        ..addAll(items);

      _continueWatchingLoading = false;
      _notifyIfAlive();
    } catch (_) {
      // Soft-fail: keep previous continue-watching data if any.
      if (_disposed) return;

      _continueWatchingLoading = false;
      _notifyIfAlive();
    }
  }

  /// Refreshes Continue Watching after a playback progress write-through.
  ///
  /// This method is intended to be called by other controllers once they persist
  /// watch progress to SQLite (via the cache-decorated repository). It avoids any
  /// BuildContext usage and relies purely on notifier state updates.
  // PUBLIC_INTERFACE
  Future<void> onPlaybackProgressPersisted() async {
    if (_disposed) return;
    await loadContinueWatching();
  }

  // PUBLIC_INTERFACE
  Future<void> refreshFromCache() async {
    if (_disposed) return;

    // When the repo cache refreshes, call fetchHomeFeed again.
    // It will return immediately with cached data (fresh).
    await loadHomeFeed();
    if (_disposed) return;

    // Also refresh continue-watching so updated cached details show up, but don't
    // make it block the rails.
    //
    // In widget tests, auto-start is disabled to prevent background work from
    // continuously scheduling frames.
    if (!TestConfig.disableAutoStart) {
      unawaited(loadContinueWatching());
    }
  }

  @override
  void dispose() {
    _disposed = true;

    _cacheRefreshDebounce?.cancel();
    _cacheRefreshDebounce = null;

    final VoidCallback? l = _cacheListener;
    if (l != null) {
      repository.cacheBuster.removeListener(l);
    }
    super.dispose();
  }
}
