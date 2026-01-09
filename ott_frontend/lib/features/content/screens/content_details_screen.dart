import 'package:flutter/material.dart';
import 'package:ott_frontend/core/i18n/app_localizations.dart';
import 'package:ott_frontend/core/services/app_bootstrap.dart';
import 'package:ott_frontend/data/models/content_models.dart';
import 'package:ott_frontend/data/repositories/content_repository.dart';
import 'package:ott_frontend/features/downloads/controllers/download_controller.dart';
import 'package:provider/provider.dart';

class ContentDetailsScreen extends StatefulWidget {
  const ContentDetailsScreen({super.key, required this.contentId});

  final String contentId;

  @override
  State<ContentDetailsScreen> createState() => _ContentDetailsScreenState();
}

class _ContentDetailsScreenState extends State<ContentDetailsScreen> {
  bool _loading = true;
  ContentItem? _item;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Avoid context usage after await: pull deps synchronously before awaiting.
    final AppDependencies deps = context.read<AppDependencies>();
    final ContentRepository repo = deps.contentRepository;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final ContentItem? item = await repo.getById(widget.contentId);
      setState(() {
        _item = item;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Failed to load content.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations t = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(_item?.title ?? 'Content')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : (_error != null)
                ? Center(child: Text(_error!))
                : _item == null
                    ? const Center(child: Text('Not found.'))
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        children: <Widget>[
                          _PosterPlaceholder(title: _item!.title),
                          const SizedBox(height: 12),
                          Text(
                            _item!.title,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          Text(_item!.description),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _item!.genres.map((String g) => Chip(label: Text(g))).toList(),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () {
                                    // Playback seam (not implemented yet).
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
                                          contentId: _item!.id,
                                          title: _item!.title,
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
