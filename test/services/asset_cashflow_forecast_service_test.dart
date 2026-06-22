import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_cashflow_forecast_service.dart';

void main() {
  group('AssetCashflowForecastService.project', () {
    test('flat forecast when there are no recurring or dated entries', () {
      final forecast = AssetCashflowForecastService.project(
        asOf: DateTime(2026, 6, 1),
        startingBalance: 100000,
        horizonMonths: 3,
      );

      expect(forecast.months, hasLength(3));
      expect(forecast.hasShortfall, isFalse);
      expect(forecast.worstBalance, 100000);
      for (final month in forecast.months) {
        expect(month.closingBalance, 100000);
        expect(month.openingBalance, 100000);
      }
    });

    test('surplus income grows the balance with no shortfall', () {
      final forecast = AssetCashflowForecastService.project(
        asOf: DateTime(2026, 6, 1),
        startingBalance: 500000,
        horizonMonths: 2,
        recurringIncome: const [
          AssetCashflowRecurringEntry(dayOfMonth: 25, amount: 300000),
        ],
        recurringOutflow: const [
          AssetCashflowRecurringEntry(dayOfMonth: 10, amount: 100000),
        ],
      );

      expect(forecast.hasShortfall, isFalse);
      expect(forecast.firstShortfallDate, isNull);
      // 6月: 500000 -100000 +300000 = 700000。7月: +200000 = 900000。
      expect(forecast.months[0].closingBalance, 700000);
      expect(forecast.months[1].closingBalance, 900000);
      expect(forecast.worstBalance, 400000);
      expect(forecast.shortfallRecoveryAmount, 0);
    });

    test('detects the first shortfall date and recovery amount', () {
      final forecast = AssetCashflowForecastService.project(
        asOf: DateTime(2026, 6, 1),
        startingBalance: 100000,
        horizonMonths: 3,
        recurringIncome: const [
          AssetCashflowRecurringEntry(dayOfMonth: 25, amount: 200000),
        ],
        recurringOutflow: const [
          AssetCashflowRecurringEntry(dayOfMonth: 10, amount: 250000),
        ],
      );

      expect(forecast.hasShortfall, isTrue);
      expect(forecast.firstShortfallDate, DateTime(2026, 6, 10));
      // 6月worst -150000, 7月worst -200000, 8月worst -250000。
      expect(forecast.worstBalance, -250000);
      expect(forecast.shortfallRecoveryAmount, 250000);
      expect(forecast.months[0].isShortfall, isTrue);
    });

    test('closing balance of month N equals opening balance of month N+1', () {
      final forecast = AssetCashflowForecastService.project(
        asOf: DateTime(2026, 6, 1),
        startingBalance: 80000,
        horizonMonths: 4,
        recurringIncome: const [
          AssetCashflowRecurringEntry(dayOfMonth: 25, amount: 180000),
        ],
        recurringOutflow: const [
          AssetCashflowRecurringEntry(dayOfMonth: 5, amount: 60000),
          AssetCashflowRecurringEntry(dayOfMonth: 27, amount: 90000),
        ],
      );

      for (var i = 1; i < forecast.months.length; i++) {
        expect(
          forecast.months[i].openingBalance,
          forecast.months[i - 1].closingBalance,
        );
      }
    });

    test('current month ignores entries dated before the anchor day', () {
      final withEarlyAnchor = AssetCashflowForecastService.project(
        asOf: DateTime(2026, 6, 1),
        startingBalance: 50000,
        horizonMonths: 1,
        recurringOutflow: const [
          AssetCashflowRecurringEntry(dayOfMonth: 10, amount: 100000),
        ],
      );
      final withLateAnchor = AssetCashflowForecastService.project(
        asOf: DateTime(2026, 6, 15),
        startingBalance: 50000,
        horizonMonths: 1,
        recurringOutflow: const [
          AssetCashflowRecurringEntry(dayOfMonth: 10, amount: 100000),
        ],
      );

      // 1日基準なら10日の支払を計上してショート、15日基準なら計上しない。
      expect(withEarlyAnchor.hasShortfall, isTrue);
      expect(withLateAnchor.hasShortfall, isFalse);
      expect(withLateAnchor.months[0].closingBalance, 50000);
    });

    test('one-time income only counts in its own month', () {
      final forecast = AssetCashflowForecastService.project(
        asOf: DateTime(2026, 6, 1),
        startingBalance: 0,
        horizonMonths: 3,
        oneTimeIncome: [
          AssetCashflowDatedEntry(date: DateTime(2026, 7, 10), amount: 70000),
        ],
      );

      expect(forecast.months[0].incomeTotal, 0);
      expect(forecast.months[1].incomeTotal, 70000);
      expect(forecast.months[2].incomeTotal, 0);
      expect(forecast.months[2].closingBalance, 70000);
    });

    test('clamps a day-of-month beyond the month length to month end', () {
      final forecast = AssetCashflowForecastService.project(
        asOf: DateTime(2026, 2, 1),
        startingBalance: 5000,
        horizonMonths: 1,
        recurringOutflow: const [
          AssetCashflowRecurringEntry(dayOfMonth: 31, amount: 6000),
        ],
      );

      // 2026年2月は28日まで。31日指定は28日へ丸めて計上される。
      expect(forecast.months[0].outflowTotal, 6000);
      expect(forecast.months[0].closingBalance, -1000);
      expect(forecast.firstShortfallDate, DateTime(2026, 2, 28));
    });

    test('safety margin surfaces a shortfall even above zero', () {
      final forecast = AssetCashflowForecastService.project(
        asOf: DateTime(2026, 6, 1),
        startingBalance: 30000,
        horizonMonths: 1,
        recurringOutflow: const [
          AssetCashflowRecurringEntry(dayOfMonth: 10, amount: 25000),
        ],
        safetyMargin: 10000,
      );

      // worst = 5000。0以上だがショートなし、安全余裕10000は割り込む。
      expect(forecast.hasShortfall, isFalse);
      expect(forecast.safetyShortfallAmount, 5000);
    });
  });
}
