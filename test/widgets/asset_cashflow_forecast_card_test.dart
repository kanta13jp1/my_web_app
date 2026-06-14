import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_cashflow_forecast_service.dart';
import 'package:my_web_app/widgets/asset_cashflow_forecast_card.dart';

Future<void> _pump(WidgetTester tester, AssetCashflowForecast forecast) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: AssetCashflowForecastCard(
            forecast: forecast,
            currencyFormatter: (value) => '¥${value.round()}',
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('AssetCashflowForecastCard', () {
    testWidgets('renders the chart and a shortfall warning', (tester) async {
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

      await _pump(tester, forecast);

      expect(
        find.byKey(const Key('asset_cashflow_forecast_card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('asset_cashflow_forecast_chart')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('asset_cashflow_forecast_shortfall')),
        findsOneWidget,
      );
      expect(find.textContaining('残高が不足'), findsOneWidget);
    });

    testWidgets('shows a no-shortfall summary when balances stay positive', (
      tester,
    ) async {
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

      await _pump(tester, forecast);

      expect(
        find.byKey(const Key('asset_cashflow_forecast_card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('asset_cashflow_forecast_chart')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('asset_cashflow_forecast_shortfall')),
        findsNothing,
      );
      expect(
        find.textContaining('残高不足の見込みはありません'),
        findsOneWidget,
      );
    });
  });
}
