import 'package:flutter/material.dart';
import 'package:ott_frontend/core/i18n/app_localizations.dart';
import 'package:ott_frontend/core/services/app_bootstrap.dart';
import 'package:ott_frontend/features/content/controllers/content_details_controller.dart';
import 'package:ott_frontend/features/downloads/controllers/download_controller.dart';
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
      create: (_) => ContentDetailsController(
        repository: deps.contentRepository,
        contentId: contentId,
      )..load(),
      child: Consumer<ContentDetailsController>(
        builder: (BuildContext context, ContentDetailsController c, _) {
          return Scaffold(
            appBar: AppBar(title: Text(c.item?.title ?? 'Content')),
            body: SafeArea(
              child: switch (c.state) {
                ContentDetailsState.loading => const Center(child: CircularProgressIndicator()),
                ContentDetailsState.error => Center(child: Text(c.errorMessage ?? 'Failed to load content.')),
                ContentDetailsState.notFound => const Center(child: Text('Not found.')),
                ContentDetailsState.ready => ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: <Widget>[
                      if ((c.errorMessage?.isNotEmpty ?? false) && c.item != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Material(
                            color: Theme.of(context).colorScheme.secondary.withAlpha(25),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(c.errorMessage!),
                            ),
                          ),
                        ),
                      _PosterPlaceholder(title: c.item!.title),
                      const SizedBox(height: 12),
                      Text(
                        c.item!.title,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(c.item!.description),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: c.item!.genres.map((String g) => Chip(label: Text(g))).toList(),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () {
                                // Playback seam (still not implemented) but we can
                                // write-through an initial watch position.
                                c.recordPlaybackProgressSeconds(30);

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Playback not implemented yet.')),
                                );
                              },
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Play'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                context.read<DownloadController>().enqueue(
                                      contentId: c.item!.id,
                                      title: c.item!.title,
                                    );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Added to downloads.')),
                                );
                              },
                              icon: const Icon(Icons.download),
                              label: Text(t.enqueueDownload),
                            ),
                          ),
                        ],
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

class _PosterPlaceholder extends StatelessWidget {
  const _PosterPlaceholder({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
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
    );
  }
}
