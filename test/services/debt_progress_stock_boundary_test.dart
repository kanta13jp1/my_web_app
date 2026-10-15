import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';
import 'package:my_web_app/services/debt_progress_card_service.dart';

void main() {
  test('paid monthly installment does not erase outstanding loan principal', () {
    final workbook = const AssetLiabilityPlanningService().buildWorkbook(
      latestSnapshot: const {'アコムローン': -100000, 'Synthetic bank': 10000},
      baseDate: DateTime(2026, 6, 20),
      includeDefaultFixedPayments: false,
      paidAccountNames: const {'アコムローン'},
    );
    final card = const DebtProgressCardService().build(workbook: workbook);
    expect(card, isNotNull);
    expect(card!.totalDebt, 100000);
  });

  test('future recurring living cost is not outstanding repayment principal', () {
    final workbook = const AssetLiabilityPlanningService().buildWorkbook(
      latestSnapshot: const {'Synthetic bank': 10000},
      baseDate: DateTime(2026, 6, 20),
      includeDefaultFixedPayments: false,
      recurringFixedCosts: const [
        AssetRecurringFixedCost(
          id: 'synthetic-rent',
          name: 'Synthetic upcoming rent',
          amount: 2000,
          paymentDay: 22,
        ),
      ],
    );
    final card = const DebtProgressCardService().build(workbook: workbook);
    expect(card, isNull);
  });

  test('repayment report principal excludes injected upcoming fixed costs', () {
    final workbook = const AssetLiabilityPlanningService().buildWorkbook(
      latestSnapshot: const {'アコムローン': -100000, 'Synthetic bank': 10000},
      baseDate: DateTime(2026, 6, 20),
      includeDefaultFixedPayments: false,
      recurringFixedCosts: const [
        AssetRecurringFixedCost(
          id: 'synthetic-rent',
          name: 'Synthetic upcoming rent',
          amount: 2000,
          paymentDay: 22,
        ),
      ],
    );
    final card = const DebtProgressCardService().build(workbook: workbook);
    expect(card!.totalDebt, 100000);
  });
}
