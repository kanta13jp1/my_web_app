import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_revolving_credit_config_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AssetRevolvingCreditConfigStore', () {
    const store = AssetRevolvingCreditConfigStore();

    test('round-trips configs through SharedPreferences', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      await store.save(
        <String, AssetLiabilityRevolvingCreditConfig>{
          'aupay': const AssetLiabilityRevolvingCreditConfig(
            monthlyAmount: 10000,
            creditLimit: 500000,
          ),
        },
        prefs: prefs,
      );

      final loaded = await store.load(prefs: prefs);
      expect(loaded.keys, ['aupay']);
      expect(loaded['aupay']!.monthlyAmount, 10000);
      expect(loaded['aupay']!.creditLimit, 500000);
    });

    test('returns empty map when nothing stored', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final loaded = await store.load(prefs: prefs);
      expect(loaded, isEmpty);
    });

    test('save with empty map clears the key', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      await store.save(
        <String, AssetLiabilityRevolvingCreditConfig>{
          'aupay': const AssetLiabilityRevolvingCreditConfig(
            monthlyAmount: 10000,
            creditLimit: 500000,
          ),
        },
        prefs: prefs,
      );
      await store.save(
        const <String, AssetLiabilityRevolvingCreditConfig>{},
        prefs: prefs,
      );
      final loaded = await store.load(prefs: prefs);
      expect(loaded, isEmpty);
    });
  });
}
