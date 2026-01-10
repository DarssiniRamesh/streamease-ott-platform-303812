import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:ott_frontend/core/i18n/app_localizations.dart';
import 'package:ott_frontend/core/routing/app_routes.dart';
import 'package:ott_frontend/core/routing/app_router.dart';
import 'package:ott_frontend/data/models/content_models.dart';
import 'package:ott_frontend/features/downloads/controllers/download_controller.dart';
import 'package:ott_frontend/features/downloads/services/download_engine.dart';
import 'package:ott_frontend/features/home/controllers/home_controller.dart';
import 'package:ott_frontend/features/home/controllers/home_view_models.dart';
import 'package:ott_frontend/widgets/content_card.dart';
import 'package:ott_frontend/widgets/rail_skeleton.dart';
import 'package:provider/provider.dart';

class HomeRootScreen extends StatefulWidget {
  const HomeRootScreen({super.key});

  @override
  State<HomeRootScreen> createState() => _HomeRootScreenState();
}

class _HomeRootScreenState extends State<HomeRootScreen> {
  // Keep stable ScrollControllers so ListViews don't reset/jank when SWR refreshes.
  final ScrollController _vertical = ScrollController();
  final ScrollController _continueWatching = ScrollController();

  final Map<String, ScrollController> _railControllers = <String, ScrollController>{};

  // Used for "user interaction idle" debounce. While scrolling, we defer refresh.
  Timer? _idleDebounce;

  @override
  void dispose() {
    _idleDebounce?.cancel();
    _idleDebounce = null;

    _vertical.dispose();
    _continueWatching.dispose();
    for (final ScrollController c in _railControllers.values) {
      c.dispose();
    }
    _railControllers.clear();

    super.dispose();
  }

  ScrollController _railControllerForId(String railId) {
    return _railControllers.putIfAbsent(railId, () => ScrollController());
  }

  void _setInteractingDebounced(HomeController controller, bool interacting) {
    // Keep controller updates synchronous (no awaits). We also debounce the "idle"
    // transition so a user who briefly pauses doesn't immediately trigger a refresh.
    if (interacting) {
      _idleDebounce?.cancel();
      _idleDebounce = null;
      controller.setUserInteracting(true);
      return;
    }

    _idleDebounce?.cancel();
    _idleDebounce = Timer(const Duration(milliseconds: 300), () {
      // No context usage here; controller is passed in.
      controller.setUserInteracting(false);
    });
  }

  // Deterministic ordering for "Continue Watching".
  //
  // We don't have updated_at on ContinueWatchingItem directly; we use positionSeconds
  // (which changes on progress writes) as a stable proxy. Tie-break by id to avoid
  // shuffle on equal positions.
  static List<ContinueWatchingItem> _sortedContinueWatching(List<ContinueWatchingItem> input) {
    final List<ContinueWatchingItem> items = List<ContinueWatchingItem>.of(input);
    items.sort((ContinueWatchingItem a, ContinueWatchingItem b) {
      final int byPosition = b.positionSeconds.compareTo(a.positionSeconds);
      if (byPosition != 0) return byPosition;
      return a.content.id.compareTo(b.content.id);
    });
    return items;
  }

  // Deterministic ordering for a rail's items. Prefer stable "rank-like" ordering if present;
  // since our model lacks rank, we use title+id (stable) to avoid shuffle across refreshes.
  static List<ContentItem> _sortedRailItems(List<ContentItem> input) {
    final List<ContentItem> items = List<ContentItem>.of(input);
    items.sort((ContentItem a, ContentItem b) {
      final int byTitle = a.title.toLowerCase().compareTo(b.title.toLowerCase());
      if (byTitle != 0) return byTitle;
      return a.id.compareTo(b.id);
    });
    return items;
  }

