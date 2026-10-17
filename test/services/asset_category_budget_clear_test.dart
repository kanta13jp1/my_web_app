import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_web_app/services/asset_category_budget_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('explicit cleared budget remains distinguishable from never configured', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    const store = AssetCategoryBudgetStore();
    await store.save(<String, double>{'food': 10000}, prefs: prefs);
    await store.save(<String, double>{}, prefs: prefs);
    expect(await store.load(prefs: prefs), isEmpty);
    expect(prefs.containsKey(AssetCategoryBudgetStore.prefsKey), isTrue,
        reason: 'A cleared budget must remain distinguishable from no local setting before mirror restore.',
    );
  });
}
