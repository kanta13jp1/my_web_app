import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_cashflow_forecast_service.dart';

/// Synthetic-only proposal, based on public commit a67c93e. No user data.
///
/// The first test characterizes the existing pure service; it is NOT an
/// endorsement of the current warning. The second is deliberately skipped
/// until the product semantics for a negative initial balance are decided.
void main() {
  AssetCashflowForecast project(double opening) =>
      AssetCashflowForecastService.project(
        asOf: DateTime(2026, 6, 15),
        startingBalance: opening,
        horizonMonths: 1,
        oneTimeIncome: [
          AssetCashflowDatedEntry(date: DateTime(2026, 6, 17), amount: 1000),
        ],
      );

  test('characterizes negative opening balance followed by income', () {
    final forecast = project(-500);

    expect(forecast.startingBalance, -500);
    expect(forecast.months, hasLength(1));
    expect(forecast.months.single.openingBalance, -500);
    expect(forecast.months.single.closingBalance, 500);
    expect(forecast.worstBalance, -500);
    expect(forecast.months.single.isShortfall, isTrue);
    expect(forecast.shortfallRecoveryAmount, 500);
    // Current service tracks firstShortfallDate only after a transaction.
    expect(forecast.firstShortfallDate, isNull);
    expect(forecast.months.single.firstShortfallDate, isNull);
    expect(forecast.hasShortfall, isFalse);
  });

  test('zero and positive openings with later income are not shortfalls', () {
    for (final opening in <double>[0, 500]) {
      final forecast = project(opening);
      expect(forecast.worstBalance, opening);
      expect(forecast.firstShortfallDate, isNull);
      expect(forecast.months.single.isShortfall, isFalse);
      expect(forecast.hasShortfall, isFalse);
    }
  });

  test(
    'policy proposal: a negative opening reports shortfall on the anchor day',
    () {
      final forecast = project(-500);

      expect(forecast.worstBalance, -500);
      expect(forecast.shortfallRecoveryAmount, 500);
      expect(forecast.hasShortfall, isTrue);
      expect(forecast.firstShortfallDate, DateTime(2026, 6, 15));
      expect(forecast.months.single.firstShortfallDate, DateTime(2026, 6, 15));
    },
    skip: 'Pending product policy on initial negative balances; do not treat '
        'this expected behavior as an approved specification.',
  );
}diff --git a/test/services/workbook_negative_balance_proposal_test.dart b/test/services/workbook_negative_balance_proposal_test.dart
