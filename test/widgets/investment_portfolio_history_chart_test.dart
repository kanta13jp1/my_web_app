import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/investment_portfolio_history.dart';
import 'package:my_web_app/services/investment_portfolio_history_service.dart';
import 'package:my_web_app/widgets/investment_portfolio_history_chart.dart';

void main() {
  testWidgets('renders market values and acquisition-cost baseline', (
    tester,
  ) async {
    await _pumpChart(tester, points: [_point(1, 1200), _point(2, 1500)]);

    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.lineBarsData, hasLength(2));
    expect(chart.data.lineBarsData.first.spots.map((spot) => spot.y), [
      1200,
      1500,
    ]);
    expect(chart.data.lineBarsData.last.spots.map((spot) => spot.y), [
      1000,
      1000,
    ]);
    expect(chart.data.lineBarsData.last.dashArray, [6, 4]);
    expect(find.text('評価額'), findsOne);
    expect(find.text('取得額'), findsOne);
    expect(
      find.byKey(const Key('investment_history_dashed_legend')),
      findsOne,
    );
  });

  testWidgets('keeps a single-point chart and tooltip bounds safe', (
    tester,
  ) async {
    await _pumpChart(tester, points: [_point(1, 1200)]);

    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.maxX, 1);
    expect(chart.data.lineBarsData.first.spots, hasLength(1));
    final tooltip = chart.data.lineTouchData.touchTooltipData.getTooltipItems;
    final outsideSpot = LineBarSpot(
      chart.data.lineBarsData.first,
      0,
      const FlSpot(1, 1200),
    );

    expect(tooltip([outsideSpot]), [isNull]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('emits all three period selections', (tester) async {
    final selections = <InvestmentHistoryPeriod>[];
    await _pumpChart(
      tester,
      points: [_point(1, 1200)],
      onPeriodChanged: selections.add,
    );

    await tester.tap(find.text('3年'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('全期間'));
    await tester.pumpAndSettle();

    expect(selections, [
      InvestmentHistoryPeriod.threeYears,
      InvestmentHistoryPeriod.lifetime,
    ]);
  });

  testWidgets('keeps period controls visible when history is empty', (
    tester,
  ) async {
    await _pumpChart(tester, points: const []);

    expect(find.byKey(const Key('investment_history_empty')), findsOne);
    expect(find.text('1年'), findsOne);
    expect(find.text('3年'), findsOne);
    expect(find.text('全期間'), findsOne);
    expect(find.byType(LineChart), findsNothing);
  });
}

Future<void> _pumpChart(
  WidgetTester tester, {
  required List<InvestmentPortfolioHistoryPoint> points,
  ValueChanged<InvestmentHistoryPeriod>? onPeriodChanged,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 520,
          child: InvestmentPortfolioHistoryChart(
            points: points,
            period: InvestmentHistoryPeriod.oneYear,
            onPeriodChanged: onPeriodChanged ?? (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

InvestmentPortfolioHistoryPoint _point(int day, double marketValue) {
  return InvestmentPortfolioHistoryPoint(
    recordedAt: DateTime.utc(2026, 7, day),
    marketValueJpy: marketValue,
    acquisitionCostJpy: 1000,
    pricedAssetCount: 1,
    unpricedAssetCount: 0,
  );
}
