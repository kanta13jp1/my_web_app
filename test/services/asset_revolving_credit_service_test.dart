import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_revolving_credit_service.dart';

void main() {
  group('AssetRevolvingCreditService', () {
    const service = AssetRevolvingCreditService();
    const config = AssetLiabilityRevolvingCreditConfig(
      monthlyAmount: 10000,
      creditLimit: 500000,
    );

    test('5月: 残高が限度額以内ならリボ設定額のみ請求', () {
      final billing = service.computeBilling(balance: 459329, config: config);
      expect(billing.overLimitAmount, 0);
      expect(billing.billedAmount, 10000);
      expect(billing.isOverLimit, isFalse);
    });

    test('6月: 限度額超過分が設定額に上乗せされる', () {
      final billing = service.computeBilling(balance: 530163, config: config);
      expect(billing.overLimitAmount, 30163);
      expect(billing.billedAmount, 40163);
      expect(billing.isOverLimit, isTrue);
    });

    test('7月: 別の残高でも式どおり一括上乗せ', () {
      final billing = service.computeBilling(balance: 519843, config: config);
      expect(billing.overLimitAmount, 19843);
      expect(billing.billedAmount, 29843);
    });

    test('残高が限度額ちょうどなら設定額のみ', () {
      final billing = service.computeBilling(balance: 500000, config: config);
      expect(billing.overLimitAmount, 0);
      expect(billing.billedAmount, 10000);
    });

    test('残高が負/ゼロでも設定額を下回らない', () {
      final billing = service.computeBilling(balance: -1000, config: config);
      expect(billing.balance, 0);
      expect(billing.billedAmount, 10000);
    });

    test('利用限度額が未設定(0)なら上乗せせず設定額のみ請求', () {
      final billing = service.computeBilling(
        balance: 530163,
        config: const AssetLiabilityRevolvingCreditConfig(
          monthlyAmount: 10000,
          creditLimit: 0,
        ),
      );
      expect(billing.overLimitAmount, 0);
      expect(billing.billedAmount, 10000);
    });
  });
}
