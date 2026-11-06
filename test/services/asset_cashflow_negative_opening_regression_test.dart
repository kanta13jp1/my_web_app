import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_cashflow_forecast_service.dart';

void main() {
  final anchor = DateTime(2026, 6, 15);

  test('negative opening is recorded on the anchor before later recovery', () {
    final forecast = AssetCashflowForecastService.project(
      asOf: anchor,
      startingBalance: -500,
      horizonMonths: 1,
      oneTimeIncome: [
        AssetCashflowDatedEntry(date: DateTime(2026, 6, 17), amount: 1000),
      ],
    );
    expect(forecast.hasShortfall, isTrue);
    expect(forecast.firstShortfallDate, anchor);
    expect(forecast.months.single.firstShortfallDate, anchor);
    expect(forecast.worstBalance, -500);
    expect(forecast.months.single.closingBalance, 500);
    expect(forecast.shortfallRecoveryAmount, 500);
  });

  test('negative opening without events carries into the next month', () {
    final forecast = AssetCashflowForecastService.project(
      asOf: anchor,
      startingBalance: -500,
      horizonMonths: 2,
    );
    expect(forecast.firstShortfallDate, anchor);
    expect(forecast.months[0].firstShortfallDate, anchor);
    expect(forecast.months[1].firstShortfallDate, DateTime(2026, 7, 1));
    expect(forecast.months.every((month) => month.isShortfall), isTrue);
  });

  test('negative monthly opening remains flagged if first-day income recovers',
      () {
    final forecast = AssetCashflowForecastService.project(
      asOf: anchor,
      startingBalance: -500,
      horizonMonths: 2,
      oneTimeIncome: [
        AssetCashflowDatedEntry(date: DateTime(2026, 7, 1), amount: 1000),
      ],
    );
    expect(forecast.firstShortfallDate, anchor);
    expect(forecast.months[1].firstShortfallDate, DateTime(2026, 7, 1));
    expect(forecast.months[1].worstBalance, -500);
    expect(forecast.months[1].closingBalance, 500);
  });

  test('zero and positive opening controls remain without shortfall', () {
    for (final opening in <double>[0, 500]) {
      final forecast = AssetCashflowForecastService.project(
        asOf: anchor,
        startingBalance: opening,
        horizonMonths: 1,
      );
      expect(forecast.hasShortfall, isFalse);
      expect(forecast.months.single.firstShortfallDate, isNull);
    }
  });

  test('same-day A/B both record negative opening and keep income split', () {
    final scenarios = AssetCashflowForecastService.projectScenarios(
      asOf: anchor,
      startingBalance: -500,
      horizonMonths: 1,
      oneTimeIncome: [AssetCashflowDatedEntry(date: anchor, amount: 1000)],
    );
    expect(scenarios.hasAnchorDayIncome, isTrue);
    expect(scenarios.advisoryForecast, isNull);
    expect(scenarios.alreadyReflected.firstShortfallDate, anchor);
    expect(scenarios.notYetReflected.firstShortfallDate, anchor);
    expect(scenarios.alreadyReflected.months.single.closingBalance, -500);
    expect(scenarios.notYetReflected.months.single.closingBalance, 500);
  });
}
