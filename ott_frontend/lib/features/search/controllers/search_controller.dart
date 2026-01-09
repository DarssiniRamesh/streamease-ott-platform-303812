import 'package:flutter/foundation.dart';
import 'package:ott_frontend/core/services/simple_cache.dart';
import 'package:ott_frontend/core/services/test_config.dart';
import 'package:ott_frontend/data/models/content_models.dart';
import 'package:ott_frontend/data/repositories/content_repository.dart';
import 'package:ott_frontend/persistence/app_database.dart';

class AppSearchController extends ChangeNotifier {
  AppSearchController({
    required this.repository,
    required this.cache,
    this.db,
  }) {
    _cacheListener = () {
      // In widget tests we disable auto-start to avoid any SWR-driven background
      // work that can keep scheduling frames and cause hangs.
      if (TestConfig.disableAutoStart) return;

      final String q = _query.trim();
      if (q.isEmpty) return;

      // SWR refresh completion: re-run the query to pick up fresh cached results,
      // without modifying the "recent searches" list.
      refreshFromCache();
    };
    repository.cacheBuster.addListener(_cacheListener!);
  }

  final ContentRepository repository;
  final SimpleCache cache;

  /// Optional DB for durable recents (preferred over preferences).
  final AppDatabase? db;

  VoidCallback? _cacheListener;

  static const String _recentKeyFallback = 'recent_searches';

  String _query = '';
  String get query => _query;

  bool _loading = false;
  bool get loading => _loading;

  bool _refreshing = false;
  bool get refreshing => _refreshing;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<ContentItem> _results = <ContentItem>[];
  List<ContentItem> get results => List<ContentItem>.unmodifiable(_results);

  final List<String> _recent = <String>[];
  List<String> get recent => List<String>.unmodifiable(_recent);

  bool _refreshInFlight = false;

  // PUBLIC_INTERFACE
  Future<void> loadRecent() async {
    // Fast path: show fallback cached recents immediately.
    _recent
      ..clear()
      ..addAll(cache.getStringList(_recentKeyFallback));
    notifyListeners();

    final AppDatabase? d = db;
    if (d == null) return;

    try {
      final List<String> fromDb = await d.getRecentSearches(limit: 10);
      _recent
        ..clear()
        ..addAll(fromDb);
      notifyListeners();
    } catch (_) {
      // If DB read fails, keep fallback.
    }
  }

  // PUBLIC_INTERFACE
  void setQuery(String value) {
    _query = value;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> _persistRecent(String query) async {
    final String q = query.trim();
    if (q.isEmpty) return;

    // Keep a preferences fallback in sync for fast reads / DB not available.
    final List<String> existing = cache.getStringList(_recentKeyFallback);
    final List<String> next =
        <String>[q, ...existing.where((String e) => e.toLowerCase() != q.toLowerCase())].take(10).toList();
    await cache.setStringList(_recentKeyFallback, next);

    // Durable DB write when available.
    final AppDatabase? d = db;
    if (d != null) {
      await d.upsertRecentSearch(query: q);
    }
  }

  Future<void> _runQuery({
    required String query,
    required bool updateRecents,
    required bool showRefreshing,
  }) async {
    final String q = query.trim();
    if (q.isEmpty) {
      _results = <ContentItem>[];
      _errorMessage = null;
      _loading = false;
      _refreshing = false;
      notifyListeners();
      return;
    }

    if (showRefreshing) {
      _refreshing = true;
      notifyListeners();
    }

    try {
      // Repository is cache-first + SWR, so this will return cached results
      // immediately (if present) and revalidate in background.
      final List<ContentItem> r = await repository.search(q);
      _results = r;

      if (updateRecents) {
        await _persistRecent(q);
        await loadRecent();
      }

      _errorMessage = null;
      _refreshing = false;
      notifyListeners();
    } catch (_) {
      // Keep previous results if any; show soft error.
      _errorMessage = 'Search failed.';
      _refreshing = false;
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

    // Since repository is cache-first, keep "loading" for explicit submits (UX),
    // but the user may still see immediate cached results.
    _loading = true;
    _errorMessage = null;
    notifyListeners();

    await _runQuery(query: q, updateRecents: true, showRefreshing: false);

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
      await _runQuery(query: q, updateRecents: false, showRefreshing: true);
    }

    _refreshInFlight = false;
  }

  // PUBLIC_INTERFACE
  Future<void> clearRecent() async {
    await cache.setStringList(_recentKeyFallback, <String>[]);
    final AppDatabase? d = db;
    if (d != null) {
      await d.clearRecentSearches();
    }
    await loadRecent();
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
