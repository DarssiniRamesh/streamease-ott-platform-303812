import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:ott_frontend/data/models/content_models.dart';
import 'package:ott_frontend/data/repositories/content_repository.dart';
import 'package:ott_frontend/features/home/controllers/home_view_models.dart';
import 'package:ott_frontend/persistence/app_database.dart';

enum HomeLoadState { loading, ready, empty, error }

class HomeController extends ChangeNotifier {
  HomeController({required this.repository}) {
    // SWR: when repository updates its cache after a background refresh,
    // reload the home feed and notify listeners.
    _cacheListener = () {
      // No await here; keep callback sync-safe.
      refreshFromCache();
    };
    repository.cacheBuster.addListener(_cacheListener!);
  }

  /// The injected repository is expected to be cache-decorated
  /// (`CachedContentRepository`) so the controller can remain simple while still
  /// benefiting from cache-first + stale-while-revalidate behavior.
  final ContentRepository repository;

  VoidCallback? _cacheListener;

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

  // PUBLIC_INTERFACE
  Future<void> loadHomeFeed() async {
    _errorMessage = null;
    _refreshing = _hasEverLoaded; // treat later loads as refresh
    _state = _hasEverLoaded ? _state : HomeLoadState.loading;
    notifyListeners();

    try {
      // Home feed is cache-first and SWR-refreshes in background.
      final HomeFeedPayload payload = await repository.fetchHomeFeed();
      _payload = payload;
      _state = payload.rails.isEmpty ? HomeLoadState.empty : HomeLoadState.ready;
      _refreshing = false;
      _hasEverLoaded = true;
      notifyListeners();

      // Kick off continue watching load after we have *some* UI; this is DB-backed,
      // and details are cache-first via repository.getById().
      unawaited(loadContinueWatching());
    } catch (_) {
      _refreshing = false;

      // If we have data already (likely cached), keep it and show a soft error.
      if (_payload != null) {
        _errorMessage = 'Failed to refresh home feed.';
        notifyListeners();
        return;
      }

      _state = HomeLoadState.error;
      _errorMessage = 'Failed to load home feed.';
      notifyListeners();
    }
  }

  // PUBLIC_INTERFACE
  Future<void> loadContinueWatching({int limit = 10}) async {
    _continueWatchingLoading = true;
    notifyListeners();

    try {
      // Repository delegates to DB when available (CachedContentRepository has db).
      final List<WatchHistoryEntry> history = await repository.getRecentWatchHistory(limit: limit);

      // Fetch content details for each history entry; repository.getById is cache-first,
      // and will SWR refresh in background.
      final List<ContinueWatchingItem> items = <ContinueWatchingItem>[];
      for (final WatchHistoryEntry h in history) {
        final ContentItem? it = await repository.getById(h.contentId);
        if (it != null) {
          items.add(
            ContinueWatchingItem(
              content: it,
              positionSeconds: h.positionSeconds,
            ),
          );
        }
      }

      _continueWatching
        ..clear()
        ..addAll(items);

      _continueWatchingLoading = false;
      notifyListeners();
    } catch (_) {
      // Soft-fail: keep previous continue-watching data if any.
      _continueWatchingLoading = false;
      notifyListeners();
    }
  }

  // PUBLIC_INTERFACE
  Future<void> refreshFromCache() async {
    // When the repo cache refreshes, call fetchHomeFeed again.
    // It will return immediately with cached data (fresh).
    await loadHomeFeed();

    // Also refresh continue-watching so updated cached details show up, but don't
    // make it block the rails.
    unawaited(loadContinueWatching());
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
