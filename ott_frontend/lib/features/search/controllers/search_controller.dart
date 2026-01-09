import 'package:flutter/foundation.dart';
import 'package:ott_frontend/core/services/simple_cache.dart';
import 'package:ott_frontend/data/models/content_models.dart';
import 'package:ott_frontend/data/repositories/content_repository.dart';

class AppSearchController extends ChangeNotifier {
  AppSearchController({required this.repository, required this.cache});

  final ContentRepository repository;
  final SimpleCache cache;

  static const String _recentKey = 'recent_searches';

  String _query = '';
  String get query => _query;

  bool _loading = false;
  bool get loading => _loading;

  List<ContentItem> _results = <ContentItem>[];
  List<ContentItem> get results => List<ContentItem>.unmodifiable(_results);

  List<String> get recent => cache.getStringList(_recentKey);

  // PUBLIC_INTERFACE
  void setQuery(String value) {
    _query = value;
    notifyListeners();
  }

  // PUBLIC_INTERFACE
  Future<void> submit() async {
    final String q = _query.trim();
    if (q.isEmpty) {
      _results = <ContentItem>[];
      notifyListeners();
      return;
    }

    _loading = true;
    notifyListeners();

    try {
      final List<ContentItem> r = await repository.search(q);

      // Update small cache.
      final List<String> existing = cache.getStringList(_recentKey);
      final List<String> next = <String>[q, ...existing.where((String e) => e.toLowerCase() != q.toLowerCase())]
          .take(10)
          .toList();
      await cache.setStringList(_recentKey, next);

      _results = r;
      _loading = false;
      notifyListeners();
    } catch (_) {
      _results = <ContentItem>[];
      _loading = false;
      notifyListeners();
    }
  }

  // PUBLIC_INTERFACE
  Future<void> clearRecent() async {
    await cache.setStringList(_recentKey, <String>[]);
    notifyListeners();
  }
}
