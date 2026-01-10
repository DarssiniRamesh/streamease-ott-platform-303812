import 'package:flutter/material.dart';
import 'package:ott_frontend/core/i18n/app_localizations.dart';
import 'package:ott_frontend/core/routing/app_routes.dart';
import 'package:ott_frontend/core/routing/app_router.dart';

import 'package:ott_frontend/features/search/controllers/search_controller.dart';
import 'package:ott_frontend/widgets/content_list_tile.dart';
import 'package:ott_frontend/widgets/reveal_on_build.dart';
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

            final bool showEmptyResults = !c.loading && q.isNotEmpty && c.results.isEmpty;

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

                // Explicit user submit loading.
                if (c.loading) const LinearProgressIndicator(minHeight: 3),

                // Background SWR refresh: keep subtle.
                if (!c.loading && c.refreshing) ...<Widget>[
                  Row(
                    children: <Widget>[
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Refreshing results…',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

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
                    const Divider(height: 24),
                  ] else
                    const Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: _SearchEmptyHint(),
                    ),
                ],

                if (showEmptyResults)
                  const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Text('No results found.'),
                  ),

                for (int i = 0; i < c.results.length; i++)
                  RevealOnBuild(
                    index: i,
                    child: ContentListTile(
                      title: c.results[i].title,
                      subtitle: c.results[i].description,
                      heroTag: 'content-poster-${c.results[i].id}',
                      onTap: () {
                        Navigator.of(context).pushNamed(
                          AppRoutes.contentDetails,
                          arguments: ContentDetailsArgs(contentId: c.results[i].id),
                        );
                      },
                    ),
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
