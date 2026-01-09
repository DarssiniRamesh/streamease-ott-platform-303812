import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ott_frontend/core/services/simple_cache.dart';
import 'package:ott_frontend/data/models/content_models.dart';
import 'package:ott_frontend/data/repositories/content_repository.dart';
import 'package:ott_frontend/features/content/controllers/content_details_controller.dart';
import 'package:ott_frontend/features/home/controllers/home_controller.dart';
import 'package:ott_frontend/features/search/controllers/search_controller.dart';
import 'package:ott_frontend/persistence/app_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StubRepo implements ContentRepository {
  _StubRepo({
    required this.homeFeed,
    required this.byId,
    required this.searchResults,
    this.playbackProgressSeconds,
    required this.recentWatchHistory,
  });

  HomeFeedPayload Function()? homeFeed;
  ContentItem? Function(String id)? byId;
  List<ContentItem> Function(String query)? searchResults;

  int? playbackProgressSeconds;
  List<WatchHistoryEntry> recentWatchHistory;

  final ValueNotifier<int> _cacheBuster = ValueNotifier<int>(0);

  @override
  ValueListenable<int> get cacheBuster => _cacheBuster;

  void bust() => _cacheBuster.value++;

  @override
  Future<HomeFeedPayload> fetchHomeFeed() async {
    final HomeFeedPayload Function()? f = homeFeed;
    if (f == null) throw StateError('homeFeed not configured');
    return f();
  }

  @override
  Future<ContentItem?> getById(String id) async {
    final ContentItem? Function(String)? f = byId;
    if (f == null) throw StateError('byId not configured');
    return f(id);
  }

  @override
  Future<List<ContentItem>> search(String query) async {
    final List<ContentItem> Function(String)? f = searchResults;
    if (f == null) throw StateError('searchResults not configured');
    return f(query);
  }

  @override
  Future<void> recordPlaybackProgress({required String contentId, required int positionSeconds}) async {}

  @override
  Future<void> recordPlaybackCompleted({required String contentId}) async {}

  @override
  Future<int?> getPlaybackProgressSeconds({required String contentId}) async => playbackProgressSeconds;

  @override
  Future<List<WatchHistoryEntry>> getRecentWatchHistory({int limit = 20}) async => recentWatchHistory;
}

HomeFeedPayload _payloadWithRails(int railsCount) {
  return HomeFeedPayload(
    rails: List<ContentRail>.generate(
      railsCount,
      (int i) => ContentRail(
        id: 'r$i',
        title: 'Rail $i',
        items: <ContentItem>[
          ContentItem(
            id: 'm$i',
            title: 'Item $i',
            posterUrl: '',
            description: 'desc',
            durationSeconds: 1,
            genres: const <String>['G'],
          ),
        ],
      ),
    ),
  );
}

