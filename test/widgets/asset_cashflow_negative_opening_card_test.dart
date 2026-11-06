import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_cashflow_forecast_service.dart';
import 'package:my_web_app/widgets/asset_cashflow_forecast_card.dart';

void main() {
  testWidgets('negative starting balance is described as existing at start',
      (tester) async {
    final forecast = AssetCashflowForecastService.project(
      asOf: DateTime(2026, 6, 15),
      startingBalance: -500,
      horizonMonths: 1,
      oneTimeIncome: [
        AssetCashflowDatedEntry(date: DateTime(2026, 6, 17), amount: 1000),
      ],
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: AssetCashflowForecastCard(forecast: forecast),
        ),
      ),
    ));
    expect(find.textContaining('登録した起点残高が 0 円未満です'), findsOneWidget);
    expect(find.textContaining('残高不足は回避できる見込み'), findsNothing);
    expect(find.textContaining('頃に残高が不足する見込み'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('both conditional cards disclose initial evaluation',
      (tester) async {
    final anchor = DateTime(2026, 6, 15);
    final scenarios = AssetCashflowForecastService.projectScenarios(
      asOf: anchor,
      startingBalance: -500,
      horizonMonths: 1,
      oneTimeIncome: [AssetCashflowDatedEntry(date: anchor, amount: 1000)],
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: AssetCashflowForecastScenariosCard(scenarios: scenarios),
        ),
      ),
    ));
    expect(find.textContaining('起点残高を先に評価し'), findsOneWidget);
    expect(find.textContaining('登録した起点残高が 0 円未満です'), findsNWidgets(2));
    expect(find.textContaining('残高不足は回避できる見込み'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
