import 'package:ott_frontend/core/services/simple_cache.dart';
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
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final SimpleCache cache = SimpleCache(prefs: prefs);

    final AppDatabase db = AppDatabase();
    await db.open();

    // Fake repository remains the source of truth; we layer a local cache on top.
    final ContentRepository repo = CachedContentRepository(
      remote: FakeContentRepository(),
      cache: cache,
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
