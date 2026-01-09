import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ott_frontend/app.dart';
import 'package:ott_frontend/core/routing/app_routes.dart';
import 'package:ott_frontend/core/routing/app_router.dart';
import 'package:ott_frontend/core/services/app_bootstrap.dart';
import 'package:ott_frontend/core/services/simple_cache.dart';
import 'package:ott_frontend/data/models/content_models.dart';
import 'package:ott_frontend/data/repositories/cached_content_repository.dart';
import 'package:ott_frontend/data/repositories/content_repository.dart';
import 'package:ott_frontend/features/downloads/services/fake_download_engine.dart';
import 'package:ott_frontend/persistence/app_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helper.dart';

class _SlowRemoteRepo implements ContentRepository {
  _SlowRemoteRepo({required this.item});

  final ContentItem item;

  final ValueNotifier<int> _cacheBuster = ValueNotifier<int>(0);
  @override
  ValueListenable<int> get cacheBuster => _cacheBuster;

  @override
  Future<ContentItem?> getById(String id) async {
    // Make remote slower than a typical test pump; we want to validate cached render.
    await Future<void>.delayed(const Duration(seconds: 2));
    return id == item.id ? item : null;
  }

  @override
  Future<HomeFeedPayload> fetchHomeFeed() async {
    // Not used by this test.
    return HomeFeedPayload(rails: <ContentRail>[]);
  }

  @override
  Future<List<ContentItem>> search(String query) async => <ContentItem>[];

  @override
  Future<void> recordPlaybackProgress({required String contentId, required int positionSeconds}) async {}

  @override
  Future<void> recordPlaybackCompleted({required String contentId}) async {}

  @override
  Future<int?> getPlaybackProgressSeconds({required String contentId}) async => null;

  @override
  Future<List<WatchHistoryEntry>> getRecentWatchHistory({int limit = 20}) async => <WatchHistoryEntry>[];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    initSqfliteFfiForTests();
  });

  testWidgets('Navigates to ContentDetails and renders immediately from cached details', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final SimpleCache cache = SimpleCache(prefs: prefs);

    final ContentItem item = ContentItem(
      id: 'm1',
      title: 'Cached Title',
      posterUrl: '',
      description: 'Cached Description',
      durationSeconds: 123,
      genres: const <String>['Drama'],
    );

    // Prepare repo with slow remote, but prefill cache so ContentDetails is instantaneous.
    final CachedContentRepository repo = CachedContentRepository(
      remote: _SlowRemoteRepo(item: item),
      cache: cache,
    );
    await cache.putJson('content_details_v1:${item.id}', item.toJson());

    // For this widget test, ContentDetails loads download state via AppDatabase. Provide a DB instance.
    final AppDatabase db = AppDatabase();
    await db.open();

    final FakeDownloadEngine engine = FakeDownloadEngine();

    addTearDown(() async {
      // Tear down widget tree first to dispose providers/controllers.
      await unmountWidgetTree(tester);

      // Cancel any active timers and close DB.
      await engine.cancelAll();
      await db.close();
    });

    final AppDependencies deps = AppDependencies(
      simpleCache: cache,
      contentRepository: repo,
      appDatabase: db,
      downloadEngine: engine,
    );

    await tester.pumpWidget(StreamEaseApp(deps: deps));
    await pumpAndSettleBounded(tester, timeout: const Duration(seconds: 1));

    // Ensure we are on a stable initial frame before navigation.
    await tester.tap(find.text('Home'));
    await pumpAndSettleBounded(tester, timeout: const Duration(milliseconds: 800));

    // Navigate using NavigatorState.pushNamed, but keep pumping bounded (never
    // wait for an unbounded settle).
    tester.state<NavigatorState>(find.byType(Navigator)).pushNamed(
          AppRoutes.contentDetails,
          arguments: const ContentDetailsArgs(contentId: 'm1'),
        );
    await tester.pump();
    await pumpAndSettleBounded(tester, timeout: const Duration(milliseconds: 800));

    // Cached title should be rendered without waiting 2 seconds for remote.
    expect(find.text('Cached Title'), findsWidgets);
    expect(find.text('Cached Description'), findsOneWidget);
  });
}
