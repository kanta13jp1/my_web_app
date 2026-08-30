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
            newUsageAmount: 23182,
            paymentDay: 25,
            creditLimit: 500000,
          ),
        },
        prefs: prefs,
      );

      final loaded = await store.load(prefs: prefs);
      expect(loaded.keys, ['aupay']);
      expect(loaded['aupay']!.monthlyAmount, 10000);
      expect(loaded['aupay']!.newUsageAmount, 23182);
      expect(loaded['aupay']!.paymentDay, 25);
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

    test('encode/decode mirror value round-trips (端末A→端末B 同期)', () {
      final configs = <String, AssetLiabilityRevolvingCreditConfig>{
        'aupay': const AssetLiabilityRevolvingCreditConfig(
          monthlyAmount: 10000,
          newUsageAmount: 23182,
          paymentDay: 25,
          creditLimit: 500000,
        ),
        'rakuten': const AssetLiabilityRevolvingCreditConfig(
          monthlyAmount: 5000,
          creditLimit: 0,
        ),
      };

      // encode (端末A の upload) → decode (端末B の boot 復元) で値が一致する。
      final encoded =
          AssetRevolvingCreditConfigStore.encodeMirrorValue(configs);
      final decoded =
          AssetRevolvingCreditConfigStore.decodeMirrorValue(encoded);

      expect(decoded.keys, unorderedEquals(<String>['aupay', 'rakuten']));
      expect(decoded['aupay']!.monthlyAmount, 10000);
      expect(decoded['aupay']!.newUsageAmount, 23182);
      expect(decoded['aupay']!.paymentDay, 25);
      expect(decoded['aupay']!.creditLimit, 500000);
      expect(decoded['rakuten']!.monthlyAmount, 5000);
      expect(decoded['rakuten']!.creditLimit, 0);
    });

    test('decodeMirrorValue ignores malformed input', () {
      expect(
        AssetRevolvingCreditConfigStore.decodeMirrorValue(null),
        isEmpty,
      );
      expect(
        AssetRevolvingCreditConfigStore.decodeMirrorValue('not a map'),
        isEmpty,
      );
      // 不正な値 (Map でない) のエントリは捨て、正しいものだけ残す。
      final decoded = AssetRevolvingCreditConfigStore.decodeMirrorValue(
        <String, dynamic>{
          'aupay': <String, dynamic>{
            'monthlyAmount': 8000,
            'creditLimit': 200000,
          },
          'broken': 'oops',
        },
      );
      expect(decoded.keys, <String>['aupay']);
      expect(decoded['aupay']!.monthlyAmount, 8000);
    });

    test('旧保存形式は新規利用額0・25日として復元する', () {
      final decoded = AssetRevolvingCreditConfigStore.decodeMirrorValue(
        <String, dynamic>{
          'legacy': <String, dynamic>{
            'monthlyAmount': 8000,
            'creditLimit': 200000,
          },
        },
      );

      expect(decoded['legacy']!.monthlyAmount, 8000);
      expect(decoded['legacy']!.newUsageAmount, 0);
      expect(decoded['legacy']!.paymentDay, 25);
      expect(decoded['legacy']!.creditLimit, 200000);
    });
  });
}