  // Deterministic ordering for rails themselves (by id, then title).
  static List<ContentRail> _sortedRails(List<ContentRail> input) {
    final List<ContentRail> rails = List<ContentRail>.of(input);
    rails.sort((ContentRail a, ContentRail b) {
      final int byId = a.id.compareTo(b.id);
      if (byId != 0) return byId;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return rails;
  }

  void _navigateToPlayerSync({
    required BuildContext context,
    required String contentId,
    int? startPositionSeconds,
  }) {
    Navigator.of(context).pushNamed(
      AppRoutes.player,
      arguments: PlayerArgs(contentId: contentId, startPositionSeconds: startPositionSeconds),
    );
  }

  void _enqueueDownloadSync({
    required DownloadController downloadController,
    required String contentId,
    required String title,
  }) {
    // Fire-and-forget; controller refreshes its own state.
    downloadController.enqueue(contentId: contentId, title: title);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations t = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.home),
        actions: <Widget>[
          IconButton(
            tooltip: t.search,
            // AppShell owns the Search tab; if TabController exists, switch.
            // Otherwise, show a gentle hint without attempting invalid navigation.
            onPressed: () {
              final TabController? tab = DefaultTabController.maybeOf(context);
              if (tab != null) {
                tab.animateTo(1);
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Use the Search tab below.')),
              );
            },
            icon: const Icon(Icons.search),
          ),
        ],
      ),
      body: SafeArea(
        child: Consumer2<HomeController, DownloadController>(
          builder: (BuildContext context, HomeController home, DownloadController downloads, _) {
            if (home.state == HomeLoadState.loading) {
              return const _HomeLoading();
            }
            if (home.state == HomeLoadState.error) {
              return _HomeError(message: home.errorMessage ?? 'Error', onRetry: home.loadHomeFeed);
            }

            final HomeFeedPayload? payload = home.payload;
            final List<ContentRail> railsRaw = payload?.rails ?? const <ContentRail>[];
            if (railsRaw.isEmpty) {
              return _HomeEmpty(onRetry: home.loadHomeFeed);
            }

            final List<ContentRail> rails = _sortedRails(railsRaw);

            // Continue watching is driven by watch_history; show a placeholder if empty.
            final List<ContinueWatchingItem> cw = _sortedContinueWatching(home.continueWatching);

            // While the user is actively scrolling, we suppress:
            // - pull-to-refresh (RefreshIndicator) to avoid gesture competition
            // - cache-buster driven refresh storms (in controller) via a scroll flag
            //
            // This prevents subtle vertical list "drift"/re-layout that users perceive as
            // the list moving on its own.
            return NotificationListener<UserScrollNotification>(
              onNotification: (UserScrollNotification n) {
                final bool scrolling = n.direction != ScrollDirection.idle;
                _setInteractingDebounced(home, scrolling);
                return false;
              },
              child: Builder(
                builder: (BuildContext context) {
                  final bool disableRefreshWhileScrolling = home.userInteracting;

                  final Widget list = ListView(
                    key: const PageStorageKey<String>('home-vertical-list'),
                    controller: _vertical,
                    padding: const EdgeInsets.only(bottom: 24),
                    children: <Widget>[
                      if (home.refreshing) const LinearProgressIndicator(minHeight: 3),
                      if ((home.errorMessage?.isNotEmpty ?? false) && home.payload != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: Material(
                            color: Theme.of(context).colorScheme.secondary.withAlpha(25),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                home.errorMessage!,
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
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                            if (home.continueWatchingLoading)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 208,
                        child: cw.isEmpty
                            ? const _ContinueWatchingEmpty()
                            : ListView.separated(
                                key: const PageStorageKey<String>('continue-watching-rail'),
                                controller: _continueWatching,
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemBuilder: (BuildContext context, int index) {
                                  final ContinueWatchingItem item = cw[index];
                                  final DownloadRecord? r = downloads.findByContentId(item.content.id);

                                  return Semantics(
                                    button: true,
                                    label: item.content.title,
                                    child: _RailCardWithActions(
                                      // Stable key across SWR refreshes:
                                      // only uses contentId (never index / title / transient props).
                                      key: ValueKey<String>('cw-${item.content.id}'),
                                      contentId: item.content.id,
                                      title: item.content.title,
                                      heroTag: 'content-poster-${item.content.id}',
                                      subtitle: 'Resume • ${_formatPosition(item.positionSeconds)}',
                                      downloadRecord: r,
                                      onPlay: () {
                                        _navigateToPlayerSync(
                                          context: context,
                                          contentId: item.content.id,
                                          startPositionSeconds: item.positionSeconds,
                                        );
                                      },
                                      onDownload: () {
                                        _enqueueDownloadSync(
                                          downloadController: downloads,
                                          contentId: item.content.id,
                                          title: item.content.title,
                                        );
                                      },
                                      // Keep tap-to-details as the main surface tap (preserves existing flow),
                                      // but still provide explicit Play button.
                                      onOpenDetails: () {
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
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        SizedBox(
                          height: 208,
                          child: _RailList(
                            rail: rail,
                            controller: _railControllerForId(rail.id),
                            items: _sortedRailItems(rail.items),
                            downloads: downloads,
                            onPlay: (ContentItem item) {
                              _navigateToPlayerSync(context: context, contentId: item.id);
                            },
                            onDownload: (ContentItem item) {
                              _enqueueDownloadSync(
                                downloadController: downloads,
                                contentId: item.id,
                                title: item.title,
                              );
                            },
                            onOpenDetails: (ContentItem item) {
                              Navigator.of(context).pushNamed(
                                AppRoutes.contentDetails,
                                arguments: ContentDetailsArgs(contentId: item.id),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  );

                  if (disableRefreshWhileScrolling) {
                    return list;
                  }

                  return RefreshIndicator(
                    onRefresh: home.loadHomeFeed,
                    child: list,
                  );
                },
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

class _RailList extends StatelessWidget {
  const _RailList({
    required this.rail,
    required this.controller,
    required this.items,
    required this.downloads,
    required this.onPlay,
    required this.onDownload,
    required this.onOpenDetails,
  });

  final ContentRail rail;
  final ScrollController controller;
  final List<ContentItem> items;
  final DownloadController downloads;

  final void Function(ContentItem item) onPlay;
  final void Function(ContentItem item) onDownload;
  final void Function(ContentItem item) onOpenDetails;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      key: PageStorageKey<String>('rail-${rail.id}'),
      controller: controller,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemBuilder: (BuildContext context, int index) {
        final ContentItem item = items[index];
        final DownloadRecord? r = downloads.findByContentId(item.id);

        return Semantics(
          button: true,
          label: item.title,
          child: _RailCardWithActions(
            // Stable key across SWR refreshes:
            // only uses rail.id and item.id (never index / title).
            key: ValueKey<String>('rail-${rail.id}-${item.id}'),
            contentId: item.id,
            title: item.title,
            heroTag: 'content-poster-${item.id}',
            subtitle: item.genres.isEmpty ? null : item.genres.first,
            downloadRecord: r,
            onPlay: () => onPlay(item),
            onDownload: () => onDownload(item),
            onOpenDetails: () => onOpenDetails(item),
          ),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemCount: items.length,
    );
  }
}

class _RailCardWithActions extends StatelessWidget {
  const _RailCardWithActions({
    super.key,
    required this.contentId,
    required this.title,
    required this.heroTag,
    required this.onPlay,
    required this.onDownload,
    required this.onOpenDetails,
    required this.downloadRecord,
    this.subtitle,
  });

  final String contentId;
  final String title;
  final String heroTag;
  final String? subtitle;

  final VoidCallback onPlay;
  final VoidCallback onDownload;
  final VoidCallback onOpenDetails;

  final DownloadRecord? downloadRecord;

  bool get _downloadIsCompleted => downloadRecord?.status == 'completed';
  bool get _downloadIsActive =>
      downloadRecord?.status == 'queued' || downloadRecord?.status == 'downloading';

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return SizedBox(
      width: 156,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: ContentCard(
              // Hero/reveal preserved (ContentCard includes Hero).
              title: title,
              heroTag: heroTag,
              subtitle: subtitle,
              onTap: onOpenDetails,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: SizedBox(
                  height: 34,
                  child: FilledButton.tonalIcon(
                    onPressed: onPlay,
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Play'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 34,
                width: 46,
                child: Tooltip(
                  message: _downloadIsCompleted
                      ? 'Downloaded'
                      : (_downloadIsActive ? 'In downloads' : 'Download'),
                  child: _DownloadButton(
                    contentId: contentId,
                    record: downloadRecord,
                    onPressed: _downloadIsCompleted ? null : onDownload,
                    activeColor: cs.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DownloadButton extends StatelessWidget {
  const _DownloadButton({
    required this.contentId,
    required this.record,
    required this.onPressed,
    required this.activeColor,
  });

  final String contentId;
  final DownloadRecord? record;
  final VoidCallback? onPressed;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    final String status = record?.status ?? 'none';
    final double progress = record?.progress ?? 0.0;

    // AnimatedSwitcher ensures smooth transitions without changing list layout/order.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: switch (status) {
        'completed' => IconButton.filledTonal(
            key: const ValueKey<String>('download-completed'),
            onPressed: null,
            icon: const Icon(Icons.download_done, size: 20),
          ),
        'queued' || 'downloading' => Stack(
            key: const ValueKey<String>('download-active'),
            alignment: Alignment.center,
            children: <Widget>[
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  value: progress <= 0 ? null : progress,
                  strokeWidth: 3,
                ),
              ),
              IconButton(
                onPressed: null,
                icon: Icon(Icons.downloading, size: 20, color: activeColor),
              ),
            ],
          ),
        _ => IconButton.outlined(
            key: const ValueKey<String>('download-idle'),
            onPressed: onPressed,
            icon: const Icon(Icons.download, size: 20),
          ),
      },
    );
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
