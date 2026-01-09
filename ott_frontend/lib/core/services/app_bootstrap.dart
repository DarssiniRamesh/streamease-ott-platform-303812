import 'package:ott_frontend/core/services/simple_cache.dart';
import 'package:ott_frontend/core/services/test_config.dart';
import 'package:ott_frontend/data/repositories/cached_content_repository.dart';
import 'package:ott_frontend/data/repositories/content_repository.dart';
import 'package:ott_frontend/data/repositories/fake_content_repository.dart';
import 'package:ott_frontend/features/downloads/services/download_engine.dart';
import 'package:ott_frontend/features/downloads/services/fake_download_engine.dart';
import 'package:ott_frontend/persistence/app_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppDependencies {
  AppDependencies({
    required this.simpleCache,
    required this.contentRepository,
    required this.appDatabase,
    required this.downloadEngine,
  });

  final SimpleCache simpleCache;
  final ContentRepository contentRepository;
  final AppDatabase appDatabase;
  final DownloadEngine downloadEngine;
}

class AppBootstrap {
  // PUBLIC_INTERFACE
  static Future<AppDependencies> bootstrap() async {
    /// Creates the app's dependency graph.
    ///
    /// Test behavior:
    /// - When `TestConfig.disableAutoStart` is true, this method avoids opening
    ///   SQLite and returns lightweight deps instead. Widget tests should either:
    ///   (a) manually create deps they need, or
    ///   (b) call `AppBootstrap.bootstrap()` and then pump widgets without any
    ///       background tasks/timers starting implicitly.
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final SimpleCache cache = SimpleCache(prefs: prefs);

    // In widget tests, avoid opening SQLite by default. This prevents background
    // sqflite work from keeping the isolate alive and eliminates a common hang
    // source when platform DB paths are not configured.
    if (TestConfig.disableAutoStart) {
      final ContentRepository repo = CachedContentRepository(
        remote: FakeContentRepository(),
        cache: cache,
        db: null,
      );

      return AppDependencies(
        simpleCache: cache,
        contentRepository: repo,
        appDatabase: AppDatabase(),
        downloadEngine: FakeDownloadEngine(),
      );
    }

    final AppDatabase db = AppDatabase();
    await db.open();

    // Fake repository remains the source of truth; we layer a local cache on top.
    // The cache decorator also owns write-through persistence for watch history.
    final ContentRepository repo = CachedContentRepository(
      remote: FakeContentRepository(),
      cache: cache,
      db: db,
    );

    final DownloadEngine engine = FakeDownloadEngine();

    return AppDependencies(
      simpleCache: cache,
      contentRepository: repo,
      appDatabase: db,
      downloadEngine: engine,
    );
  }
}
