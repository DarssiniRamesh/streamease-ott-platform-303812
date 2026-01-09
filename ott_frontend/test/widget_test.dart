import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ott_frontend/app.dart';
import 'package:ott_frontend/core/services/app_bootstrap.dart';

import 'test_helper.dart';

void main() {
  setUpAll(() {
    // Must occur before any AppDatabase.open calls (AppBootstrap.bootstrap opens SQLite).
    initSqfliteFfiForTests();
  });

  testWidgets('App boots and shows bottom navigation', (WidgetTester tester) async {
    final AppDependencies deps = await AppBootstrap.bootstrap();

    addTearDown(() async {
      // Dispose widget tree first so providers/controllers cancel debounces/listeners.
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(),
        ),
      );
      await pumpAndSettleBounded(tester, max: const Duration(seconds: 1));

      // Then close DB / cancel any download timers.
      await disposeAppDependencies(deps);
    });

    await tester.pumpWidget(StreamEaseApp(deps: deps));

    // Allow initial provider async work to run, but avoid unbounded pumpAndSettle.
    await pumpAndSettleBounded(tester, max: const Duration(seconds: 2));

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Downloads'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });
}
