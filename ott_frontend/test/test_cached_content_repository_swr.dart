import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ott_frontend/core/services/simple_cache.dart';
import 'package:ott_frontend/data/models/content_models.dart';
import 'package:ott_frontend/data/repositories/cached_content_repository.dart';
import 'package:ott_frontend/data/repositories/content_repository.dart';
import 'package:ott_frontend/persistence/app_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ControlledRemoteRepo implements ContentRepository {
  _ControlledRemoteRepo({
    required this.homeFeedResponses,
    required this.detailsResponses,
  });

  final Queue<HomeFeedPayload> homeFeedResponses;
  final Map<String, Queue<ContentItem?>> detailsResponses;

  int fetchHomeFeedCalls = 0;
  int getByIdCalls = 0;

  final ValueNotifier<int> _cacheBuster = ValueNotifier<int>(0);

  @override
  ValueListenable<int> get cacheBuster => _cacheBuster;

  @override
  Future<HomeFeedPayload> fetchHomeFeed() async {
    fetchHomeFeedCalls++;
    // Ensure refresh runs asynchronously (SWR), not inline.
    await Future<void>.delayed(const Duration(milliseconds: 1));

    if (homeFeedResponses.isEmpty) {
      throw StateError('No more home feed responses configured');
    }
    return homeFeedResponses.removeFirst();
  }

  @override
  Future<ContentItem?> getById(String id) async {
    getByIdCalls++;
    await Future<void>.delayed(const Duration(milliseconds: 1));

    final Queue<ContentItem?>? q = detailsResponses[id];
    if (q == null || q.isEmpty) {
      return null;
    }
    return q.removeFirst();
  }

  @override
  Future<List<ContentItem>> search(String query) async {
    throw UnimplementedError();
  }

  @override
  Future<void> recordPlaybackProgress({required String contentId, required int positionSeconds}) async {
    throw UnimplementedError();
  }

  @override
  Future<void> recordPlaybackCompleted({required String contentId}) async {
    throw UnimplementedError();
  }

  @override
  Future<int?> getPlaybackProgressSeconds({required String contentId}) async {
    throw UnimplementedError();
  }

  @override
  Future<List<WatchHistoryEntry>> getRecentWatchHistory({int limit = 20}) async {
    throw UnimplementedError();
  }
}

HomeFeedPayload _homeWithTitle(String railTitle) {
  return HomeFeedPayload(
    rails: <ContentRail>[
      ContentRail(
        id: 'r1',
        title: railTitle,
        items: <ContentItem>[
          ContentItem(
            id: 'm1',
            title: 'Item $railTitle',
            posterUrl: '',
            description: 'desc',
            durationSeconds: 1,
            genres: const <String>['G'],
          ),
        ],
      ),
    ],
  );
}

ContentItem _itemWithTitle({required String id, required String title}) {
  return ContentItem(
    id: id,
    title: title,
    posterUrl: '',
    description: 'desc $title',
    durationSeconds: 1,
    genres: const <String>['G'],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CachedContentRepository SWR', () {
    test('fetchHomeFeed returns cached immediately and refreshes in background', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final SimpleCache cache = SimpleCache(prefs: prefs);

      final _ControlledRemoteRepo remote = _ControlledRemoteRepo(
        homeFeedResponses: Queue<HomeFeedPayload>.from(<HomeFeedPayload>[
          _homeWithTitle('Network v1'),
          _homeWithTitle('Network v2'),
        ]),
        detailsResponses: <String, Queue<ContentItem?>>{},
      );

      final CachedContentRepository repo = CachedContentRepository(
        remote: remote,
        cache: cache,
        homeTtl: const Duration(minutes: 10),
      );

      int cacheBusterTicks = 0;
      repo.cacheBuster.addListener(() => cacheBusterTicks++);

      final HomeFeedPayload first = await repo.fetchHomeFeed();
      expect(first.rails.single.title, 'Network v1');
      expect(remote.fetchHomeFeedCalls, 1);
      expect(cacheBusterTicks, 1);

      // Second call: within TTL -> returns cached (v1), schedules background refresh to v2.
      final HomeFeedPayload second = await repo.fetchHomeFeed();
      expect(second.rails.single.title, 'Network v1');
      expect(remote.fetchHomeFeedCalls, 2, reason: 'Background refresh should call remote again');

      // Allow refresh future to complete.
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Cache should now contain v2, and cacheBuster should tick again.
      expect(cacheBusterTicks, 2);
      final HomeFeedPayload third = await repo.fetchHomeFeed();
      expect(third.rails.single.title, 'Network v2');
    });

    test('getById returns stale cache immediately then refreshes to newer value', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final SimpleCache cache = SimpleCache(prefs: prefs);

      final _ControlledRemoteRepo remote = _ControlledRemoteRepo(
        homeFeedResponses: Queue<HomeFeedPayload>(),
        detailsResponses: <String, Queue<ContentItem?>>{
          'm1': Queue<ContentItem?>.from(<ContentItem?>[
            _itemWithTitle(id: 'm1', title: 'Network v1'),
            _itemWithTitle(id: 'm1', title: 'Network v2'),
          ]),
        },
      );

      final CachedContentRepository repo = CachedContentRepository(
        remote: remote,
        cache: cache,
        detailsTtl: const Duration(hours: 6),
      );

      int cacheBusterTicks = 0;
      repo.cacheBuster.addListener(() => cacheBusterTicks++);

      // First: no cache -> network v1, writes cache.
      final ContentItem? first = await repo.getById('m1');
      expect(first, isNotNull);
      expect(first!.title, 'Network v1');
      expect(cacheBusterTicks, 1);

      // Second: cached -> returns v1 immediately, schedules refresh -> v2.
      final ContentItem? second = await repo.getById('m1');
      expect(second, isNotNull);
      expect(second!.title, 'Network v1');
      expect(remote.getByIdCalls, 2);

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(cacheBusterTicks, 2);

      final ContentItem? third = await repo.getById('m1');
      expect(third, isNotNull);
      expect(third!.title, 'Network v2');
    });
  });
}
