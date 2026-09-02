import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_pain_metric_service.dart';

void main() {
  group('AssetPainMetricService', () {
    const service = AssetPainMetricService();

    test('estimates hourly wage from monthly income or default', () {
      expect(service.estimateHourlyWage(monthlyIncome: null), 2500);
      expect(service.estimateHourlyWage(monthlyIncome: 0), 2500);
      expect(service.estimateHourlyWage(monthlyIncome: 400000), 2500);
      expect(service.estimateHourlyWage(monthlyIncome: 800000), 5000);
    });

    test('formats labor time for minutes and hours', () {
      expect(service.formatLaborTime(1250, hourlyWage: 2500), '30分');
      expect(service.formatLaborTime(5000, hourlyWage: 2500), '2.0時間');
      expect(service.formatLaborTime(6250, hourlyWage: 2500), '2.5時間');
      expect(service.formatLaborTime(0, hourlyWage: 2500), '0分');
    });

    test('calculates daily interest loss and lost labor hours', () {
      final dailyLoss = service.dailyInterestLoss(monthlyInterestTotal: 90000);
      expect(dailyLoss, 3000);

      final lostHours = service.dailyLaborHoursLost(
        monthlyInterestTotal: 90000,
        hourlyWage: 2500,
      );
      expect(lostHours, 1.2);
    });
  });
}
