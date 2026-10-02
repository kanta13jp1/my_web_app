import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_developer_issue_lookup_cache.dart';

Map<String, String> request(String key, {String description = 'description'}) =>
    {
      'key': key,
      'title': 'Title $key',
      'description': description,
    };

Map<String, dynamic> issue(String key) => {'key': key, 'number': key};

void main() {
  group('Shared developer issue lookups', () {
    test('shared failures release all pending entries for one retry', () async {
      final cache = AssetDeveloperIssueLookupCache();
      final response = Completer<Map<String, Map<String, dynamic>>>();
      var calls = 0;
      Future<Map<String, Map<String, dynamic>>> load(
        List<Map<String, String>> requests,
      ) {
        calls++;
        return response.future;
      }

      final first = cache.lookup(
          scopeKey: 'user', requests: [request('a'), request('b')], load: load,
      );
      final second =
          cache.lookup(scopeKey: 'user', requests: [request('b')], load: load,
      );
      final checks = Future.wait([
        expectLater(first, throwsStateError),
        expectLater(second, throwsStateError),
      ]);
      response.completeError(StateError('Unavailable'));
      await checks;
      expect(calls, 1);
      expect(
          await cache.lookup(
              scopeKey: 'user',
              requests: [request('b')],
              load: (_) async => {'b': issue('b')},
          ),
          {'b': issue('b')},
      );
    });

    test('same-account invalidation rejects in-flight result', () async {
      final cache = AssetDeveloperIssueLookupCache();
      final response = Completer<Map<String, Map<String, dynamic>>>();
      final pending = cache.lookup(
          scopeKey: 'user',
          requests: [request('a')],
          load: (_) => response.future,
      );
      final checked = expectLater(pending, throwsStateError);
      final revision = cache.revision;
      cache.invalidate();
      expect(cache.revision, greaterThan(revision));
      expect(
          await cache.lookup(
              scopeKey: 'user',
              requests: [request('a')],
              load: (_) async => {'a': issue('new')},
          ),
          {'a': issue('new')},
      );
      response.complete({'a': issue('old')});
      await checked;
      expect(
          await cache.lookup(
              scopeKey: 'user',
              requests: [request('a')],
              load: (_) => throw StateError('No request expected'),
          ),
          {'a': issue('new')},
      );
    });

    test('deterministic, combined, deterministic fetch only new AI payload',
        () async {
      final cache = AssetDeveloperIssueLookupCache();
      final calls = <List<String>>[];
      Future<Map<String, Map<String, dynamic>>> load(
        List<Map<String, String>> requests,
      ) async {
        calls.add(requests.map((item) => item['key']!).toList());
        return {for (final item in requests) item['key']!: issue(item['key']!)};
      }

      final base = request('base');
      final ai = request('ai');
      expect(
        await cache.lookup(scopeKey: 'user', requests: [base], load: load),
        {'base': issue('base')},
      );
      expect(
        await cache.lookup(scopeKey: 'user', requests: [base, ai], load: load),
        {'base': issue('base'), 'ai': issue('ai')},
      );
      await cache.lookup(scopeKey: 'user', requests: [base], load: load,
      );
      await cache.lookup(scopeKey: 'user', requests: [ai, base], load: load,
      );
      expect(calls, [
        ['base'],
        ['ai'],
      ]);
    });

    test('overlapping calls share in-flight entries and await both batches',
        () async {
      final cache = AssetDeveloperIssueLookupCache();
      final completions = <Completer<Map<String, Map<String, dynamic>>>>[];
      final calls = <List<String>>[];
      Future<Map<String, Map<String, dynamic>>> load(
        List<Map<String, String>> requests,
      ) {
        calls.add(requests.map((item) => item['key']!).toList());
        final completion = Completer<Map<String, Map<String, dynamic>>>();
        completions.add(completion);
        return completion.future;
      }

      final first = cache.lookup(
        scopeKey: 'user',
        requests: [request('base')],
        load: load,
      );
      final combined = cache.lookup(
        scopeKey: 'user',
        requests: [request('base'), request('ai')],
        load: load,
      );
      final repeated = cache.lookup(
        scopeKey: 'user',
        requests: [request('base')],
        load: load,
      );
      expect(calls, [
        ['base'],
        ['ai'],
      ]);
      completions[1].complete({'ai': issue('ai')});
      completions[0].complete({'base': issue('base')});
      expect(await first, {'base': issue('base')});
      expect(await repeated, {'base': issue('base')});
      expect(await combined, {'base': issue('base'), 'ai': issue('ai')});
    });

    test('successful no-match entries are cached', () async {
      final cache = AssetDeveloperIssueLookupCache();
      var calls = 0;
      Future<Map<String, Map<String, dynamic>>> load(
        List<Map<String, String>> requests,
      ) async {
        calls++;
        return {};
      }

      for (var index = 0; index < 3; index++) {
        expect(
          await cache.lookup(
            scopeKey: 'user',
            requests: [request('base')],
            load: load,
          ),
          isEmpty,
        );
      }
      expect(calls, 1);
    });

    test('failed lookup is retryable and cannot become a no-match cache',
        () async {
      final cache = AssetDeveloperIssueLookupCache();
      var calls = 0;
      Future<Map<String, Map<String, dynamic>>> load(
        List<Map<String, String>> requests,
      ) async {
        if (calls++ == 0) throw StateError('Unavailable');
        return {'base': issue('base')};
      }

      await expectLater(
        cache.lookup(scopeKey: 'user', requests: [request('base')], load: load),
        throwsStateError,
      );
      expect(
        await cache.lookup(
          scopeKey: 'user',
          requests: [request('base')],
          load: load,
        ),
        {'base': issue('base')},
      );
      expect(calls, 2);
    });

    test('changed description is a different identity for the same title',
        () async {
      final cache = AssetDeveloperIssueLookupCache();
      final descriptions = <String>[];
      Future<Map<String, Map<String, dynamic>>> load(
        List<Map<String, String>> requests,
      ) async {
        descriptions.add(requests.single['description']!);
        return {};
      }

      await cache.lookup(
        scopeKey: 'user',
        requests: [request('base')],
        load: load,
      );
      await cache.lookup(
        scopeKey: 'user',
        requests: [request('base', description: 'changed')],
        load: load,
      );
      expect(descriptions, ['description', 'changed']);
    });

    test('account switch rejects stale results and cannot seed new cache',
        () async {
      final cache = AssetDeveloperIssueLookupCache();
      final oldResponse = Completer<Map<String, Map<String, dynamic>>>();
      final oldLookup = cache.lookup(
        scopeKey: 'old-user',
        requests: [request('base')],
        load: (_) => oldResponse.future,
      );
      final rejected = expectLater(oldLookup, throwsStateError);
      var newCalls = 0;
      Future<Map<String, Map<String, dynamic>>> loadNew(
        List<Map<String, String>> requests,
      ) async {
        newCalls++;
        return {};
      }

      expect(
        await cache.lookup(
          scopeKey: 'new-user',
          requests: [request('base')],
          load: loadNew,
        ),
        isEmpty,
      );
      oldResponse.complete({'base': issue('private-old')});
      await rejected;
      expect(
        await cache.lookup(
          scopeKey: 'new-user',
          requests: [request('base')],
          load: loadNew,
        ),
        isEmpty,
      );
      expect(newCalls, 1);
    });

    test('invalidation refreshes a prior no-match after issue creation',
        () async {
      final cache = AssetDeveloperIssueLookupCache();
      var created = false;
      Future<Map<String, Map<String, dynamic>>> load(
        List<Map<String, String>> requests,
      ) async =>
          created ? {'base': issue('base')} : {};

      expect(
        await cache.lookup(
          scopeKey: 'user',
          requests: [request('base')],
          load: load,
        ),
        isEmpty,
      );
      created = true;
      cache.invalidate();
      expect(
        await cache.lookup(
          scopeKey: 'user',
          requests: [request('base')],
          load: load,
        ),
        {'base': issue('base')},
      );
    });

    test('bounded cache preserves current results while evicting old entries',
        () async {
      final cache = AssetDeveloperIssueLookupCache(maxCachedEntries: 2);
      final calls = <List<String>>[];
      Future<Map<String, Map<String, dynamic>>> load(
        List<Map<String, String>> requests,
      ) async {
        calls.add(requests.map((item) => item['key']!).toList());
        return {for (final item in requests) item['key']!: issue(item['key']!)};
      }

      expect(
        await cache.lookup(
          scopeKey: 'user',
          requests: [request('a'), request('b'), request('c')],
          load: load,
        ),
        {'a': issue('a'), 'b': issue('b'), 'c': issue('c')},
      );
      await cache.lookup(
          scopeKey: 'user', requests: [request('b')], load: load,
      );
      await cache.lookup(
          scopeKey: 'user', requests: [request('a')], load: load,
      );
      expect(calls, [
        ['a', 'b', 'c'],
        ['a'],
      ]);
    });

    test('payloads and returned results cannot mutate the cache identity',
        () async {
      final cache = AssetDeveloperIssueLookupCache();
      final input = request('base');
      final response = Completer<Map<String, Map<String, dynamic>>>();
      List<Map<String, String>>? captured;
      final pending = cache.lookup(
        scopeKey: 'user',
        requests: [input],
        load: (requests) {
          captured = requests;
          return response.future;
        },
      );
      input['description'] = 'edited';
      expect(captured!.single['description'], 'description');
      expect(() => captured!.single['title'] = 'edit', throwsUnsupportedError);
      response.complete({'base': issue('base'), 'unrequested': issue('other')});
      final result = await pending;
      expect(result.keys, ['base']);
      result['base']!['number'] = 'mutated';
      expect(
        await cache.lookup(
          scopeKey: 'user',
          requests: [request('base')],
          load: (_) => throw StateError('No fetch expected'),
        ),
        {'base': issue('base')},
      );
    });

    test('duplicate payloads are fetched once and empty input never fetches',
        () async {
      final cache = AssetDeveloperIssueLookupCache();
      var calls = 0;
      Future<Map<String, Map<String, dynamic>>> load(
        List<Map<String, String>> requests,
      ) async {
        calls++;
        expect(requests, hasLength(1));
        return {};
      }

      await cache.lookup(scopeKey: 'user', requests: [], load: load,
      );
      await cache.lookup(
        scopeKey: 'user',
        requests: [request('base'), request('base')],
        load: load,
      );
      expect(calls, 1);
    });
  });
}
