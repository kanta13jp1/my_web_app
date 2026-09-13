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

    test('既存残高は一括返済せず最低返済額だけを予定する', () {
      final billing = service.computeBilling(balance: 530163, config: config);
      expect(billing.existingBalanceAmount, 530163);
      expect(billing.newUsageAmount, 0);
      expect(billing.monthlyAmount, 10000);
      expect(billing.overLimitAmount, 0);
      expect(billing.billedAmount, 10000);
      expect(billing.paymentDay, 25);
      expect(billing.isOverLimit, isFalse);
    });

    test('新規利用分は最低返済額へ全額上乗せする', () {
      final billing = service.computeBilling(
        balance: 530163,
        config: const AssetLiabilityRevolvingCreditConfig(
          monthlyAmount: 10000,
          newUsageAmount: 23182,
        ),
      );
      expect(billing.newUsageAmount, 23182);
      expect(billing.existingBalanceAmount, 506981);
      expect(billing.billedAmount, 33182);
    });

    test('取込明細の新規利用額は手入力値より優先する', () {
      final billing = service.computeBilling(
        balance: 100000,
        config: const AssetLiabilityRevolvingCreditConfig(
          monthlyAmount: 5000,
          newUsageAmount: 10000,
        ),
        newUsageAmount: 30000,
      );
      expect(billing.newUsageAmount, 30000);
      expect(billing.billedAmount, 35000);
    });

    test('新規利用額と最低返済額の合計は残高を超えない', () {
      final billing = service.computeBilling(
        balance: 12000,
        config: const AssetLiabilityRevolvingCreditConfig(
          monthlyAmount: 10000,
          newUsageAmount: 10000,
        ),
      );
      expect(billing.newUsageAmount, 10000);
      expect(billing.monthlyAmount, 2000);
      expect(billing.billedAmount, 12000);
    });

    test('残高が負/ゼロなら返済予定も0', () {
      final billing = service.computeBilling(balance: -1000, config: config);
      expect(billing.balance, 0);
      expect(billing.billedAmount, 0);
    });

    test('旧保存値の利用限度額と返済日は計算を変えない', () {
      final billing = service.computeBilling(
        balance: 530163,
        config: const AssetLiabilityRevolvingCreditConfig(
          monthlyAmount: 10000,
          newUsageAmount: 20000,
          paymentDay: 10,
          creditLimit: 500000,
        ),
      );
      expect(billing.overLimitAmount, 0);
      expect(billing.billedAmount, 30000);
      expect(billing.paymentDay, 25);
    });
  });
}
