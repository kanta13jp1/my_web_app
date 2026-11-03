import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:my_web_app/services/asset_cashflow_forecast_service.dart';
import 'package:my_web_app/widgets/asset_cashflow_forecast_card.dart';

/// Preserve synthetic test exceptions in the driver response on failure.
class _DiagnosticBinding extends IntegrationTestWidgetsFlutterBinding {
  @override
  void reportExceptionNoticed(foundation.FlutterErrorDetails exception) {
    final data = reportData ??= <String, dynamic>{};
    final errors = data.putIfAbsent(
      'frameworkErrors',
      () => <String>[],
    ) as List<String>;
    if (errors.length < 20) {
      errors.add(exception.toString());
    }
    super.reportExceptionNoticed(exception);
  }
}

/// Synthetic display only: no account, authentication, or persistence.
void main() {
  _DiagnosticBinding();

  testWidgets('conditional forecast and period switch remain labelled',
      (tester) async {
    var horizon = 3;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) {
                final scenarios = AssetCashflowForecastService.projectScenarios(
                  asOf: DateTime(2026, 6, 25),
                  startingBalance: 100,
                  horizonMonths: horizon,
                  recurringIncome: const [
                    AssetCashflowRecurringEntry(dayOfMonth: 25, amount: 200),
                  ],
                  oneTimeOutflow: [
                    AssetCashflowDatedEntry(
                      date: DateTime(2026, 6, 26),
                      amount: 180,
                    ),
                  ],
                );
                return AssetCashflowForecastScenariosCard(
                  scenarios: scenarios,
                  currentHorizon: horizon,
                  onHorizonChanged: (value) => setState(() => horizon = value),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('実際の上下限や確定額ではありません'), findsOneWidget);
    expect(find.textContaining('予定が重複して計上される場合があります'), findsOneWidget);
    expect(find.text('条件A：当日予定入金がすべて起点残高に反映済み'), findsOneWidget);
    expect(find.text('条件B：当日予定入金がすべて起点残高に未反映'), findsOneWidget);
    expect(
      find.byKey(const Key('asset_cashflow_forecast_shortfall_条件A')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('asset_cashflow_forecast_shortfall_条件B')),
      findsNothing,
    );
    final sixMonths = find.byKey(
      const Key('asset_cashflow_forecast_horizon_6_条件A'),
    );
    await tester.ensureVisible(sixMonths);
    await tester.tap(sixMonths);
    await tester.pumpAndSettle();
    expect(find.textContaining('将来残高予測(今後6ヶ月)'), findsNWidgets(2));
  });

  testWidgets('period switch keeps keyboard focus and checked semantics',
      (tester) async {
    final semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);
    var horizon = 3;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) {
                final scenarios = AssetCashflowForecastService.projectScenarios(
                  asOf: DateTime(2026, 6, 25),
                  startingBalance: 100,
                  horizonMonths: horizon,
                  recurringIncome: const [
                    AssetCashflowRecurringEntry(dayOfMonth: 25, amount: 200),
                  ],
                );
                return AssetCashflowForecastScenariosCard(
                  scenarios: scenarios,
                  currentHorizon: horizon,
                  onHorizonChanged: (value) => setState(() => horizon = value),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final six = find.byKey(
      const Key('asset_cashflow_forecast_horizon_6_条件A'),
    );
    final three = find.byKey(
      const Key('asset_cashflow_forecast_horizon_3_条件A'),
    );
    final sixLabel = find.descendant(of: six, matching: find.text('6ヶ月'));
    await tester.ensureVisible(six);
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(six).selected, isFalse);
    final initialSemantics = tester.getSemantics(six).getSemanticsData();
    expect(initialSemantics.label, contains('6ヶ月'));
    expect(initialSemantics.flagsCollection.isChecked, ui.CheckedState.isFalse);
    final before = tester.element(sixLabel);
    final sixFocus = Focus.of(before);
    sixFocus.requestFocus();
    await tester.pumpAndSettle();
    expect(sixFocus.hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(six).selected, isTrue);
    expect(sixFocus.hasPrimaryFocus, isTrue);
    final selectedElement = tester.element(sixLabel);
    expect(identical(before, selectedElement), isFalse);
    final selectedSemantics = tester.getSemantics(six).getSemanticsData();
    expect(selectedSemantics.label, contains('6ヶ月'));
    expect(selectedSemantics.flagsCollection.isChecked, ui.CheckedState.isTrue);
    expect(find.textContaining('将来残高予測(今後6ヶ月)'), findsNWidgets(2));
    final threeLabel = find.descendant(of: three, matching: find.text('3ヶ月'));
    final threeFocus = Focus.of(tester.element(threeLabel));
    threeFocus.requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(three).selected, isTrue);
    expect(threeFocus.hasPrimaryFocus, isTrue);
    expect(identical(selectedElement, tester.element(sixLabel)), isFalse);
    final threeSemantics = tester.getSemantics(three).getSemanticsData();
    expect(threeSemantics.label, contains('3ヶ月'));
    expect(threeSemantics.flagsCollection.isChecked, ui.CheckedState.isTrue);
    final resetSemantics = tester.getSemantics(six).getSemanticsData();
    expect(resetSemantics.flagsCollection.isChecked, ui.CheckedState.isFalse);
    expect(find.textContaining('将来残高予測(今後3ヶ月)'), findsNWidgets(2));
  });

  testWidgets('no anchor-day income retains a single forecast', (tester) async {
    final scenarios = AssetCashflowForecastService.projectScenarios(
      asOf: DateTime(2026, 6, 24),
      startingBalance: 100,
      horizonMonths: 3,
      recurringIncome: const [
        AssetCashflowRecurringEntry(dayOfMonth: 25, amount: 200),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AssetCashflowForecastScenariosCard(scenarios: scenarios),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('asset_cashflow_forecast_conditional_notice')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('asset_cashflow_forecast_card')),
      findsOneWidget,
    );
    expect(find.text('予定が重複して計上される場合があります。'), findsOneWidget);
  });
}
