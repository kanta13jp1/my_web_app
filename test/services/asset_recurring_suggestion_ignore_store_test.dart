import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_recurring_suggestion_ignore_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const store = AssetRecurringSuggestionIgnoreStore();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('save then load round-trips the set', () async {
    final prefs = await SharedPreferences.getInstance();
    await store.save(<String>{'電気代', 'netflix'}, prefs: prefs);
    expect(await store.load(prefs: prefs), <String>{'電気代', 'netflix'});
  });

  test('saving an empty set clears the key', () async {
    final prefs = await SharedPreferences.getInstance();
    await store.save(<String>{'x'}, prefs: prefs);
    await store.save(<String>{}, prefs: prefs);
    expect(await store.load(prefs: prefs), isEmpty);
  });

  test('distinct prefsKey isolates expense and income ignore sets', () async {
    final prefs = await SharedPreferences.getInstance();
    const incomeStore = AssetRecurringSuggestionIgnoreStore(
      prefsKey: 'asset_recurring_income_ignored_v1',
    );

    await store.save(<String>{'電気代'}, prefs: prefs);
    await incomeStore.save(<String>{'給料'}, prefs: prefs);

    expect(await store.load(prefs: prefs), <String>{'電気代'});
    expect(await incomeStore.load(prefs: prefs), <String>{'給料'});
  });

  test('rejected write is reported without claiming persistence', () async {
    final prefs = _RejectedIgnorePreferences();
    await expectLater(
      store.save(<String>{'google'}, prefs: prefs),
      throwsStateError,
    );
  });

  test('rejected removal is reported without claiming persistence', () async {
    final prefs = _RejectedIgnorePreferences();
    await expectLater(store.save(<String>{}, prefs: prefs), throwsStateError);
  });

  test('write exception is propagated to the caller', () async {
    final prefs = _RejectedIgnorePreferences(throwOnWrite: true);
    await expectLater(
      store.save(<String>{'google'}, prefs: prefs),
      throwsA(isA<Exception>()),
    );
  });

  test('encodeMirrorValue sorts and drops blank labels', () {
    expect(
      AssetRecurringSuggestionIgnoreStore.encodeMirrorValue(<String>{
        'b',
        '  ',
        'a',
        ' c ',
      }),
      <String>['a', 'b', 'c'],
    );
  });

  test('decodeMirrorValue tolerates non-list and trims entries', () {
    expect(
      AssetRecurringSuggestionIgnoreStore.decodeMirrorValue('nope'),
      isEmpty,
    );
    expect(
      AssetRecurringSuggestionIgnoreStore.decodeMirrorValue(<dynamic>[
        ' a ',
        '',
        'b',
      ]),
      <String>{'a', 'b'},
    );
  });
}

class _RejectedIgnorePreferences extends Fake implements SharedPreferences {
  _RejectedIgnorePreferences({this.throwOnWrite = false});

  final bool throwOnWrite;

  @override
  Future<bool> setString(String key, String value) async {
    if (throwOnWrite) {
      throw Exception('test write rejected');
    }
    return false;
  }

  @override
  Future<bool> remove(String key) async => false;
}
