import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:ott_frontend/core/services/simple_cache.dart';
import 'package:ott_frontend/data/models/content_models.dart';
import 'package:ott_frontend/data/repositories/content_repository.dart';

enum HomeLoadState { loading, ready, empty, error }

class HomeController extends ChangeNotifier {
  HomeController({required this.repository, required this.cache});

  final ContentRepository repository;
  final SimpleCache cache;

  static const String _cacheKey = 'home_feed_v1';
  static const Duration _ttl = Duration(minutes: 10);

  HomeLoadState _state = HomeLoadState.loading;
  HomeLoadState get state => _state;

  HomeFeedPayload? _payload;
  HomeFeedPayload? get payload => _payload;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _showingStaleCache = false;
  bool get showingStaleCache => _showingStaleCache;

  // PUBLIC_INTERFACE
  Future<void> loadHomeFeed() async {
    _errorMessage = null;
    _showingStaleCache = false;

    // Cache-first: show cached payload immediately (fresh or stale) then refresh in background.
    final CacheEntry? fresh = cache.getJsonIfFresh(_cacheKey, _ttl);
    if (fresh != null) {
      _payload = HomeFeedPayload.fromJson((jsonDecode(fresh.json) as Map<String, dynamic>));
      _state = _payload!.rails.isEmpty ? HomeLoadState.empty : HomeLoadState.ready;
      notifyListeners();
      // Background refresh below.
    } else {
      final CacheEntry? stale = cache.getJsonEvenIfStale(_cacheKey);
      if (stale != null) {
        _payload = HomeFeedPayload.fromJson((jsonDecode(stale.json) as Map<String, dynamic>));
        _state = _payload!.rails.isEmpty ? HomeLoadState.empty : HomeLoadState.ready;
        _showingStaleCache = true;
        notifyListeners();
      } else {
        _state = HomeLoadState.loading;
        notifyListeners();
      }
    }

    try {
      final HomeFeedPayload net = await repository.fetchHomeFeed();
      await cache.putJson(_cacheKey, net.toJson());

      _payload = net;
      _state = net.rails.isEmpty ? HomeLoadState.empty : HomeLoadState.ready;
      _showingStaleCache = false;
      notifyListeners();
    } catch (e) {
      // Fall back: if we already have cached data on screen, keep it and surface banner.
      if (_payload != null) {
        _showingStaleCache = true;
        _errorMessage = 'Unable to refresh. Showing offline data.';
        notifyListeners();
        return;
      }

      _state = HomeLoadState.error;
      _errorMessage = 'Failed to load home feed.';
      notifyListeners();
    }
  }
}
