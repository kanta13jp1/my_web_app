import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_web_app/services/asset_category_budget_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('owner settings are isolated and restored without adopting legacy',
      () async {
    const legacy = AssetCategoryBudgetStore();
    const a = AssetCategoryBudgetStore.forOwner('owner-a');
    const b = AssetCategoryBudgetStore.forOwner('owner-b');
    await legacy.save({'legacy': 999});
    expect(await a.load(), isEmpty);
    expect(await b.hasSavedSetting(), isFalse);
    await a.save({'food': 123});
    expect(await b.load(), isEmpty);
    await b.save({});
    expect(await b.hasSavedSetting(), isTrue);
    expect(await a.load(), {'food': 123.0});
    expect(await legacy.load(), {'legacy': 999.0});
  });
  test('scoped unauthenticated access is rejected', () async {
    const store = AssetCategoryBudgetStore.forOwner(null);
    await expectLater(store.load(), throwsStateError);
    await expectLater(store.save({'food': 123}), throwsStateError);
    await expectLater(store.hasSavedSetting(), throwsStateError);
  });
  test('mirror restores only the named owner including an explicit clear', () {
    final row = <String, dynamic>{
      'user_id': 'owner-a',
      'value': <String, dynamic>{'food': 123},
    };
    expect(
      AssetCategoryBudgetStore.decodeOwnedMirrorRow(row, 'owner-a'),
      <String, double>{'food': 123},
    );
    expect(
      AssetCategoryBudgetStore.decodeOwnedMirrorRow(row, 'owner-b'),
      isNull,
    );
    expect(AssetCategoryBudgetStore.decodeOwnedMirrorRow(row, ''), isNull);
    expect(
      AssetCategoryBudgetStore.decodeOwnedMirrorRow(
        <String, dynamic>{'value': row['value']},
        'owner-a',
      ),
      isNull,
    );
    expect(
      AssetCategoryBudgetStore.decodeOwnedMirrorRow(
        <String, dynamic>{'user_id': 'owner-a', 'value': <String, dynamic>{}},
        'owner-a',
      ),
      isEmpty,
    );
  });
}
