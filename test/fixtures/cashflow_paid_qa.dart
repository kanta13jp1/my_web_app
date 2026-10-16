import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:my_web_app/services/asset_cashflow_forecast_service.dart';
import 'package:my_web_app/widgets/asset_cashflow_forecast_card.dart';

SemanticsHandle? qaSemantics;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  qaSemantics = SemanticsBinding.instance.ensureSemantics();
  runApp(
    MaterialApp(
    theme: ThemeData(
      fontFamily: 'NotoSansJP',
      fontFamilyFallback: const ['NotoSansJP', 'NotoSans', 'NotoColorEmoji'],
    ),
    home: const ForecastQa(),
    ),
  );
}

class ForecastQa extends StatefulWidget {
  const ForecastQa({super.key});
  @override
  State<ForecastQa> createState() => _ForecastQaState();
}

class _ForecastQaState extends State<ForecastQa> {
  int horizon = 2;
  @override
  Widget build(BuildContext context) {
    final scenario = Uri.base.queryParameters['scenario'] ?? 'paid';
    final forecast = AssetCashflowForecastService.project(
      asOf: DateTime(2026, 6, 1),
      startingBalance: 1000,
      horizonMonths: horizon,
      recurringOutflow: [
        AssetCashflowRecurringEntry(
          dayOfMonth: 10,
          amount: 2000,
          paidPeriodStart: scenario == 'paid' ? DateTime(2026, 6, 1) : null,
          paidPeriodEndExclusive: scenario == 'paid' ? DateTime(2026, 7, 1) : null,
        ),
      ],
    );
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            const Text('合成データ・将来予測の検証'),
            AssetCashflowForecastCard(
              forecast: forecast,
              currentHorizon: horizon,
              availableHorizons: const [2, 3],
              onHorizonChanged: (value) => setState(() => horizon = value),
            ),
          ],
        ),
      ),
    );
  }
}
