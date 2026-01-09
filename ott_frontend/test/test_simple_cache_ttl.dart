import 'package:flutter_test/flutter_test.dart';
import 'package:ott_frontend/core/services/simple_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SimpleCache TTL', () {
    test('getJsonIfFresh returns entry within TTL, then null after TTL', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final SimpleCache cache = SimpleCache(prefs: prefs);

      await cache.putJson('k1', <String, dynamic>{'a': 1});

      final CacheEntry? freshNow = cache.getJsonIfFresh(
        'k1',
        const Duration(milliseconds: 50),
      );
      expect(freshNow, isNotNull);
      expect(freshNow!.json, contains('"a":1'));

      await Future<void>.delayed(const Duration(milliseconds: 60));

      final CacheEntry? expired = cache.getJsonIfFresh(
        'k1',
        const Duration(milliseconds: 50),
      );
      expect(expired, isNull);

      // Stale read should still return the cached payload.
      final CacheEntry? stale = cache.getJsonEvenIfStale('k1');
      expect(stale, isNotNull);
      expect(stale!.json, contains('"a":1'));
    });

    test('remove deletes stored json and timestamp', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final SimpleCache cache = SimpleCache(prefs: prefs);

      await cache.putJson('k2', <String, dynamic>{'x': true});
      expect(cache.getJsonEvenIfStale('k2'), isNotNull);

      await cache.remove('k2');

      expect(cache.getJsonEvenIfStale('k2'), isNull);

      // Also validate that it stays removed even after some time passes.
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(cache.getJsonIfFresh('k2', const Duration(milliseconds: 50)), isNull);
    });
  });
}
