import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';
import 'package:my_web_app/services/disposable_balance_asset_liability_adapter.dart';
import 'package:my_web_app/services/disposable_balance_service.dart';

void main() {
  group('DisposableBalanceAssetLiabilityAdapter', () {
    const planner = AssetLiabilityPlanningService();
    const adapter = DisposableBalanceAssetLiabilityAdapter();
    const disposableBalance = DisposableBalanceService();

    test('routes cashflow fixed payments into fixed expenses, not debts', () {
      final asOfDate = DateTime(2026, 5, 26);
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          'cash': 464568,
          'au': -32152,
          'PayPayカード': -487324,
        },
        baseDate: asOfDate,
        monthlyPaymentOverrides: const <String, double>{
          AssetLiabilityPlanningService.rentAccountName: 63000,
          AssetLiabilityPlanningService.kddiProviderAccountName: 5764,
          'PayPayカード': 17229,
        },
        paymentSourceAccountIds: const <String, String>{
          AssetLiabilityPlanningService.rentAccountId: 'cash',
          AssetLiabilityPlanningService.kddiProviderAccountId: 'cash',
          'paypay_card': 'cash',
        },
        includeDefaultFixedPayments: true,
      );
      final nextPayday = disposableBalance.nextPaydayFor(
        asOfDate: asOfDate,
      );
      final cycleStart = disposableBalance.salaryCycleStartFor(
        asOfDate: asOfDate,
      );

      final result = adapter.build(
        workbook: workbook,
        cycleStart: cycleStart,
        nextPayday: nextPayday,
      );

      expect(
        result.recurringExpenses.map((expense) => expense.name),
        containsAll(<String>[
          AssetLiabilityPlanningService.rentAccountName,
          AssetLiabilityPlanningService.kddiProviderAccountName,
        ]),
      );
      expect(
        result.recurringExpenses
            .fold<double>(0, (sum, expense) => sum + expense.amount),
        68764,
      );
      expect(
        result.debts.map((debt) => debt.name),
        isNot(
          contains(AssetLiabilityPlanningService.rentAccountName),
        ),
      );
      expect(
        result.debts.map((debt) => debt.name),
        contains('PayPayカード'),
      );
      final payPayDebt = result.debts.singleWhere(
        (debt) => debt.monthlyPayment == 17229,
      );
      final payPayRow = workbook.debtMasterRows.singleWhere(
        (row) => row.name == 'PayPayカード',
      );
      expect(payPayDebt.dayOfMonth, 27);
      expect(payPayDebt.principalPayment, payPayRow.principalPaymentEstimate);
      expect(payPayDebt.interestPayment, payPayRow.monthlyInterestEstimate);
    });

    test('Anthropic Acom shopping charge is not a separate cash debt', () {
      const acomShoppingName =
          '\u30a2\u30b3\u30e0\u30b7\u30e7\u30c3\u30d4\u30f3\u30b0';
      final asOfDate = DateTime(2026, 5, 26);
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          'cash': 150000,
          acomShoppingName: -200000,
        },
        baseDate: asOfDate,
        monthlyPaymentOverrides: const <String, double>{
          AssetLiabilityPlanningService.acomShoppingAccountId: 68000,
        },
      );
      final nextPayday = disposableBalance.nextPaydayFor(
        asOfDate: asOfDate,
      );
      final cycleStart = disposableBalance.salaryCycleStartFor(
        asOfDate: asOfDate,
      );

      final result = adapter.build(
        workbook: workbook,
        cycleStart: cycleStart,
        nextPayday: nextPayday,
      );

      // \u30a2\u30b3\u30e0\u30b7\u30e7\u30c3\u30d4\u30f3\u30b0\u8acb\u6c42\u306b\u542b\u3080\u6271\u3044\u306b\u306a\u3063\u305f\u305f\u3081\u3001\u73fe\u91d1\u3067\u5225\u9014\u8fd4\u6e08\u3059\u308b
      // \u30c7\u30d6\u30c8\u3068\u3057\u3066\u306f\u73fe\u308c\u306a\u3044 (\u30a2\u30b3\u30e0\u6700\u4f4e\u8fd4\u6e08\u3067\u5438\u53ce\u3055\u308c\u308b)\u3002
      expect(
        result.debts.map((debt) => debt.name),
        isNot(
          contains(
            AssetLiabilityPlanningService.anthropicAcomShoppingPaymentName,
          ),
        ),
      );
    });
  });
}
