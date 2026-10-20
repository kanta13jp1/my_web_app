import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_web_app/services/asset_category_budget_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('fresh budget consumer inherits a prior consumer setting without owner context', () async {
    SharedPreferences.setMockInitialValues({});
    const prior = AssetCategoryBudgetStore();
    await prior.save({'Synthetic category': 123});
    const next = AssetCategoryBudgetStore();
    expect(await next.hasSavedSetting(), isTrue);
    expect(await next.load(), {'Synthetic category': 123.0});
    // This probe observes shared local scope, not a real account sign-in.
  });
}
