import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';
import 'package:my_web_app/services/debt_progress_card_service.dart';

void main() {
  const planner = AssetLiabilityPlanningService();
  const service = DebtProgressCardService();

  for (final confirmed in [false, true]) {
    test('zero interest requires explicit rate evidence confirmed=$confirmed',
        () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const {'SyntheticLoan': -100000},
        baseDate: DateTime(2026, 6, 20),
        includeDefaultFixedPayments: false,
        monthlyPaymentOverrides: const {'SyntheticLoan': 10000},
        annualRateOverrides: confirmed ? const {'SyntheticLoan': 0} : const {},
      );
      final card = service.build(
        workbook: workbook,
        confirmedAnnualRateAccountKeys:
            confirmed ? const {'SyntheticLoan'} : const {},
      )!;
      if (confirmed) {
        expect(card.payoffMonths, 10);
        expect(card.estimatedInterest, 0);
        expect(card.projectionStatus, DebtProgressProjectionStatus.estimated);
      } else {
        expect(card.payoffMonths, isNull);
        expect(card.estimatedInterest, isNull);
        expect(card.projectionStatus,
            DebtProgressProjectionStatus.unconfirmedTerms);
        expect(card.projectionNote, contains('未確認'));
      }
    });
  }

  test('confirmed insufficient budget differs from unknown terms', () {
    final workbook = planner.buildWorkbook(
      latestSnapshot: const {'SyntheticLoan': -100000},
      baseDate: DateTime(2026, 6, 20),
      includeDefaultFixedPayments: false,
      monthlyPaymentOverrides: const {'SyntheticLoan': 1000},
      annualRateOverrides: const {'SyntheticLoan': 0.18},
    );
    final card = service.build(
      workbook: workbook,
      confirmedAnnualRateAccountKeys: const {'SyntheticLoan'},
    )!;
    expect(card.projectionStatus,
        DebtProgressProjectionStatus.insufficientPayment);
    expect(card.payoffMonths, isNull);
    expect(card.estimatedInterest, isNull);
  });

  test('missing prior stock is not a whole-report month comparison', () {
    final workbook = planner.buildWorkbook(
      latestSnapshot: const {
        'SyntheticLoanA': -100000,
        'SyntheticLoanB': -200000
      },
      baseDate: DateTime(2026, 6, 20),
      includeDefaultFixedPayments: false,
    );
    final id = workbook.debtMasterRows
        .singleWhere((row) => row.name == 'SyntheticLoanA')
        .id;
    final card = service.build(
      workbook: workbook,
      priorBalancesByAccountId: {id: 120000},
    )!;
    expect(card.totalDebt, 300000);
    expect(card.monthOverMonthDelta, isNull);
  });
}
