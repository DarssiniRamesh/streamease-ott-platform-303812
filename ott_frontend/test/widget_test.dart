import 'package:flutter_test/flutter_test.dart';
import 'package:ott_frontend/app.dart';
import 'package:ott_frontend/core/services/app_bootstrap.dart';

import 'test_helper.dart';

void main() {
  setUpAll(() {
    initSqfliteFfiForTests();
  });

  testWidgets('App boots and shows bottom navigation', (WidgetTester tester) async {
    final AppDependencies deps = await AppBootstrap.bootstrap();
    await tester.pumpWidget(StreamEaseApp(deps: deps));

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Downloads'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });
}
