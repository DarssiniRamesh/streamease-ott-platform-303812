import 'package:flutter_test/flutter_test.dart';
import 'package:ott_frontend/app.dart';
import 'package:ott_frontend/core/services/app_bootstrap.dart';
import 'package:ott_frontend/core/services/test_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // CRITICAL: must be initialized before any SharedPreferences.getInstance()
    // calls, including any potential indirect calls during bootstrap.
    SharedPreferences.setMockInitialValues(<String, Object>{});

    // Must occur before any AppDatabase.open calls (AppBootstrap.bootstrap opens SQLite).
    initSqfliteFfiForTests();
  });

  setUp(() {
    // Ensure background work is disabled for every widget test, even if a prior
    // test failed before it could reset.
    TestConfig.disableAutoStart = true;

    // Must be initialized before any SharedPreferences.getInstance() calls.
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('App boots and shows bottom navigation', (WidgetTester tester) async {
    // Minimal diagnostics: if something starts a ticker/timer and keeps frames
    // scheduled, fail fast here instead of hanging later.
    expect(
      tester.binding.hasScheduledFrame,
      isFalse,
      reason: 'Test started with a scheduled frame (unexpected).',
    );

    // MUST happen after setMockInitialValues; bootstrap calls SharedPreferences.getInstance().
    final AppDependencies deps = await AppBootstrap.bootstrap();

    addTearDown(() async {
      // Order matters:
      // 1) unmount the widget tree so Providers dispose controllers/tickers/listeners
      // 2) dispose app dependencies (DB, timers)
      // 3) reset global test config + prefs mock (keep subsequent tests deterministic)
      await unmountWidgetTree(tester);
      await disposeAppDependencies(deps);
      TestConfig.reset();

      // Ensure next tests cannot observe any leftover preference state.
      SharedPreferences.setMockInitialValues(<String, Object>{});

      // Final fail-fast: verify nothing is still scheduling frames.
      await assertNoScheduledFramesAfterPumps(
        tester,
        reason: 'Widget tree teardown left scheduled frames behind.',
      );
    });

    await tester.pumpWidget(StreamEaseApp(deps: deps));

    // Make progress deterministic: pump bounded until the expected navigation labels appear.
    // Avoid any unbounded settle.
    await pumpUntilFound(tester, find.text('Home'), timeout: const Duration(seconds: 2));

    // Extra bounded drain to catch any stray scheduled frames started by constructors.
    await pumpAndSettleBounded(
      tester,
      timeout: const Duration(seconds: 1),
      assertNoScheduledFrames: true,
    );

    expect(find.text('Home'), findsWidgets);
    expect(find.text('Search'), findsWidgets);
    expect(find.text('Downloads'), findsWidgets);
    expect(find.text('Profile'), findsWidgets);
  });
}
