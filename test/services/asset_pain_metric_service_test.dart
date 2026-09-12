import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';
import 'package:my_web_app/services/asset_pain_metric_service.dart';

void main() {
  group('AssetPainMetricService', () {
    test('Issue #5203: static bleed and stolen future calculations', () {
      const planner = AssetLiabilityPlanningService();
      final workbook = planner.buildWorkbook(
        baseDate: DateTime(2026, 8, 25),
        latestSnapshot: const <String, double>{
          'モビット': -500000,
          '三井住友銀行': 100000,
        },
        annualRateOverrides: const <String, double>{
          'mobit': 18.0,
        },
      );

      final bleed =
          AssetPainMetricService.calculateDailyInterestBleed(workbook);
      expect(bleed, greaterThan(0));
      final hours = AssetPainMetricService.dailyLostLaborHours(workbook);
      expect(hours, greaterThan(0));
      final stolen = AssetPainMetricService.stolenFutureTotal(
        workbook: workbook,
        months: 6,
      );
      expect(stolen, greaterThan(bleed * 30));
    });

    test('calculates hourly wage from income correctly', () {
      const service = AssetPainMetricService();
      expect(service.estimateHourlyWage(), 2500);
      expect(service.estimateHourlyWage(monthlyIncome: 400000), 2500);
      expect(service.estimateHourlyWage(monthlyIncome: 480000), 3000);
    });

    test('formats amount into labor time appropriately', () {
      const service = AssetPainMetricService();
      expect(service.formatLaborTime(0), '0分');
      expect(service.formatLaborTime(1250), '30分');
      expect(service.formatLaborTime(5000), '2.0時間');
    });

    test('calculates daily interest loss and lost labor hours', () {
      const service = AssetPainMetricService();
      expect(service.dailyInterestLoss(monthlyInterestTotal: 30000), 1000);
      expect(service.dailyLaborHoursLost(monthlyInterestTotal: 30000), 0.4);
    });
  });
}
