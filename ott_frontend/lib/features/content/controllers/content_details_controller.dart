import 'package:flutter/foundation.dart';
import 'package:ott_frontend/data/models/content_models.dart';
import 'package:ott_frontend/data/repositories/content_repository.dart';

enum ContentDetailsState { loading, ready, notFound, error }

class ContentDetailsController extends ChangeNotifier {
  ContentDetailsController({required this.repository, required this.contentId}) {
    _cacheListener = () {
      // Re-load from cache when SWR refresh completes.
      refreshFromCache();
    };
    repository.cacheBuster.addListener(_cacheListener!);
  }

  final ContentRepository repository;
  final String contentId;

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

  // PUBLIC_INTERFACE
  Future<void> load() async {
    if (_inFlight) return;
    _inFlight = true;

    _errorMessage = null;
    _refreshing = _hasEverLoaded;
    _state = _hasEverLoaded ? _state : ContentDetailsState.loading;
    notifyListeners();

    try {
      final ContentItem? it = await repository.getById(contentId);
      _item = it;

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
  }

  // PUBLIC_INTERFACE
  Future<void> recordPlaybackCompleted() async {
    await repository.recordPlaybackCompleted(contentId: contentId);
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
