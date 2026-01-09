class ContentItem {
  ContentItem({
    required this.id,
    required this.title,
    required this.posterUrl,
    required this.description,
    required this.durationSeconds,
    required this.genres,
  });

  final String id;
  final String title;
  final String posterUrl;
  final String description;
  final int durationSeconds;
  final List<String> genres;

  factory ContentItem.fromJson(Map<String, dynamic> json) {
    return ContentItem(
      id: (json['id'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      posterUrl: (json['posterUrl'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      durationSeconds: (json['durationSeconds'] as int?) ?? 0,
      genres: ((json['genres'] as List<dynamic>?) ?? const <dynamic>[]).cast<String>(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'posterUrl': posterUrl,
        'description': description,
        'durationSeconds': durationSeconds,
        'genres': genres,
      };
}

class ContentRail {
  ContentRail({required this.id, required this.title, required this.items});

  final String id;
  final String title;
  final List<ContentItem> items;

  factory ContentRail.fromJson(Map<String, dynamic> json) {
    return ContentRail(
      id: (json['id'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      items: ((json['items'] as List<dynamic>?) ?? const <dynamic>[])
          .map((dynamic e) => ContentItem.fromJson((e as Map<String, dynamic>)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'items': items.map((ContentItem e) => e.toJson()).toList(),
      };
}

class HomeFeedPayload {
  HomeFeedPayload({required this.rails});

  final List<ContentRail> rails;

  factory HomeFeedPayload.fromJson(Map<String, dynamic> json) {
    return HomeFeedPayload(
      rails: ((json['rails'] as List<dynamic>?) ?? const <dynamic>[])
          .map((dynamic e) => ContentRail.fromJson((e as Map<String, dynamic>)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'rails': rails.map((ContentRail e) => e.toJson()).toList(),
      };
}
