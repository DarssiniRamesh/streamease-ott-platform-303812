import 'package:flutter/foundation.dart';
import 'package:ott_frontend/core/services/simple_cache.dart';
import 'package:ott_frontend/data/models/content_models.dart';
import 'package:ott_frontend/data/repositories/content_repository.dart';

class AppSearchController extends ChangeNotifier {
  AppSearchController({required this.repository, required this.cache}) {
    _cacheListener = () {
      final String q = _query.trim();
      if (q.isEmpty) return;

      // SWR refresh completion: re-run the query to pick up fresh cached results,
      // without modifying the "recent searches" list or toggling loading UI.
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

  bool _refreshInFlight = false;

  // PUBLIC_INTERFACE
  void setQuery(String value) {
    _query = value;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> _runQuery({required String query, required bool updateRecents}) async {
    if (query.trim().isEmpty) {
      _results = <ContentItem>[];
      _errorMessage = null;
      notifyListeners();
      return;
    }

    try {
      final List<ContentItem> r = await repository.search(query);
      _results = r;

      if (updateRecents) {
        final List<String> existing = cache.getStringList(_recentKey);
        final List<String> next =
            <String>[query, ...existing.where((String e) => e.toLowerCase() != query.toLowerCase())]
                .take(10)
                .toList();
        await cache.setStringList(_recentKey, next);
      }

      notifyListeners();
    } catch (_) {
      _results = <ContentItem>[];
      _errorMessage = 'Search failed.';
      notifyListeners();
    }
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

    await _runQuery(query: q, updateRecents: true);

    _loading = false;
    notifyListeners();
  }

  // PUBLIC_INTERFACE
  Future<void> refreshFromCache() async {
    // Avoid piling up refresh work if cacheBuster is noisy.
    if (_refreshInFlight) return;
    _refreshInFlight = true;

    final String q = _query.trim();
    if (q.isNotEmpty) {
      await _runQuery(query: q, updateRecents: false);
    }

    _refreshInFlight = false;
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
