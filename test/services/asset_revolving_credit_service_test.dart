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

    test('取込明細がある場合、各明細行の内訳とカバー状況ステータスを生成する', () {
      final billing = service.computeBilling(
        balance: 200000,
        config: const AssetLiabilityRevolvingCreditConfig(monthlyAmount: 10000),
        statementLines: const <AssetLiabilityCardStatementLine>[
          AssetLiabilityCardStatementLine(
            id: 'line_1',
            billingAccountId: 'card_1',
            billingAccountName: 'カード',
            postedAt: null,
            description: 'スーパー食費',
            amount: 5000,
          ),
          AssetLiabilityCardStatementLine(
            id: 'line_2',
            billingAccountId: 'card_1',
            billingAccountName: 'カード',
            postedAt: null,
            description: '家電購入',
            amount: 25000,
          ),
        ],
        newUsageAmount: 30000,
        scheduledPayment:
            20000, // 最低返済10000 + 新規返済枠10000 (line_1はカバー、line_2は不足)
      );

      expect(billing.hasImportedStatement, isTrue);
      expect(billing.usageItems, hasLength(2));
      expect(billing.usageItems[0].description, 'スーパー食費');
      expect(
        billing.usageItems[0].status,
        AssetLiabilityRevolvingUsageStatus.covered,
      );
      expect(billing.usageItems[0].statusLabel, '今月返済でカバー');

      expect(billing.usageItems[1].description, '家電購入');
      expect(
        billing.usageItems[1].status,
        AssetLiabilityRevolvingUsageStatus.uncoveredShortfall,
      );
      expect(billing.usageItems[1].statusLabel, contains('不足'));
    });

    test('明細未取込で手入力設定がある場合、未取込フラグと手入力アイテムを保持する', () {
      final billing = service.computeBilling(
        balance: 100000,
        config: const AssetLiabilityRevolvingCreditConfig(
          monthlyAmount: 10000,
          newUsageAmount: 6000,
        ),
      );
      expect(billing.hasImportedStatement, isFalse);
      expect(billing.usageItems, hasLength(1));
      expect(billing.usageItems.first.id, 'manual_usage');
    });
  });
}
