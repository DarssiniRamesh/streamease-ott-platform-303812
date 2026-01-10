import 'package:flutter/material.dart';
import 'package:ott_frontend/core/motion/app_page_routes.dart';
import 'package:ott_frontend/core/routing/app_routes.dart';
import 'package:ott_frontend/features/content/screens/content_details_screen.dart';
import 'package:ott_frontend/features/profile/screens/settings_screen.dart';

class ContentDetailsArgs {
  const ContentDetailsArgs({required this.contentId});
  final String contentId;
}

class AppRouter {
  // PUBLIC_INTERFACE
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.contentDetails:
        final Object? args = settings.arguments;
        if (args is! ContentDetailsArgs) {
          return _errorRoute('Missing contentId');
        }
        return FadeThroughPageRoute<void>(
          settings: settings,
          builder: (_) => ContentDetailsScreen(contentId: args.contentId),
        );
      case AppRoutes.settings:
        return FadeThroughPageRoute<void>(
          settings: settings,
          builder: (_) => const SettingsScreen(),
        );
      default:
        return null;
    }
  }

  static Route<dynamic> _errorRoute(String message) {
    return FadeThroughPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Route error')),
        body: Center(child: Text(message)),
      ),
    );
  }
}
