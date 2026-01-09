import 'package:flutter_test/flutter_test.dart';
import 'package:ott_frontend/app.dart';
import 'package:ott_frontend/core/services/app_bootstrap.dart';
import 'package:ott_frontend/core/services/test_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
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
    // Must be mocked before *any* bootstrap work (bootstrap calls getInstance()).
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final AppDependencies deps = await AppBootstrap.bootstrap();

    addTearDown(() async {
      // Reset test config first (so later tests start clean).
      TestConfig.reset();

      // Dispose widget tree first so providers/controllers cancel debounces/listeners.
      // This includes a final unmount to a const SizedBox() + bounded settle.
      await unmountWidgetTree(tester);

      // Then close DB / cancel any download timers.
      await disposeAppDependencies(deps);

      // Fail fast if anything continues scheduling frames after teardown.
      await assertNoScheduledFramesAfterPumps(
        tester,
        reason: 'Widget tree teardown left scheduled frames behind.',
      );
    });

    await tester.pumpWidget(StreamEaseApp(deps: deps));

    // Fail fast if any unexpected background work starts scheduling frames
    // continuously (prevents silent hangs).
    await pumpUntilNoScheduledFrames(
      tester,
      timeout: const Duration(seconds: 1),
      reason: 'App did not go idle after initial build; background work may be running.',
    );

    // Do NOT assert global idleness beyond bounded: implicit animations (ink reactions,
    // focus highlights, etc.) can keep scheduling frames and make tests flaky/hang.
    // Instead, pump bounded and wait until the expected UI is present.
    await pumpUntilFound(tester, find.text('Home'));

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Downloads'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });
}
