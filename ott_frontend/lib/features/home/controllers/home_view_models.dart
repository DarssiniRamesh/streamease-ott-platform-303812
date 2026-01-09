import 'package:ott_frontend/data/models/content_models.dart';

/// Lightweight UI model for a "Continue watching" card.
///
/// We keep this separate from DB/repository types so UI doesn't depend on
/// persistence layer shapes.
// PUBLIC_INTERFACE
class ContinueWatchingItem {
  /// PUBLIC_INTERFACE
  ContinueWatchingItem({
    required this.content,
    required this.positionSeconds,
  });

  final ContentItem content;
  final int positionSeconds;
}
