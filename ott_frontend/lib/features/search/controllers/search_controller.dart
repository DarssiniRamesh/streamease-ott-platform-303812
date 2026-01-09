import 'package:flutter/foundation.dart';
import 'package:ott_frontend/core/services/simple_cache.dart';
import 'package:ott_frontend/data/models/content_models.dart';
import 'package:ott_frontend/data/repositories/content_repository.dart';

class AppSearchController extends ChangeNotifier {
  AppSearchController({required this.repository, required this.cache}) {
    _cacheListener = () {
      final String q = _query.trim();
      if (q.isEmpty) return;
      // SWR refresh completion: re-run the search to pick up fresh cached results.
      refreshFromCache();
    };
    repository.cacheBuster.addListener(_cacheListener!);
  }

  final ContentRepository repository;
  final SimpleCache cache;

  VoidCallback? _cacheListener;

  static const String _recentKey = 'recent_searches';

  String _query = '';
  String get query => _query;

  bool _loading = false;
  bool get loading => _loading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<ContentItem> _results = <ContentItem>[];
  List<ContentItem> get results => List<ContentItem>.unmodifiable(_results);

  List<String> get recent => cache.getStringList(_recentKey);

  // PUBLIC_INTERFACE
  void setQuery(String value) {
    _query = value;
    _errorMessage = null;
    notifyListeners();
  }

  // PUBLIC_INTERFACE
  Future<void> submit() async {
    final String q = _query.trim();
    if (q.isEmpty) {
      _results = <ContentItem>[];
      _errorMessage = null;
      notifyListeners();
      return;
    }

    _loading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Repository is cache-decorated (CachedContentRepository):
      // - returns cached immediately when available
      // - triggers background refresh that will bump cacheBuster later
      final List<ContentItem> r = await repository.search(q);

      // Recent searches list (small prefs cache).
      final List<String> existing = cache.getStringList(_recentKey);
      final List<String> next = <String>[q, ...existing.where((String e) => e.toLowerCase() != q.toLowerCase())]
          .take(10)
          .toList();
      await cache.setStringList(_recentKey, next);

      _results = r;
      _loading = false;
      notifyListeners();
    } catch (_) {
      _loading = false;
      _results = <ContentItem>[];
      _errorMessage = 'Search failed.';
      notifyListeners();
    }
  }

  // PUBLIC_INTERFACE
  Future<void> refreshFromCache() async {
    // Re-run current query; this should be instant due to cache.
    await submit();
  }

  // PUBLIC_INTERFACE
  Future<void> clearRecent() async {
    await cache.setStringList(_recentKey, <String>[]);
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
