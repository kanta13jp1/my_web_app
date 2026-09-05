import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_cashflow_forecast_service.dart';
import 'package:my_web_app/widgets/asset_cashflow_forecast_card.dart';

Future<void> _pump(
  WidgetTester tester,
  AssetCashflowForecast forecast, {
  int? currentHorizon,
  ValueChanged<int>? onHorizonChanged,
  VoidCallback? onReviewPaymentDays,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: AssetCashflowForecastCard(
            forecast: forecast,
            currencyFormatter: (value) => '¥${value.round()}',
            currentHorizon: currentHorizon,
            onHorizonChanged: onHorizonChanged,
            onReviewPaymentDays: onReviewPaymentDays,
          ),
        ),
      ),
    ),
  );
}

AssetCashflowForecast _shortfallForecast() {
  return AssetCashflowForecastService.project(
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
}

void main() {
  group('AssetCashflowForecastCard', () {
    testWidgets('shows a negative monthly low even when month-end recovers', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final forecast = AssetCashflowForecastService.project(
        asOf: DateTime(2026, 9, 5),
        startingBalance: 172928,
        horizonMonths: 1,
        recurringIncome: const [
          AssetCashflowRecurringEntry(dayOfMonth: 25, amount: 421277),
        ],
        recurringOutflow: const [
          AssetCashflowRecurringEntry(dayOfMonth: 15, amount: 233498),
        ],
      );
      expect(forecast.worstBalance, -60570);
      expect(forecast.months.single.closingBalance, 360707);
      await _pump(tester, forecast);
      expect(find.text('● 月末残高'), findsOneWidget);
      expect(find.text('◆ 月内最低残高'), findsOneWidget);
      final details = find.byKey(
        const Key('asset_cashflow_forecast_month_details'),
      );
      await tester.ensureVisible(details);
      await tester.tap(find.text('月別内訳（月末・月内最低）'));
      await tester.pumpAndSettle();
      expect(find.text('2026/9 月末 ¥360707 / 月内最低 ¥-60570'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders the chart and a shortfall warning', (tester) async {
      await _pump(tester, _shortfallForecast());

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
        find.byKey(const Key('asset_cashflow_forecast_shortfall')),
        findsNothing,
      );
      expect(
        find.textContaining('残高不足の見込みはありません'),
        findsOneWidget,
      );
    });

    testWidgets('renders the horizon selector and reports a change', (
      tester,
    ) async {
      var changedTo = 0;
      await _pump(
        tester,
        _shortfallForecast(),
        currentHorizon: 6,
        onHorizonChanged: (months) => changedTo = months,
      );

      expect(
        find.byKey(const Key('asset_cashflow_forecast_horizon_3')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('asset_cashflow_forecast_horizon_12')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('asset_cashflow_forecast_horizon_3')),
      );
      await tester.pump();

      expect(changedTo, 3);
    });

    testWidgets('does not show the horizon selector without a callback', (
      tester,
    ) async {
      await _pump(tester, _shortfallForecast());

      expect(
        find.byKey(const Key('asset_cashflow_forecast_horizon_3')),
        findsNothing,
      );
    });

    testWidgets('warns when the safety margin is breached without a shortfall',
        (
      tester,
    ) async {
      final forecast = AssetCashflowForecastService.project(
        asOf: DateTime(2026, 6, 1),
        startingBalance: 30000,
        horizonMonths: 1,
        recurringOutflow: const [
          AssetCashflowRecurringEntry(dayOfMonth: 10, amount: 25000),
        ],
        safetyMargin: 10000,
      );

      await _pump(tester, forecast);

      expect(
        find.byKey(const Key('asset_cashflow_forecast_shortfall')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('asset_cashflow_forecast_safety_breach')),
        findsOneWidget,
      );
      expect(find.textContaining('安全余裕'), findsOneWidget);
    });

    testWidgets('review-payment-days link fires the callback on a shortfall', (
      tester,
    ) async {
      var tapped = false;
      await _pump(
        tester,
        _shortfallForecast(),
        onReviewPaymentDays: () => tapped = true,
      );

      final link = find.byKey(
        const Key('asset_cashflow_forecast_review_payment_days'),
      );
      expect(link, findsOneWidget);

      await tester.ensureVisible(link);
      await tester.tap(link);
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('exposes a live-region alert and a labelled chart for a11y', (
      tester,
    ) async {
      await _pump(tester, _shortfallForecast());

      // 警告は liveRegion かつ本文を label に持つ(出現/変化を読み上げる)。
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              (widget.properties.liveRegion ?? false) &&
              (widget.properties.label ?? '').contains('残高が不足'),
        ),
        findsOneWidget,
      );
      // グラフは graphic(image)ロール + 要約を含む単一 label を持つ。
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              (widget.properties.image ?? false) &&
              (widget.properties.label ?? '').startsWith('将来残高予測グラフ'),
        ),
        findsOneWidget,
      );
    });
  });
}
