import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_web_app/services/asset_category_budget_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('explicit cleared budget remains distinguishable from never configured',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    const store = AssetCategoryBudgetStore();
    await store.save(<String, double>{'food': 10000}, prefs: prefs);
    await store.save(<String, double>{}, prefs: prefs);
    expect(await store.load(prefs: prefs), isEmpty);
    expect(
      prefs.containsKey(AssetCategoryBudgetStore.prefsKey),
      isTrue,
      reason:
          'A cleared budget must remain distinguishable from no local setting before mirror restore.',
    );
  });
  test('never configured remains eligible for mirror restore', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    const store = AssetCategoryBudgetStore();
    expect(await store.hasSavedSetting(prefs: prefs), isFalse);
    expect(await store.load(prefs: prefs), isEmpty);
  });
  test('cleared setting survives a fresh store and can be configured again',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    const store = AssetCategoryBudgetStore();
    await store.save(<String, double>{}, prefs: prefs);
    const restoredStore = AssetCategoryBudgetStore();
    expect(await restoredStore.hasSavedSetting(prefs: prefs), isTrue);
    expect(await restoredStore.load(prefs: prefs), isEmpty);
    await restoredStore.save(<String, double>{'food': 5000}, prefs: prefs);
    expect(await store.load(prefs: prefs), <String, double>{'food': 5000});
  });
  test('malformed local value remains eligible for mirror recovery', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      AssetCategoryBudgetStore.prefsKey: 'broken-json',
    });
    final prefs = await SharedPreferences.getInstance();
    expect(await const AssetCategoryBudgetStore().hasSavedSetting(prefs: prefs), isFalse);
  });
}
