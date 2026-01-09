import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class CacheEntry {
  CacheEntry({required this.json, required this.savedAtMs});

  final String json;
  final int savedAtMs;
}

class SimpleCache {
  SimpleCache({required this.prefs});

  final SharedPreferences prefs;

  String _dataKey(String key) => 'cache:$key:data';
  String _tsKey(String key) => 'cache:$key:ts';

  // PUBLIC_INTERFACE
  Future<void> putJson(String key, Map<String, dynamic> value) async {
    final String encoded = jsonEncode(value);
    await prefs.setString(_dataKey(key), encoded);
    await prefs.setInt(_tsKey(key), DateTime.now().millisecondsSinceEpoch);
  }

  // PUBLIC_INTERFACE
  CacheEntry? getJsonIfFresh(String key, Duration ttl) {
    final String? json = prefs.getString(_dataKey(key));
    final int? ts = prefs.getInt(_tsKey(key));
    if (json == null || ts == null) return null;

    final int ageMs = DateTime.now().millisecondsSinceEpoch - ts;
    if (ageMs > ttl.inMilliseconds) return null;
    return CacheEntry(json: json, savedAtMs: ts);
  }

  // PUBLIC_INTERFACE
  CacheEntry? getJsonEvenIfStale(String key) {
    final String? json = prefs.getString(_dataKey(key));
    final int? ts = prefs.getInt(_tsKey(key));
    if (json == null || ts == null) return null;
    return CacheEntry(json: json, savedAtMs: ts);
  }

  // PUBLIC_INTERFACE
  Future<void> remove(String key) async {
    await prefs.remove(_dataKey(key));
    await prefs.remove(_tsKey(key));
  }

  // PUBLIC_INTERFACE
  Future<void> setStringList(String key, List<String> values) async {
    await prefs.setStringList(key, values);
  }

  // PUBLIC_INTERFACE
  List<String> getStringList(String key) => prefs.getStringList(key) ?? <String>[];
}
