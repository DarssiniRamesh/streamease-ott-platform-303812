import 'package:flutter/foundation.dart';
import 'package:ott_frontend/data/models/content_models.dart';
import 'package:ott_frontend/data/repositories/content_repository.dart';

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

  // PUBLIC_INTERFACE
  Future<void> loadHomeFeed() async {
    _errorMessage = null;
    _refreshing = _hasEverLoaded; // treat later loads as refresh
    _state = _hasEverLoaded ? _state : HomeLoadState.loading;
    notifyListeners();

    try {
      final HomeFeedPayload payload = await repository.fetchHomeFeed();
      _payload = payload;
      _state = payload.rails.isEmpty ? HomeLoadState.empty : HomeLoadState.ready;
      _refreshing = false;
      _hasEverLoaded = true;
      notifyListeners();
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
  Future<void> refreshFromCache() async {
    // When the repo cache refreshes, call fetchHomeFeed again.
    // It will return immediately with cached data (fresh).
    await loadHomeFeed();
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
