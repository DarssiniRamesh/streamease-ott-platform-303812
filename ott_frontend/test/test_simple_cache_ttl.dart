import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ott_frontend/core/services/simple_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SimpleCache TTL', () {
    test('getJsonIfFresh returns entry within TTL, then null after TTL', () {
      fakeAsync((FakeAsync async) {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        late SharedPreferences prefs;
        late SimpleCache cache;

        async.run((FakeAsync self) async {
          prefs = await SharedPreferences.getInstance();
          cache = SimpleCache(prefs: prefs);

          await cache.putJson('k1', <String, dynamic>{'a': 1});
        });

        final CacheEntry? freshNow = cache.getJsonIfFresh('k1', const Duration(seconds: 10));
        expect(freshNow, isNotNull);
        expect(freshNow!.json, contains('"a":1'));

        async.elapse(const Duration(seconds: 11));

        final CacheEntry? expired = cache.getJsonIfFresh('k1', const Duration(seconds: 10));
        expect(expired, isNull);

        final CacheEntry? stale = cache.getJsonEvenIfStale('k1');
        expect(stale, isNotNull);
        expect(stale!.json, contains('"a":1'));
      });
    });

    test('remove deletes stored json and timestamp', () {
      fakeAsync((FakeAsync async) {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        late SharedPreferences prefs;
        late SimpleCache cache;

        async.run((FakeAsync self) async {
          prefs = await SharedPreferences.getInstance();
          cache = SimpleCache(prefs: prefs);
          await cache.putJson('k2', <String, dynamic>{'x': true});
          await cache.remove('k2');
        });

        expect(cache.getJsonEvenIfStale('k2'), isNull);
      });
    });
  });
}
