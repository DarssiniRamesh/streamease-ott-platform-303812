import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:ott_frontend/core/services/simple_cache.dart';
import 'package:ott_frontend/core/services/test_config.dart';
import 'package:ott_frontend/data/models/content_models.dart';
import 'package:ott_frontend/data/repositories/content_repository.dart';
import 'package:ott_frontend/persistence/app_database.dart';

/// A cache decorator for the content repository implementing SWR semantics.
///
/// Key behavior:
/// - Cache-first reads: return cached payloads immediately (fresh OR stale)
/// - Background refresh: fetches latest from remote and updates cache
/// - Notification: emits a `cacheBuster` tick whenever cache is updated, so
///   controllers can reload state without duplicating cache logic.
///
/// This keeps controllers simple while still enabling "serve stale immediately,
/// then revalidate" (SWR).
class CachedContentRepository implements ContentRepository {
  CachedContentRepository({
    required this.remote,
    required this.cache,
    this.db,
    this.homeTtl = const Duration(minutes: 10),
    this.detailsTtl = const Duration(hours: 6),
    this.searchTtl = const Duration(minutes: 2),
  });

  final ContentRepository remote;
  final SimpleCache cache;

  /// Optional DB used for write-through user state (watch history).
  /// When omitted, watch history methods are best-effort no-ops.
  final AppDatabase? db;

  final Duration homeTtl;
  final Duration detailsTtl;
  final Duration searchTtl;

  static const String _homeKey = 'home_feed_v1';

  final ValueNotifier<int> _cacheBuster = ValueNotifier<int>(0);

  @override
  ValueListenable<int> get cacheBuster => _cacheBuster;

  void _bustCache() {
    _cacheBuster.value = _cacheBuster.value + 1;
  }

  String _detailsKey(String id) => 'content_details_v1:$id';

  /// We normalize searches so the same query maps to the same key.
  String _searchKey(String query) => 'search_results_v1:${_normalizeQuery(query)}';

  String _normalizeQuery(String query) => query.trim().toLowerCase();

  @override
  Future<HomeFeedPayload> fetchHomeFeed() async {
    final CacheEntry? fresh = cache.getJsonIfFresh(_homeKey, homeTtl);
    if (fresh != null) {
      // SWR: return immediately and refresh in background.
      if (!TestConfig.disableAutoStart) {
        unawaited(_refreshHomeFeed());
      }
      return HomeFeedPayload.fromJson(jsonDecode(fresh.json) as Map<String, dynamic>);
    }

    final CacheEntry? stale = cache.getJsonEvenIfStale(_homeKey);
    if (stale != null) {
      // Stale fallback + background refresh.
      if (!TestConfig.disableAutoStart) {
        unawaited(_refreshHomeFeed());
      }
      return HomeFeedPayload.fromJson(jsonDecode(stale.json) as Map<String, dynamic>);
    }

    // No cache: hit remote.
    final HomeFeedPayload net = await remote.fetchHomeFeed();
    await cache.putJson(_homeKey, net.toJson());
    _bustCache();
    return net;
  }

  Future<void> _refreshHomeFeed() async {
    try {
      final HomeFeedPayload net = await remote.fetchHomeFeed();
      await cache.putJson(_homeKey, net.toJson());
      _bustCache();
    } catch (_) {
      // Best-effort refresh; ignore failures so cached UI doesn't break.
    }
  }

  @override
  Future<ContentItem?> getById(String id) async {
    final String key = _detailsKey(id);

    final CacheEntry? fresh = cache.getJsonIfFresh(key, detailsTtl);
    if (fresh != null) {
      if (!TestConfig.disableAutoStart) {
        unawaited(_refreshDetails(id: id));
      }
      return ContentItem.fromJson(jsonDecode(fresh.json) as Map<String, dynamic>);
    }

    final CacheEntry? stale = cache.getJsonEvenIfStale(key);
    if (stale != null) {
      if (!TestConfig.disableAutoStart) {
        unawaited(_refreshDetails(id: id));
      }
      return ContentItem.fromJson(jsonDecode(stale.json) as Map<String, dynamic>);
    }

    final ContentItem? net = await remote.getById(id);
    if (net != null) {
      await cache.putJson(key, net.toJson());
      _bustCache();
    }
    return net;
  }

  Future<void> _refreshDetails({required String id}) async {
    try {
      final ContentItem? net = await remote.getById(id);
      if (net != null) {
        await cache.putJson(_detailsKey(id), net.toJson());
        _bustCache();
      }
    } catch (_) {
      // Best-effort refresh only.
    }
  }

  @override
  Future<List<ContentItem>> search(String query) async {
    // Optional short-lived caching for repeated queries.
    final String q = query.trim();
    if (q.isEmpty) return <ContentItem>[];

    final String key = _searchKey(q);
    final CacheEntry? fresh = cache.getJsonIfFresh(key, searchTtl);
    if (fresh != null) {
      if (!TestConfig.disableAutoStart) {
        unawaited(_refreshSearch(query: q));
      }
      return _decodeSearchResults(fresh.json);
    }

    final CacheEntry? stale = cache.getJsonEvenIfStale(key);
    if (stale != null) {
      if (!TestConfig.disableAutoStart) {
        unawaited(_refreshSearch(query: q));
      }
      return _decodeSearchResults(stale.json);
    }

    final List<ContentItem> net = await remote.search(q);
    await cache.putJson(key, _encodeSearchResults(net));
    _bustCache();
    return net;
  }

  Future<void> _refreshSearch({required String query}) async {
    try {
      final List<ContentItem> net = await remote.search(query);
      await cache.putJson(_searchKey(query), _encodeSearchResults(net));
      _bustCache();
    } catch (_) {
      // Best-effort refresh only.
    }
  }

  List<ContentItem> _decodeSearchResults(String json) {
    final Map<String, dynamic> decoded = jsonDecode(json) as Map<String, dynamic>;
    final List<dynamic> raw = (decoded['items'] as List<dynamic>?) ?? const <dynamic>[];
    return raw.map((dynamic e) => ContentItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Map<String, dynamic> _encodeSearchResults(List<ContentItem> items) {
    return <String, dynamic>{
      'items': items.map((ContentItem e) => e.toJson()).toList(),
    };
  }

  @override
  Future<void> recordPlaybackProgress({
    required String contentId,
    required int positionSeconds,
  }) async {
    final AppDatabase? d = db;
    if (d == null) return;
    await d.upsertWatchProgress(contentId: contentId, positionSeconds: positionSeconds);
  }

  @override
  Future<void> recordPlaybackCompleted({required String contentId}) async {
    // For now, treat completion as a progress update at 0 (or could be duration later).
    // This keeps the API stable without requiring duration knowledge at this layer.
    final AppDatabase? d = db;
    if (d == null) return;
    await d.upsertWatchProgress(contentId: contentId, positionSeconds: 0);
  }

  @override
  Future<int?> getPlaybackProgressSeconds({required String contentId}) async {
    final AppDatabase? d = db;
    if (d == null) return null;
    return d.getWatchProgressSeconds(contentId: contentId);
  }

  @override
  Future<List<WatchHistoryEntry>> getRecentWatchHistory({int limit = 20}) async {
    final AppDatabase? d = db;
    if (d == null) return <WatchHistoryEntry>[];
    return d.getRecentWatchHistory(limit: limit);
  }
}
