import 'package:flutter/foundation.dart';
import 'package:ott_frontend/data/models/content_models.dart';
import 'package:ott_frontend/data/repositories/content_repository.dart';

enum HomeLoadState { loading, ready, empty, error }

class HomeController extends ChangeNotifier {
  HomeController({required this.repository});

  /// The injected repository is expected to be cache-decorated
  /// (`CachedContentRepository`) so the controller can remain simple while still
  /// benefiting from cache-first + stale-while-revalidate behavior.
  final ContentRepository repository;

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

    // With CachedContentRepository:
    // - if cache exists, fetchHomeFeed returns immediately with cached data
    // - it will refresh in background best-effort
    // So here we just call fetch and update UI once.
    _state = HomeLoadState.loading;
    notifyListeners();

    try {
      final HomeFeedPayload payload = await repository.fetchHomeFeed();
      _payload = payload;
      _state = payload.rails.isEmpty ? HomeLoadState.empty : HomeLoadState.ready;
      notifyListeners();
    } catch (_) {
      _state = HomeLoadState.error;
      _errorMessage = 'Failed to load home feed.';
      notifyListeners();
    }
  }
}
