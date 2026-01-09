import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ott_frontend/core/services/app_bootstrap.dart';
import 'package:ott_frontend/features/downloads/services/fake_download_engine.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

bool _sqfliteFfiInitialized = false;

/// PUBLIC_INTERFACE
void initSqfliteFfiForTests() {
  /// Initialize sqflite to use the FFI implementation for unit/widget tests.
  ///
  /// This prevents tests from hanging when a platform implementation is not
  /// available (e.g., in `flutter test` on CI).
  ///
  /// This method is idempotent so it can safely be called from multiple test
  /// suites (e.g. multiple `main()` files).
  if (_sqfliteFfiInitialized) return;
  _sqfliteFfiInitialized = true;

  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}

/// PUBLIC_INTERFACE
Future<void> pumpFrames(
  WidgetTester tester, {
  int count = 5,
  Duration step = const Duration(milliseconds: 16),
}) async {
  /// Pumps a fixed number of frames.
  ///
  /// Use this as a fallback when you want deterministic progress without relying
  /// on a settle heuristic.
  for (int i = 0; i < count; i++) {
    await tester.pump(step);
  }
}

/// PUBLIC_INTERFACE
Future<void> pumpAndSettleBounded(
  WidgetTester tester, {
  Duration timeout = const Duration(seconds: 2),
  Duration step = const Duration(milliseconds: 20),
  int fallbackFrames = 5,
  bool assertNoScheduledFrames = false,
}) async {
  /// Pumps frames until the framework becomes idle, but with a strict upper bound.
  ///
  /// Why: `pumpAndSettle()` can hang indefinitely if anything keeps scheduling
  /// frames (periodic timers, animations, streams). This helper *never* loops
  /// forever, making CI hangs far less likely.
  ///
  /// Behavior:
  /// - Pump `step` repeatedly until `hasScheduledFrame` becomes false.
  /// - Stop after `timeout` regardless.
  /// - Pump a few extra fixed frames as a best-effort flush for microtasks.
  ///
  /// If [assertNoScheduledFrames] is true, this will assert that the framework is
  /// idle after the bounded loop + fallback frames.
  final Stopwatch sw = Stopwatch()..start();

  // Ensure at least one pump so initial microtasks/layout happen.
  await tester.pump(step);

  while (tester.binding.hasScheduledFrame && sw.elapsed < timeout) {
    await tester.pump(step);
  }

  // Always do a small deterministic drain to help flush late microtasks.
  await pumpFrames(tester, count: fallbackFrames, step: step);

  if (assertNoScheduledFrames) {
    expect(
      tester.binding.hasScheduledFrame,
      isFalse,
      reason: 'Framework still has scheduled frames after bounded settle. '
          'This usually means a timer/animation/stream is still running.',
    );
  }
}

/// PUBLIC_INTERFACE
Future<void> unmountWidgetTree(WidgetTester tester) async {
  /// Unmounts any current widget tree and pumps a bounded settle.
  ///
  /// This is important because:
  /// - Controllers/listeners are often disposed by Provider during unmount
  /// - Disposing can cancel timers/streams that otherwise keep the isolate alive
  await tester.pumpWidget(const SizedBox());
  await pumpAndSettleBounded(
    tester,
    timeout: const Duration(seconds: 1),
    assertNoScheduledFrames: true,
  );
}

/// PUBLIC_INTERFACE
Future<void> disposeAppDependencies(AppDependencies deps) async {
  /// Best-effort cleanup for widget tests to avoid keeping the isolate alive.
  ///
  /// - Cancel any active download timers (FakeDownloadEngine)
  /// - Close SQLite handle
  final Object engine = deps.downloadEngine;

  // Prefer a full timer cancellation when available (FakeDownloadEngine).
  if (engine is FakeDownloadEngine) {
    await engine.cancelAll();
  } else {
    // Backwards-compatible best-effort cancels for known IDs.
    await deps.downloadEngine.cancel(contentId: 'm1');
    await deps.downloadEngine.cancel(contentId: 'm2');
    await deps.downloadEngine.cancel(contentId: 'm3');
    await deps.downloadEngine.cancel(contentId: 's1e1');
    await deps.downloadEngine.cancel(contentId: 's1e2');
    await deps.downloadEngine.cancel(contentId: 'm4');
  }

  await deps.appDatabase.close();
}
