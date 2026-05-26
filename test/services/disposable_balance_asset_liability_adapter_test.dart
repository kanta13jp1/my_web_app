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
      expect(payPayDebt.dayOfMonth, 27);
    });
  });
}
