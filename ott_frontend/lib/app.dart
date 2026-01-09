import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ott_frontend/core/i18n/app_localizations.dart';
import 'package:ott_frontend/core/routing/app_router.dart';
import 'package:ott_frontend/core/routing/app_shell.dart';
import 'package:ott_frontend/core/services/app_bootstrap.dart';
import 'package:ott_frontend/core/theme/ocean_theme.dart';
import 'package:ott_frontend/features/downloads/controllers/download_controller.dart';
import 'package:ott_frontend/features/home/controllers/home_controller.dart';
import 'package:ott_frontend/features/profile/controllers/settings_controller.dart';
import 'package:ott_frontend/features/search/controllers/search_controller.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

class StreamEaseApp extends StatelessWidget {
  const StreamEaseApp({super.key, required this.deps});

  final AppDependencies deps;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: <SingleChildWidget>[
        Provider<AppDependencies>.value(value: deps),
        ChangeNotifierProvider<HomeController>(
          create: (_) => HomeController(
            repository: deps.contentRepository,
            cache: deps.simpleCache,
          )..loadHomeFeed(),
        ),
        ChangeNotifierProvider<AppSearchController>(
          create: (_) => AppSearchController(
            repository: deps.contentRepository,
            cache: deps.simpleCache,
          ),
        ),
        ChangeNotifierProvider<DownloadController>(
          create: (_) => DownloadController(
            db: deps.appDatabase,
            engine: deps.downloadEngine,
          )..restoreFromDisk(),
        ),
        ChangeNotifierProvider<SettingsController>(
          create: (_) => SettingsController(cache: deps.simpleCache)..load(),
        ),
      ],
      child: MaterialApp(
        title: 'StreamEase',
        theme: OceanTheme.lightTheme,
        // Foundations for a11y/i18n
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
          DefaultMaterialLocalizations.delegate,
          DefaultCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        onGenerateRoute: AppRouter.onGenerateRoute,
        home: const AppShell(),
      ),
    );
  }
}
