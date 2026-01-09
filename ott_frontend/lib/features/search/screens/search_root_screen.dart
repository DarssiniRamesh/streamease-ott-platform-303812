import 'package:flutter/material.dart';
import 'package:ott_frontend/core/i18n/app_localizations.dart';
import 'package:ott_frontend/core/routing/app_routes.dart';
import 'package:ott_frontend/core/routing/app_router.dart';
import 'package:ott_frontend/data/models/content_models.dart';
import 'package:ott_frontend/features/search/controllers/search_controller.dart';
import 'package:ott_frontend/widgets/content_list_tile.dart';
import 'package:provider/provider.dart';

class SearchRootScreen extends StatelessWidget {
  const SearchRootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations t = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(t.search)),
      body: SafeArea(
        child: Consumer<AppSearchController>(
          builder: (BuildContext context, AppSearchController c, _) {
            final String q = c.query.trim();

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: <Widget>[
                TextField(
                  onChanged: c.setQuery,
                  onSubmitted: (_) {
                    // Keyboard submit (search action).
                    c.submit();
                  },
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search titles, genres...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: q.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear',
                            onPressed: () => c.setQuery(''),
                            icon: const Icon(Icons.close),
                          ),
                  ),
                ),
                const SizedBox(height: 12),

                // SWR visual cue: when a query is active, show a thin progress bar while
                // the repository may refresh in background.
                if (c.loading) const LinearProgressIndicator(minHeight: 3),

                if ((c.errorMessage?.isNotEmpty ?? false))
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Material(
                      color: Theme.of(context).colorScheme.error.withAlpha(12),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(c.errorMessage!),
                      ),
                    ),
                  ),

                if (!c.loading && q.isEmpty) ...<Widget>[
                  if (c.recent.isNotEmpty) ...<Widget>[
                    Row(
                      children: <Widget>[
                        Text(
                          'Recent',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        TextButton(onPressed: c.clearRecent, child: const Text('Clear')),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: c.recent
                          .map(
                            (String rq) => ActionChip(
                              label: Text(rq),
                              onPressed: () {
                                // Submit from recent should not duplicate; controller de-dupes.
                                c.setQuery(rq);
                                c.submit();
                              },
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                  ] else
                    const Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: _SearchEmptyHint(),
                    ),
                ],

                if (!c.loading && q.isNotEmpty && c.results.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Text('No results found.'),
                  ),

                for (final ContentItem item in c.results)
                  ContentListTile(
                    title: item.title,
                    subtitle: item.description,
                    onTap: () {
                      Navigator.of(context).pushNamed(
                        AppRoutes.contentDetails,
                        arguments: ContentDetailsArgs(contentId: item.id),
                      );
                    },
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SearchEmptyHint extends StatelessWidget {
  const _SearchEmptyHint();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Search for a title to see results.\nRecent searches will appear here.',
      style: Theme.of(context).textTheme.bodyMedium,
      textAlign: TextAlign.center,
    );
  }
}
