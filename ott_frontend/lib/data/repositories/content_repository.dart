import 'package:ott_frontend/data/models/content_models.dart';

abstract class ContentRepository {
  // PUBLIC_INTERFACE
  Future<HomeFeedPayload> fetchHomeFeed();

  // PUBLIC_INTERFACE
  Future<List<ContentItem>> search(String query);

  // PUBLIC_INTERFACE
  Future<ContentItem?> getById(String id);
}
