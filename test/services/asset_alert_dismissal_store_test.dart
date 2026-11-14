import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_alert_dismissal_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const store = AssetAlertDismissalStore();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('load returns empty set when nothing stored', () async {
    final prefs = await SharedPreferences.getInstance();
    expect(await store.load(prefs: prefs), isEmpty);
  });

  test('dismiss persists and load returns the id', () async {
    final prefs = await SharedPreferences.getInstance();
    final next = await store.dismiss('overdue:acc:2026-05-15', prefs: prefs);
    expect(next, contains('overdue:acc:2026-05-15'));
    expect(await store.load(prefs: prefs), contains('overdue:acc:2026-05-15'));
  });

  test('dismiss is idempotent and ignores blank ids', () async {
    final prefs = await SharedPreferences.getInstance();
    await store.dismiss('a', prefs: prefs);
    final again = await store.dismiss('a', prefs: prefs);
    expect(again, {'a'});
    final blank = await store.dismiss('   ', prefs: prefs);
    expect(blank, {'a'});
  });

  test('restore removes a dismissed id', () async {
    final prefs = await SharedPreferences.getInstance();
    await store.dismiss('a', prefs: prefs);
    await store.dismiss('b', prefs: prefs);
    final next = await store.restore('a', prefs: prefs);
    expect(next, {'b'});
  });

  test('prune keeps only live ids', () async {
    final prefs = await SharedPreferences.getInstance();
    await store.dismiss('a', prefs: prefs);
    await store.dismiss('b', prefs: prefs);
    await store.dismiss('c', prefs: prefs);
    final next = await store.prune({'b', 'c', 'x'}, prefs: prefs);
    expect(next, {'b', 'c'});
    expect(await store.load(prefs: prefs), {'b', 'c'});
  });

  final operations = <String, Future<Object?> Function(SharedPreferences)>{
    'dismiss': (prefs) => store.dismiss('new', prefs: prefs),
    'restore': (prefs) => store.restore('old', prefs: prefs),
    'prune': (prefs) => store.prune(<String>{'keep'}, prefs: prefs),
    'restoreAll': (prefs) async {
      await store.restoreAll(prefs: prefs);
      return null;
    },
  };
  for (final entry in operations.entries) {
    test('alert ${entry.key} rejects an unconfirmed write without retry',
        () async {
      final prefs = _AlertPreferences()..reject = true;
      await expectLater(entry.value(prefs), throwsA(isA<StateError>()));
      expect(prefs.attempts, 1);
      expect(prefs.lastKey, AssetAlertDismissalStore.prefsKey);
      // The fake mutates its cache before rejecting, like SharedPreferences.
      // Failure does not imply rollback or a known persisted state.
    });
    test('alert ${entry.key} preserves the original storage exception',
        () async {
      final failure = StateError('synthetic storage failure');
      final prefs = _AlertPreferences()..failure = failure;
      await expectLater(entry.value(prefs), throwsA(same(failure)));
      expect(prefs.attempts, 1);
    });
    test('alert ${entry.key} accepts a confirmed write', () async {
      final prefs = _AlertPreferences();
      final result = await entry.value(prefs);
      expect(prefs.attempts, 1);
      switch (entry.key) {
        case 'dismiss':
          expect(result, <String>{'old', 'keep', 'new'});
          expect(prefs.ids, <String>['old', 'keep', 'new']);
        case 'restore':
          expect(result, <String>{'keep'});
          expect(prefs.ids, <String>['keep']);
        case 'prune':
          expect(result, <String>{'keep'});
          expect(prefs.ids, <String>['keep']);
        case 'restoreAll':
          expect(prefs.ids, isNull);
      }
    });
  }
  test('alert no-op operations do not attempt a rejected write', () async {
    final prefs = _AlertPreferences()..reject = true;
    expect(await store.dismiss('old', prefs: prefs), <String>{'old', 'keep'});
    expect(await store.dismiss(' ', prefs: prefs), <String>{'old', 'keep'});
    expect(
        await store.restore('absent', prefs: prefs), <String>{'old', 'keep'});
    expect(await store.prune(<String>{'old', 'keep'}, prefs: prefs),
        <String>{'old', 'keep'});
    expect(prefs.attempts, 0);
  });
}

class _AlertPreferences extends Fake implements SharedPreferences {
  List<String>? ids = <String>['old', 'keep'];
  bool reject = false;
  Object? failure;
  int attempts = 0;
  String? lastKey;

  @override
  List<String>? getStringList(String key) =>
      ids == null ? null : List<String>.from(ids!);

  @override
  Future<bool> setStringList(String key, List<String> value) async {
    attempts++;
    lastKey = key;
    ids = List<String>.from(value);
    if (failure != null) throw failure!;
    return !reject;
  }

  @override
  Future<bool> remove(String key) async {
    attempts++;
    lastKey = key;
    ids = null;
    if (failure != null) throw failure!;
    return !reject;
  }
}
