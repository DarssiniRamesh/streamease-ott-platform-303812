import 'package:flutter/foundation.dart';
import 'package:ott_frontend/core/services/simple_cache.dart';

enum StreamingQuality { auto, low, medium, high }

class SettingsController extends ChangeNotifier {
  SettingsController({required this.cache});

  final SimpleCache cache;

  static const String _qualityKey = 'settings:quality';
  static const String _subsKey = 'settings:subtitles_default';

  bool _loading = true;
  bool get loading => _loading;

  StreamingQuality _quality = StreamingQuality.auto;
  bool _subtitlesDefault = true;

  StreamingQuality get quality => _quality;
  bool get subtitlesDefault => _subtitlesDefault;

  // PUBLIC_INTERFACE
  Future<void> load() async {
    _loading = true;
    notifyListeners();

    final List<String> rawQuality = cache.getStringList(_qualityKey);
    final String q = rawQuality.isEmpty ? 'auto' : rawQuality.first;
    _quality = StreamingQuality.values.firstWhere(
      (StreamingQuality e) => e.name == q,
      orElse: () => StreamingQuality.auto,
    );

    final List<String> subs = cache.getStringList(_subsKey);
    _subtitlesDefault = subs.isNotEmpty ? subs.first == '1' : true;

    _loading = false;
    notifyListeners();
  }

  // PUBLIC_INTERFACE
  Future<void> setQuality(StreamingQuality q) async {
    _quality = q;
    notifyListeners();

    await cache.setStringList(_qualityKey, <String>[q.name]);
  }

  // PUBLIC_INTERFACE
  Future<void> setSubtitlesDefault(bool enabled) async {
    _subtitlesDefault = enabled;
    notifyListeners();

    await cache.setStringList(_subsKey, <String>[enabled ? '1' : '0']);
  }
}
