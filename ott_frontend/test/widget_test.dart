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
    // Safety: ensure prefs are mocked before *any* bootstrap that may read them.
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final AppDependencies deps = await AppBootstrap.bootstrap();

    addTearDown(() async {
      // Reset test config first (so later tests start clean).
      TestConfig.reset();

      // Dispose widget tree first so providers/controllers cancel debounces/listeners.
      // This includes a final unmount to a const SizedBox() + bounded pumps.
      await unmountWidgetTree(tester);

      // Then close DB / cancel any download timers.
      await disposeAppDependencies(deps);

      // Extra bounded pumps + fail fast if anything keeps scheduling frames.
      await assertNoScheduledFramesAfterPumps(
        tester,
        reason: 'Widget tree teardown left scheduled frames behind.',
      );
    });

    await tester.pumpWidget(StreamEaseApp(deps: deps));

    // Explicit bounded pumps + fail fast.
    await assertNoScheduledFramesAfterPumps(
      tester,
      reason: 'App left scheduled frames behind after initial boot pumps.',
    );

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Downloads'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });
}
