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
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: <Widget>[
                TextField(
                  onChanged: c.setQuery,
                  onSubmitted: (_) {
                    c.submit();
                  },
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search titles, genres...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: c.query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear',
                            onPressed: () => c.setQuery(''),
                            icon: const Icon(Icons.close),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                if (c.loading) const LinearProgressIndicator(minHeight: 3),
                if (!c.loading && c.query.trim().isEmpty && c.recent.isNotEmpty) ...<Widget>[
                  Row(
                    children: <Widget>[
                      Text('Recent', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      const Spacer(),
                      TextButton(onPressed: c.clearRecent, child: const Text('Clear')),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: c.recent
                        .map(
                          (String q) => ActionChip(
                            label: Text(q),
                            onPressed: () {
                              c.setQuery(q);
                              c.submit();
                            },
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                ],
                if (!c.loading && c.query.trim().isNotEmpty && c.results.isEmpty)
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
