import 'dart:math';

import 'package:ott_frontend/data/models/content_models.dart';
import 'package:ott_frontend/data/repositories/content_repository.dart';

class FakeContentRepository implements ContentRepository {
  final Random _rng = Random(7);

  List<ContentItem> _library() {
    return <ContentItem>[
      ContentItem(
        id: 'm1',
        title: 'Blue Horizon',
        posterUrl: '',
        description: 'A documentary journey across the deep ocean trenches.',
        durationSeconds: 5400,
        genres: const <String>['Documentary', 'Nature'],
      ),
      ContentItem(
        id: 'm2',
        title: 'City Lights',
        posterUrl: '',
        description: 'A fast-paced thriller set in a neon metropolis.',
        durationSeconds: 6600,
        genres: const <String>['Thriller', 'Action'],
      ),
      ContentItem(
        id: 'm3',
        title: 'Amber Sunrise',
        posterUrl: '',
        description: 'A heartfelt drama about family and second chances.',
        durationSeconds: 6000,
        genres: const <String>['Drama'],
      ),
      ContentItem(
        id: 's1e1',
        title: 'Orbiters S1 • Ep 1',
        posterUrl: '',
        description: 'A crew begins a risky mission beyond the moon.',
        durationSeconds: 2700,
        genres: const <String>['Sci‑Fi', 'Series'],
      ),
      ContentItem(
        id: 's1e2',
        title: 'Orbiters S1 • Ep 2',
        posterUrl: '',
        description: 'An unexpected malfunction tests the team.',
        durationSeconds: 2750,
        genres: const <String>['Sci‑Fi', 'Series'],
      ),
      ContentItem(
        id: 'm4',
        title: 'Coastline',
        posterUrl: '',
        description: 'A calming collection of coastal vistas.',
        durationSeconds: 3600,
        genres: const <String>['Relax', 'Nature'],
      ),
    ];
  }

  @override
  Future<HomeFeedPayload> fetchHomeFeed() async {
    await Future<void>.delayed(const Duration(milliseconds: 650));

    final List<ContentItem> lib = _library();
    // shuffle without mutating original
    final List<ContentItem> shuffled = List<ContentItem>.of(lib)..shuffle(_rng);

    return HomeFeedPayload(
      rails: <ContentRail>[
        ContentRail(id: 'rail_continue', title: 'Continue watching', items: shuffled.take(4).toList()),
        ContentRail(id: 'rail_trending', title: 'Trending now', items: (List<ContentItem>.of(lib)..shuffle(_rng)).take(6).toList()),
        ContentRail(id: 'rail_recommended', title: 'Recommended for you', items: (List<ContentItem>.of(lib)..shuffle(_rng)).take(5).toList()),
      ],
    );
  }

  @override
  Future<List<ContentItem>> search(String query) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (query.trim().isEmpty) return <ContentItem>[];

    final String q = query.toLowerCase();
    return _library()
        .where((ContentItem i) => i.title.toLowerCase().contains(q) || i.description.toLowerCase().contains(q))
        .toList();
  }

  @override
  Future<ContentItem?> getById(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    try {
      return _library().firstWhere((ContentItem e) => e.id == id);
    } catch (_) {
      return null;
    }
  }
}
