import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_web_app/models/savings_life_plan.dart';
import 'package:my_web_app/services/savings_life_plan_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('reload restores owner plan and daily notes without financial writes',
      () async {
    SharedPreferences.setMockInitialValues(
      {'salary_amount': 400000, 'account_balance_history': 'protected'},
    );
    final date = DateTime(2026, 10, 13);
    final store = SavingsLifePlanStore('owner-a');
    await store.save(
      SavingsLifePlan(
        start: date,
        targetDate: DateTime(2027, 10, 13),
        savings: 250000,
      ),
    );
    await store.saveDaily(date, {'morning', 'spent:1234'});
    final restored = SavingsLifePlanStore('owner-a');
    expect((await restored.load())!.savings, 250000);
    expect(await restored.loadDaily(date), {'morning', 'spent:1234'});
    expect(await restored.loadDaily(DateTime(2026, 10, 14)), isEmpty);
    expect(await SavingsLifePlanStore('owner-b').load(), isNull);
    expect(await SavingsLifePlanStore('owner-b').loadDaily(date), isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('salary_amount'), 400000);
    expect(prefs.getString('account_balance_history'), 'protected');
    expect(
      prefs
          .getKeys()
          .where((k) => !k.startsWith('savings_life_plan_v1:'))
          .toSet(),
      {'salary_amount', 'account_balance_history'},
    );
  });
}
