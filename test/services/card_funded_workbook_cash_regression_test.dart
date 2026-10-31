import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';

void main() {
  test('card funded fixed cost preserves cash projection and card repayment',
      () {
    const service = AssetLiabilityPlanningService();
    const snapshot = <String, double>{'財布': 50000, 'PayPayカード': -20000};
    final baseline = service.buildWorkbook(
      latestSnapshot: snapshot,
      baseDate: DateTime(2026, 10, 17),
    );
    final card = baseline.accounts
        .singleWhere((a) => a.kind == AssetLiabilityAccountKind.creditCard);
    final actual = service.buildWorkbook(
      latestSnapshot: snapshot,
      baseDate: DateTime(2026, 10, 17),
      recurringFixedCosts: [
        AssetRecurringFixedCost(
          id: 'probe',
          name: 'Probe subscription',
          amount: 2000,
          paymentDay: 20,
          sourceAccountId: card.id,
          category: AssetRecurringFixedCostCategory.subscription,
        ),
      ],
    );
    expect(
      actual.cashAfterScheduledPayments,
      baseline.cashAfterScheduledPayments,
    );
    expect(
      actual.monthlyUnpaidPaymentTotal,
      baseline.monthlyUnpaidPaymentTotal,
    );
    expect(
      actual.cashflowRows.any((r) => r.accountName == 'Probe subscription'),
      isTrue,
    );
  });
  test('bank funded fixed cost still reduces cash projection', () {
    const service = AssetLiabilityPlanningService();
    const snapshot = <String, double>{'三井住友銀行大塚支店': 50000};
    final baseline = service.buildWorkbook(
      latestSnapshot: snapshot,
      baseDate: DateTime(2026, 10, 17),
    );
    final bank = baseline.accounts.single;
    final actual = service.buildWorkbook(
      latestSnapshot: snapshot,
      baseDate: DateTime(2026, 10, 17),
      recurringFixedCosts: [
        AssetRecurringFixedCost(
          id: 'probe',
          name: 'Probe bank bill',
          amount: 2000,
          paymentDay: 20,
          sourceAccountId: bank.id,
        ),
      ],
    );
    expect(
      actual.cashAfterScheduledPayments,
      baseline.cashAfterScheduledPayments - 2000,
    );
  });
}
