import 'package:flutter_test/flutter_test.dart';
import 'package:ott_frontend/core/services/app_bootstrap.dart';
import 'package:ott_frontend/features/downloads/services/fake_download_engine.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// PUBLIC_INTERFACE
void initSqfliteFfiForTests() {
  /// Initialize sqflite to use the FFI implementation for unit/widget tests.
  /// This prevents tests from hanging when a platform implementation is not
  /// available (e.g., in `flutter test` on CI).
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}

/// PUBLIC_INTERFACE
Future<void> pumpAndSettleBounded(
  WidgetTester tester, {
  Duration max = const Duration(seconds: 2),
  Duration step = const Duration(milliseconds: 20),
}) async {
  /// Pump frames until the framework is *actually* idle, but with a hard upper
  /// bound so tests cannot hang indefinitely if something schedules work forever.
  ///
  /// We consider the app idle when there is no scheduled frame. Since some
  /// Flutter versions/bindings used in CI don't expose transient-callback APIs
  /// here, we rely on this signal plus a strict max duration to prevent hangs.
  final DateTime start = DateTime.now();
  while (true) {
    await tester.pump(step);

    if (!tester.binding.hasScheduledFrame) return;

    if (DateTime.now().difference(start) >= max) return;
  }
}

/// PUBLIC_INTERFACE
Future<void> disposeAppDependencies(AppDependencies deps) async {
  /// Best-effort cleanup for widget tests to avoid keeping the isolate alive.
  ///
  /// - Cancel any active download timers (FakeDownloadEngine)
  /// - Close SQLite handle
  // Prefer a full timer cancellation when available (FakeDownloadEngine).
  final Object engine = deps.downloadEngine;
  if (engine is FakeDownloadEngine) {
    await engine.cancelAll();
  }

  // Backwards-compatible best-effort cancels for known IDs.
  await deps.downloadEngine.cancel(contentId: 'm1');
  await deps.downloadEngine.cancel(contentId: 'm2');
  await deps.downloadEngine.cancel(contentId: 'm3');
  await deps.downloadEngine.cancel(contentId: 's1e1');
  await deps.downloadEngine.cancel(contentId: 's1e2');
  await deps.downloadEngine.cancel(contentId: 'm4');

  await deps.appDatabase.close();
}
