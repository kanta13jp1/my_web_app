import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:my_web_app/services/asset_cashflow_forecast_service.dart';
import 'package:my_web_app/widgets/asset_cashflow_forecast_card.dart';

/// Preserve synthetic test exceptions in the driver response on failure.
class _DiagnosticBinding extends IntegrationTestWidgetsFlutterBinding {
  @override
  void reportExceptionNoticed(foundation.FlutterErrorDetails exception) {
    final data = reportData ??= <String, dynamic>{};
    data.putIfAbsent('firstExceptionPhase', () => data['phase'] ?? 'unknown');
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
  final binding = _DiagnosticBinding();
  void mark(String phase, WidgetTester tester) {
    final data = binding.reportData ??= <String, dynamic>{};
    data['phase'] = phase;
    data['configuredViewport'] = const String.fromEnvironment('FORECAST_VIEWPORT');
    data['physicalSize'] = tester.view.physicalSize.toString();
    data['devicePixelRatio'] = tester.view.devicePixelRatio;
  }

  testWidgets('conditional forecast and period switch remain labelled',
      (tester) async {
    var horizon = 3;
    mark('before initial pump', tester);
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
    mark('initial settle', tester);
    await tester.pumpAndSettle();
    mark('initial assertions', tester);
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
    mark('before ensureVisible', tester);
    await tester.ensureVisible(sixMonths);
    mark('before tap', tester);
    await tester.tap(sixMonths);
    mark('after tap before settle', tester);
    await tester.pumpAndSettle();
    mark('after final settle', tester);
    expect(find.textContaining('将来残高予測(今後6ヶ月)'), findsNWidgets(2));
  });

  testWidgets('no anchor-day income retains a single forecast', (tester) async {
    mark('single before construction', tester);
    final scenarios = AssetCashflowForecastService.projectScenarios(
      asOf: DateTime(2026, 6, 24),
      startingBalance: 100,
      horizonMonths: 3,
      recurringIncome: const [
        AssetCashflowRecurringEntry(dayOfMonth: 25, amount: 200),
      ],
    );
    mark('single before initial pump', tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AssetCashflowForecastScenariosCard(scenarios: scenarios),
          ),
        ),
      ),
    );
    mark('single settle', tester);
    await tester.pumpAndSettle();
    mark('single assertions', tester);
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