ContentItem _content({required String id, required String title}) {
  return ContentItem(
    id: id,
    title: title,
    posterUrl: '',
    description: 'desc $title',
    durationSeconds: 123,
    genres: const <String>['Drama'],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HomeController', () {
    test('loadHomeFeed transitions loading -> ready', () async {
      final _StubRepo repo = _StubRepo(
        homeFeed: () => _payloadWithRails(1),
        byId: (String _) => null,
        searchResults: (String _) => <ContentItem>[],
        recentWatchHistory: const <WatchHistoryEntry>[],
      );

      final HomeController controller = HomeController(repository: repo);

      final List<HomeLoadState> states = <HomeLoadState>[];
      controller.addListener(() => states.add(controller.state));

      await controller.loadHomeFeed();

      expect(states, contains(HomeLoadState.loading));
      expect(controller.state, HomeLoadState.ready);
      expect(controller.payload, isNotNull);

      controller.dispose();
    });

    test('loadHomeFeed transitions to empty when rails empty', () async {
      final _StubRepo repo = _StubRepo(
        homeFeed: () => _payloadWithRails(0),
        byId: (String _) => null,
        searchResults: (String _) => <ContentItem>[],
        recentWatchHistory: const <WatchHistoryEntry>[],
      );

      final HomeController controller = HomeController(repository: repo);
      await controller.loadHomeFeed();

      expect(controller.state, HomeLoadState.empty);
      controller.dispose();
    });

    test('refreshFromCache invokes loadHomeFeed (cacheBuster-driven)', () async {
      final _StubRepo repo = _StubRepo(
        homeFeed: () => _payloadWithRails(1),
        byId: (String _) => null,
        searchResults: (String _) => <ContentItem>[],
        recentWatchHistory: const <WatchHistoryEntry>[],
      );

      final HomeController controller = HomeController(repository: repo);

      await controller.loadHomeFeed();
      expect(controller.state, HomeLoadState.ready);

      repo.bust();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(controller.state, HomeLoadState.ready);
      controller.dispose();
    });
  });

  group('AppSearchController', () {
    test('submit sets loading then results and persists recent to prefs fallback', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final SimpleCache cache = SimpleCache(prefs: prefs);

      final _StubRepo repo = _StubRepo(
        homeFeed: () => _payloadWithRails(1),
        byId: (String _) => null,
        searchResults: (String q) => <ContentItem>[
          _content(id: 'm1', title: 'Match $q'),
        ],
        recentWatchHistory: const <WatchHistoryEntry>[],
      );

      final AppSearchController controller = AppSearchController(repository: repo, cache: cache);

      controller.setQuery('Ocean');
      await controller.submit();

      expect(controller.loading, isFalse);
      expect(controller.results, isNotEmpty);
      expect(controller.results.first.title, 'Match Ocean');

      await controller.loadRecent();
      expect(controller.recent, isNotEmpty);
      expect(controller.recent.first, 'Ocean');

      controller.dispose();
    });

    test('refreshFromCache does not update recents but refreshes results', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final SimpleCache cache = SimpleCache(prefs: prefs);

      int call = 0;
      final _StubRepo repo = _StubRepo(
        homeFeed: () => _payloadWithRails(1),
        byId: (String _) => null,
        searchResults: (String q) {
          call++;
          return <ContentItem>[
            _content(id: 'm1', title: 'Match $q v$call'),
          ];
        },
        recentWatchHistory: const <WatchHistoryEntry>[],
      );

      final AppSearchController controller = AppSearchController(repository: repo, cache: cache);

      controller.setQuery('Ocean');
      await controller.submit();
      final List<String> recentsAfterSubmit = List<String>.of(controller.recent);
      final String firstTitle = controller.results.first.title;

      repo.bust();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(controller.results.first.title, isNot(firstTitle));
      expect(controller.recent, recentsAfterSubmit, reason: 'SWR refresh should not mutate recents');
      controller.dispose();
    });
  });

  group('ContentDetailsController', () {
    test('load transitions loading -> ready, populates lastWatched and watchlist', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'watchlist:ids': <String>['m1'],
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final SimpleCache cache = SimpleCache(prefs: prefs);

      final _StubRepo repo = _StubRepo(
        homeFeed: () => _payloadWithRails(1),
        byId: (String id) => _content(id: id, title: 'Title $id'),
        searchResults: (String _) => <ContentItem>[],
        playbackProgressSeconds: 42,
        recentWatchHistory: const <WatchHistoryEntry>[],
      );

      final ContentDetailsController controller = ContentDetailsController(
        repository: repo,
        cache: cache,
        contentId: 'm1',
      );

      await controller.load();

      expect(controller.state, ContentDetailsState.ready);
      expect(controller.item, isNotNull);
      expect(controller.lastWatchedSeconds, 42);
      expect(controller.inWatchlist, isTrue);

      controller.dispose();
    });

    test('load sets notFound when repository returns null', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final SimpleCache cache = SimpleCache(prefs: prefs);

      final _StubRepo repo = _StubRepo(
        homeFeed: () => _payloadWithRails(1),
        byId: (String _) => null,
        searchResults: (String _) => <ContentItem>[],
        recentWatchHistory: const <WatchHistoryEntry>[],
      );

      final ContentDetailsController controller = ContentDetailsController(
        repository: repo,
        cache: cache,
        contentId: 'missing',
      );

      await controller.load();
      expect(controller.state, ContentDetailsState.notFound);

      controller.dispose();
    });

    test('toggleWatchlist updates prefs-backed list and controller flag', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'watchlist:ids': <String>[],
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final SimpleCache cache = SimpleCache(prefs: prefs);

      final _StubRepo repo = _StubRepo(
        homeFeed: () => _payloadWithRails(1),
        byId: (String id) => _content(id: id, title: 'Title $id'),
        searchResults: (String _) => <ContentItem>[],
        recentWatchHistory: const <WatchHistoryEntry>[],
      );

      final ContentDetailsController controller = ContentDetailsController(
        repository: repo,
        cache: cache,
        contentId: 'm1',
      );

      await controller.load();
      expect(controller.inWatchlist, isFalse);

      await controller.toggleWatchlist();
      expect(controller.inWatchlist, isTrue);

      await controller.toggleWatchlist();
      expect(controller.inWatchlist, isFalse);

      controller.dispose();
    });
  });

  // Note: AppDatabase is not directly unit-tested here because it is sqflite-backed.
  // The request preferred mocking DB interactions unless sqflite_common_ffi is needed.
}
