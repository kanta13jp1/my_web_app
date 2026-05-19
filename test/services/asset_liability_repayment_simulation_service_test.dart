import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';
import 'package:my_web_app/services/asset_liability_repayment_simulation_service.dart';

void main() {
  group('AssetLiabilityRepaymentSimulationService.buildComparison', () {
    const planner = AssetLiabilityPlanningService();
    const service = AssetLiabilityRepaymentSimulationService();

    test('switches priority order by strategy', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          'cash': 100000,
          'mobit': -120000,
          'aupay card': -90000,
          'paypay card': -30000,
        },
        baseDate: DateTime(2026, 5, 1),
        monthlyPaymentOverrides: const <String, double>{
          'mobit': 10000,
          'aupay card': 8000,
          'paypay card': 6000,
        },
        annualRateOverrides: const <String, double>{
          'mobit': 0.18,
          'aupay card': 0.08,
          'paypay card': 0.15,
        },
      );

      final result = service.buildComparison(
        workbook: workbook,
        extraMonthlyPayment: 10000,
      );

      expect(
        result
            .planFor(AssetLiabilityRepaymentSimulationStrategy.interestRate)
            ?.firstFocusDebtName,
        'mobit',
      );
      expect(
        result
            .planFor(AssetLiabilityRepaymentSimulationStrategy.smallestBalance)
            ?.firstFocusDebtName,
        'paypay card',
      );
      expect(
        result
            .planFor(AssetLiabilityRepaymentSimulationStrategy.paymentDay)
            ?.firstFocusDebtName,
        'aupay card',
      );
    });

    test('extra monthly repayment shortens payoff timing and interest', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          'cash': 150000,
          'mobit': -180000,
          'aupay card': -120000,
        },
        baseDate: DateTime(2026, 5, 1),
        monthlyPaymentOverrides: const <String, double>{
          'mobit': 12000,
          'aupay card': 8000,
        },
        annualRateOverrides: const <String, double>{
          'mobit': 0.18,
          'aupay card': 0.15,
        },
      );

      final baseline = service
          .buildComparison(workbook: workbook)
          .planFor(AssetLiabilityRepaymentSimulationStrategy.interestRate);
      final withExtra = service
          .buildComparison(workbook: workbook, extraMonthlyPayment: 30000)
          .planFor(AssetLiabilityRepaymentSimulationStrategy.interestRate);

      expect(baseline?.estimatedPayoffMonths, isNotNull);
      expect(withExtra?.estimatedPayoffMonths, isNotNull);
      expect(
        withExtra!.estimatedPayoffMonths,
        lessThan(baseline!.estimatedPayoffMonths!),
      );
      expect(
        withExtra.estimatedInterestTotal,
        lessThan(baseline.estimatedInterestTotal),
      );
    });

    test('excludes paid and card-billed debts without mutating workbook', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{
          'cash': 80000,
          'au': -12000,
          'aupay card': -60000,
          'paypay card': -20000,
          'mobit': -100000,
        },
        baseDate: DateTime(2026, 5, 1),
        monthlyPaymentOverrides: const <String, double>{
          'aupay card': 9000,
          'paypay card': 7000,
          'mobit': 10000,
        },
        paidAccountNames: const <String>{'paypay card'},
      );
      final before = workbook.debtMasterRows
          .map((row) => '${row.id}:${row.balance}:${row.paid}')
          .toList();

      final result = service.buildComparison(
        workbook: workbook,
        extraMonthlyPayment: 5000,
      );
      final selectedPlan = result.planFor(
        AssetLiabilityRepaymentSimulationStrategy.interestRate,
      );
      final after = workbook.debtMasterRows
          .map((row) => '${row.id}:${row.balance}:${row.paid}')
          .toList();

      expect(result.eligibleDebtCount, 2);
      expect(
        selectedPlan?.priorityRows.map((row) => row.name),
        isNot(contains('au')),
      );
      expect(
        selectedPlan?.priorityRows.map((row) => row.name),
        isNot(contains('paypay card')),
      );
      expect(after, before);
    });
  });
}
