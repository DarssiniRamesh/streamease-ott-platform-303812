import 'package:flutter/material.dart';
import 'package:ott_frontend/core/i18n/app_localizations.dart';
import 'package:ott_frontend/core/routing/app_routes.dart';
import 'package:ott_frontend/features/downloads/screens/downloads_root_screen.dart';
import 'package:ott_frontend/features/home/screens/home_root_screen.dart';
import 'package:ott_frontend/features/profile/screens/profile_root_screen.dart';
import 'package:ott_frontend/features/search/screens/search_root_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final List<GlobalKey<NavigatorState>> _navigatorKeys =
      List<GlobalKey<NavigatorState>>.generate(4, (_) => GlobalKey<NavigatorState>());

  int _index = 0;

  void _selectTab(int newIndex) {
    if (newIndex == _index) {
      _navigatorKeys[newIndex].currentState?.popUntil((Route<dynamic> r) => r.isFirst);
      return;
    }
    setState(() => _index = newIndex);
  }

  Widget _buildTabNavigator({
    required GlobalKey<NavigatorState> navigatorKey,
    required String initialRoute,
    required Widget root,
  }) {
    return Navigator(
      key: navigatorKey,
      initialRoute: initialRoute,
      onGenerateRoute: (RouteSettings settings) {
        // Each tab can grow its own stack; app-wide routes are handled by MaterialApp.onGenerateRoute.
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => root,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations t = AppLocalizations.of(context);

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeOutCubic,
        transitionBuilder: (Widget child, Animation<double> animation) {
          final bool reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

          final Animation<double> fade = CurvedAnimation(
            parent: animation,
            curve: const Interval(0.12, 1.0, curve: Curves.easeOutCubic),
          );

          Widget w = FadeTransition(opacity: fade, child: child);

          if (!reduce) {
            w = ScaleTransition(
              scale: Tween<double>(begin: 1.01, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
              child: w,
            );
          }
          return w;
        },
        child: KeyedSubtree(
          key: ValueKey<int>(_index),
          child: IndexedStack(
            index: _index,
            children: <Widget>[
              _buildTabNavigator(
                navigatorKey: _navigatorKeys[0],
                initialRoute: AppRoutes.home,
                root: const HomeRootScreen(),
              ),
              _buildTabNavigator(
                navigatorKey: _navigatorKeys[1],
                initialRoute: AppRoutes.search,
                root: const SearchRootScreen(),
              ),
              _buildTabNavigator(
                navigatorKey: _navigatorKeys[2],
                initialRoute: AppRoutes.downloads,
                root: const DownloadsRootScreen(),
              ),
              _buildTabNavigator(
                navigatorKey: _navigatorKeys[3],
                initialRoute: AppRoutes.profile,
                root: const ProfileRootScreen(),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _selectTab,
        destinations: <NavigationDestination>[
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: t.home,
          ),
          NavigationDestination(
            icon: const Icon(Icons.search_outlined),
            selectedIcon: const Icon(Icons.search),
            label: t.search,
          ),
          NavigationDestination(
            icon: const Icon(Icons.download_outlined),
            selectedIcon: const Icon(Icons.download),
            label: t.downloads,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: t.profile,
          ),
        ],
      ),
    );
  }
}
