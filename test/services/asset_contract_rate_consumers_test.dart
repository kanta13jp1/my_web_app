import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';
import 'package:my_web_app/services/asset_liability_repayment_simulation_service.dart';
import 'package:my_web_app/services/asset_pain_metric_service.dart';

void main() {
  const planner = AssetLiabilityPlanningService();
  const simulation = AssetLiabilityRepaymentSimulationService();

  for (final rate in <double>[0.15, 0.12, 0]) {
    test('registered rate $rate reaches pain and all repayment strategies', () {
      final workbook = planner.buildWorkbook(
        latestSnapshot: const <String, double>{'mobit': -120000},
        baseDate: DateTime(2026, 9, 6),
        annualRateOverrides: <String, double>{'mobit': rate},
        monthlyPaymentOverrides: const <String, double>{'mobit': 10000},
      );
      final expectedMonthlyInterest = 120000 * rate / 12;
      final debt = workbook.debtMasterRows.single;
      expect(debt.annualRate, rate);
      expect(
        debt.monthlyInterestEstimate,
        closeTo(expectedMonthlyInterest, 0.000001),
      );
      expect(
        AssetPainMetricService.calculateDailyInterestBleed(workbook),
        closeTo(expectedMonthlyInterest / 30, 0.000001),
      );
      expect(
        AssetPainMetricService.dailyLostLaborHours(workbook),
        closeTo(expectedMonthlyInterest / 30 / 2500, 0.000001),
      );
      expect(
        AssetPainMetricService.stolenFutureTotal(workbook: workbook),
        closeTo(expectedMonthlyInterest * 6, 0.000001),
      );
      final comparison = simulation.buildComparison(workbook: workbook);
      expect(comparison.eligibleDebtCount, 1);
      for (final strategy in AssetLiabilityRepaymentSimulationStrategy.values) {
        final plan = comparison.planFor(strategy)!;
        expect(plan.priorityRows.single.annualRate, rate);
        expect(
          plan.monthSnapshots.first.interestTotal,
          closeTo(expectedMonthlyInterest, 0.000001),
        );
        expect(
          plan.monthSnapshots.first.remainingDebt,
          closeTo(120000 + expectedMonthlyInterest - 10000, 0.000001),
        );
      }
    });
  }
}
