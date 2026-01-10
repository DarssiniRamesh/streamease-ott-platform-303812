import 'package:flutter/material.dart';
import 'package:ott_frontend/core/i18n/app_localizations.dart';
import 'package:ott_frontend/core/routing/app_routes.dart';
import 'package:ott_frontend/core/routing/app_router.dart';
import 'package:ott_frontend/core/services/app_bootstrap.dart';
import 'package:ott_frontend/core/services/test_config.dart';
import 'package:ott_frontend/features/content/controllers/content_details_controller.dart';
import 'package:ott_frontend/features/content/widgets/details_reveal.dart';
import 'package:ott_frontend/features/downloads/controllers/download_controller.dart';
import 'package:ott_frontend/features/home/controllers/home_controller.dart';
import 'package:ott_frontend/widgets/animated_banner.dart';
import 'package:provider/provider.dart';

class ContentDetailsScreen extends StatelessWidget {
  const ContentDetailsScreen({super.key, required this.contentId});

  final String contentId;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations t = AppLocalizations.of(context);

    // Pull deps synchronously; avoid context usage after async gaps elsewhere.
    final AppDependencies deps = context.read<AppDependencies>();

    return ChangeNotifierProvider<ContentDetailsController>(
      create: (_) {
        final ContentDetailsController c = ContentDetailsController(
          repository: deps.contentRepository,
          cache: deps.simpleCache,
          db: deps.appDatabase,
          contentId: contentId,
        );

        // In widget tests, we disable auto-start to prevent background work
        // (SWR refreshes, cache-buster driven reloads) from scheduling frames.
        if (!TestConfig.disableAutoStart) {
          c.load();
        }

        return c;
      },
      child: Consumer<ContentDetailsController>(
        builder: (BuildContext context, ContentDetailsController c, _) {
          final bool isReady = c.state == ContentDetailsState.ready && c.item != null;

          final String downloadLabel = !isReady
              ? t.enqueueDownload
              : (c.hasDownload
                  ? (c.downloadStatus == 'completed' ? 'Downloaded' : 'In Downloads')
                  : t.enqueueDownload);

          final String title = c.item?.title ?? 'Content';
          final String heroTag = 'content-poster-$contentId';

          return Scaffold(
            appBar: AppBar(title: Text(title)),
            body: SafeArea(
              child: switch (c.state) {
                ContentDetailsState.loading => const Center(child: CircularProgressIndicator()),
                ContentDetailsState.error => Center(child: Text(c.errorMessage ?? 'Failed to load content.')),
                ContentDetailsState.notFound => const Center(child: Text('Not found.')),
                ContentDetailsState.ready => ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: <Widget>[
                      if (c.refreshing) const LinearProgressIndicator(minHeight: 3),
                      AnimatedBanner(
                        visible: (c.errorMessage?.isNotEmpty ?? false) && c.item != null,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12, top: 12),
                          child: Material(
                            color: Theme.of(context).colorScheme.secondary.withAlpha(25),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(c.errorMessage ?? ''),
                            ),
                          ),
                        ),
                      ),
                      DetailsReveal(
                        order: 0,
                        child: _PosterPlaceholder(title: c.item!.title, heroTag: heroTag),
                      ),
                      const SizedBox(height: 12),
                      DetailsReveal(
                        order: 1,
                        child: Text(
                          c.item!.title,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(height: 8),
                      DetailsReveal(order: 2, child: Text(c.item!.description)),
                      if ((c.lastWatchedSeconds ?? 0) > 0) ...<Widget>[
                        const SizedBox(height: 10),
                        DetailsReveal(order: 3, child: _LastWatchedPill(seconds: c.lastWatchedSeconds!)),
                      ],
                      const SizedBox(height: 12),
                      DetailsReveal(
                        order: 4,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: c.item!.genres.map((String g) => Chip(label: Text(g))).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Primary actions row
                      DetailsReveal(
                        order: 5,
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () {
                                  // Navigate to a dedicated Player screen to complete the playback flow.
                                  // Also do a best-effort progress write-through (sync kick-off only)
                                  // to keep Continue Watching durable.
                                  final HomeController home = context.read<HomeController>();

                                  () async {
                                    await c.playPressed(); // write-through to repository/DB
                                    await home.onPlaybackProgressPersisted();
                                  }();

                                  Navigator.of(context).pushNamed(
                                    AppRoutes.player,
                                    arguments: PlayerArgs(
                                      contentId: c.item!.id,
                                      startPositionSeconds: c.lastWatchedSeconds,
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.play_arrow),
                                label: Text((c.lastWatchedSeconds ?? 0) > 0 ? 'Resume' : 'Play'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: !isReady
                                    ? null
                                    : (c.hasDownload
                                        ? () {
                                            // Navigate user to Downloads tab (shell); keep it simple with hint.
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Open the Downloads tab to manage.')),
                                            );
                                          }
                                        : () {
                                            context.read<DownloadController>().enqueue(
                                                  contentId: c.item!.id,
                                                  title: c.item!.title,
                                                );

                                            // Update local state immediately for UI reflect.
                                            c.markDownloadEnqueuedLocally();

                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Added to downloads.')),
                                            );
                                          }),
                                icon: Icon(c.hasDownload ? Icons.download_done : Icons.download),
                                label: Text(downloadLabel),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Secondary actions
                      DetailsReveal(
                        order: 6,
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: c.toggleWatchlist,
                                icon: Icon(c.inWatchlist ? Icons.check : Icons.add),
                                label: Text(c.inWatchlist ? 'In Watchlist' : 'Add to Watchlist'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              },
            ),
          );
        },
      ),
    );
  }
}

class _LastWatchedPill extends StatelessWidget {
  const _LastWatchedPill({required this.seconds});

  final int seconds;

  @override
  Widget build(BuildContext context) {
    final String text = 'Last watched at ${_format(seconds)}';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withAlpha(10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withAlpha(18)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.play_circle_outline, size: 18, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(text, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  static String _format(int seconds) {
    final int m = seconds ~/ 60;
    final int s = seconds % 60;
    if (m <= 0) return '${s}s';
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }
}

class _PosterPlaceholder extends StatelessWidget {
  const _PosterPlaceholder({required this.title, required this.heroTag});

  final String title;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: heroTag,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: <Color>[
                Theme.of(context).colorScheme.primary.withAlpha(35),
                Theme.of(context).colorScheme.surface,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ),
    );
  }
}
