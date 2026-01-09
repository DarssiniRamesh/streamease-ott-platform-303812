import 'package:flutter/material.dart';
import 'package:ott_frontend/core/i18n/app_localizations.dart';
import 'package:ott_frontend/core/routing/app_routes.dart';
import 'package:ott_frontend/core/routing/app_router.dart';
import 'package:ott_frontend/data/models/content_models.dart';
import 'package:ott_frontend/features/home/controllers/home_controller.dart';
import 'package:ott_frontend/features/home/controllers/home_view_models.dart';
import 'package:ott_frontend/widgets/content_card.dart';
import 'package:ott_frontend/widgets/rail_skeleton.dart';
import 'package:provider/provider.dart';

class HomeRootScreen extends StatelessWidget {
  const HomeRootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations t = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.home),
        actions: <Widget>[
          IconButton(
            tooltip: t.search,
            // AppShell owns the Search tab; `/search` isn't a global route in AppRouter.
            // Using bottom-nav selection avoids a missing-route error.
            onPressed: () {
              DefaultTabController.maybeOf(context)?.animateTo(1);
              // If no TabController exists (our shell uses NavigationBar), use ScaffoldMessenger hint.
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Use the Search tab below.')),
              );
            },
            icon: const Icon(Icons.search),
          ),
        ],
      ),
      body: SafeArea(
        child: Consumer<HomeController>(
          builder: (BuildContext context, HomeController c, _) {
            if (c.state == HomeLoadState.loading) {
              return const _HomeLoading();
            }
            if (c.state == HomeLoadState.error) {
              return _HomeError(message: c.errorMessage ?? 'Error', onRetry: c.loadHomeFeed);
            }

            final HomeFeedPayload? payload = c.payload;
            final List<ContentRail> rails = payload?.rails ?? const <ContentRail>[];
            if (rails.isEmpty) {
              return _HomeEmpty(onRetry: c.loadHomeFeed);
            }

            // Continue watching is driven by watch_history; show a placeholder if empty.
            final List<ContinueWatchingItem> cw = c.continueWatching;

            return RefreshIndicator(
              onRefresh: c.loadHomeFeed,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: <Widget>[
                  if (c.refreshing) const LinearProgressIndicator(minHeight: 3),
                  if ((c.errorMessage?.isNotEmpty ?? false) && c.payload != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Material(
                        color: Theme.of(context).colorScheme.secondary.withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            c.errorMessage!,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ),
                    ),

                  // Continue Watching rail (watch-history based).
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            t.continueWatching,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (c.continueWatchingLoading)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 190,
                    child: cw.isEmpty
                        ? const _ContinueWatchingEmpty()
                        : ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemBuilder: (BuildContext context, int index) {
                              final ContinueWatchingItem item = cw[index];
                              return Semantics(
                                button: true,
                                label: item.content.title,
                                child: ContentCard(
                                  title: item.content.title,
                                  subtitle: 'Resume • ${_formatPosition(item.positionSeconds)}',
                                  onTap: () {
                                    Navigator.of(context).pushNamed(
                                      AppRoutes.contentDetails,
                                      arguments: ContentDetailsArgs(contentId: item.content.id),
                                    );
                                  },
                                ),
                              );
                            },
                            separatorBuilder: (_, __) => const SizedBox(width: 12),
                            itemCount: cw.length,
                          ),
                  ),

                  // Remote rails (cache-first via SWR).
                  for (final ContentRail rail in rails) ...<Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                      child: Text(
                        rail.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    SizedBox(
                      height: 190,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemBuilder: (BuildContext context, int index) {
                          final ContentItem item = rail.items[index];
                          return Semantics(
                            button: true,
                            label: item.title,
                            child: ContentCard(
                              title: item.title,
                              subtitle: item.genres.isEmpty ? null : item.genres.first,
                              onTap: () {
                                Navigator.of(context).pushNamed(
                                  AppRoutes.contentDetails,
                                  arguments: ContentDetailsArgs(contentId: item.id),
                                );
                              },
                            ),
                          );
                        },
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemCount: rail.items.length,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  static String _formatPosition(int seconds) {
    final int m = seconds ~/ 60;
    final int s = seconds % 60;
    if (m <= 0) return '${s}s';
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }
}

class _HomeLoading extends StatelessWidget {
  const _HomeLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: const <Widget>[
        RailSkeleton(),
        RailSkeleton(),
        RailSkeleton(),
      ],
    );
  }
}

class _HomeError extends StatelessWidget {
  const _HomeError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                // no await; avoid context across async gap
                onRetry();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeEmpty extends StatelessWidget {
  const _HomeEmpty({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text('Nothing to show yet.'),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                onRetry();
              },
              child: const Text('Reload'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContinueWatchingEmpty extends StatelessWidget {
  const _ContinueWatchingEmpty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).colorScheme.primary.withAlpha(10),
          border: Border.all(color: Theme.of(context).colorScheme.primary.withAlpha(18)),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Start watching something to see it here.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
