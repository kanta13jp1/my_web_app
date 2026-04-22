import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/kgi_csf_kpi.dart';
import 'package:my_web_app/widgets/kgi_csf_kpi_panel.dart';

void main() {
  testWidgets('KgiCsfKpiPanel renders KGI, CSF and numeric KPI', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: KgiCsfKpiPanel(
            initiallyExpanded: true,
            plan: KgiCsfKpiPlan(
              domain: 'テスト領域',
              kgi: '成果を最大化する',
              actualLabel: '7件',
              targetLabel: '10件',
              progress: 0.7,
              metrics: <KgiCsfKpiMetric>[
                KgiCsfKpiMetric(
                  csf: '重要行動',
                  kpi: '完了数',
                  actualLabel: '7件',
                  targetLabel: '10件',
                  progress: 0.7,
                  remainingLabel: '残り3件',
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('KGI: 成果を最大化する'), findsOneWidget);
    expect(find.textContaining('テスト領域: 7件 / 10件'), findsOneWidget);
    expect(find.textContaining('CSF: 重要行動'), findsOneWidget);
    expect(find.textContaining('KPI: 完了数'), findsOneWidget);
  });
}
