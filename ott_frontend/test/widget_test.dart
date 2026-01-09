import 'package:flutter_test/flutter_test.dart';
import 'package:ott_frontend/app.dart';
import 'package:ott_frontend/core/services/app_bootstrap.dart';
import 'package:ott_frontend/core/services/test_config.dart';

import 'test_helper.dart';

void main() {
  setUpAll(() {
    // Must occur before any AppDatabase.open calls (AppBootstrap.bootstrap opens SQLite).
    initSqfliteFfiForTests();
  });

  testWidgets('App boots and shows bottom navigation', (WidgetTester tester) async {
    TestConfig.disableAutoStart = true;

    final AppDependencies deps = await AppBootstrap.bootstrap();

    addTearDown(() async {
      // Reset test config first (so later tests start clean).
      TestConfig.reset();

      // Dispose widget tree first so providers/controllers cancel debounces/listeners.
      await unmountWidgetTree(tester);

      // Then close DB / cancel any download timers.
      await disposeAppDependencies(deps);

      // After teardown there should be no scheduled frames.
      expect(
        tester.binding.hasScheduledFrame,
        isFalse,
        reason: 'Widget tree teardown left scheduled frames behind.',
      );
    });

    await tester.pumpWidget(StreamEaseApp(deps: deps));

    // Allow initial layout to complete; bounded + asserted idle.
    await pumpAndSettleBounded(
      tester,
      timeout: const Duration(seconds: 1),
      assertNoScheduledFrames: true,
    );

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Downloads'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });
}
