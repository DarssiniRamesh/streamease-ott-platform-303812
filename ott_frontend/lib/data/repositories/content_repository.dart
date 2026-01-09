import 'package:flutter/foundation.dart';
import 'package:ott_frontend/data/models/content_models.dart';
import 'package:ott_frontend/persistence/app_database.dart';

/// Repository abstraction for content + local user state.
///
/// The app uses a cache-decorated implementation (SWR: stale-while-revalidate).
/// To support SWR without coupling controllers to cache internals, the repository
/// exposes a lightweight cache-update notification mechanism.
///
/// Controllers:
/// - call fetch/search/getById (which returns cached immediately when available)
/// - subscribe to cache update events to refresh their state when background
///   refreshes complete.
abstract class ContentRepository {
  // PUBLIC_INTERFACE
  Future<HomeFeedPayload> fetchHomeFeed();

  // PUBLIC_INTERFACE
  Future<List<ContentItem>> search(String query);

  // PUBLIC_INTERFACE
  Future<ContentItem?> getById(String id);

  // PUBLIC_INTERFACE
  ValueListenable<int> get cacheBuster;

  // PUBLIC_INTERFACE
  Future<void> recordPlaybackProgress({
    required String contentId,
    required int positionSeconds,
  });

  // PUBLIC_INTERFACE
  Future<void> recordPlaybackCompleted({required String contentId});

  // PUBLIC_INTERFACE
  Future<int?> getPlaybackProgressSeconds({required String contentId});

  // PUBLIC_INTERFACE
  Future<List<WatchHistoryEntry>> getRecentWatchHistory({int limit = 20});
}
