import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/kgi_csf_kpi.dart';
import 'package:my_web_app/widgets/kgi_csf_kpi_panel.dart';

// Based on the fixture in test/widgets/kgi_csf_kpi_panel_test.dart at a50bb70.
const _plan = KgiCsfKpiPlan(
  domain: 'テスト領域',
  kgi: '成果を最大化する',
  actualLabel: '7件',
  targetLabel: '10件',
  progress: .7,
  metrics: <KgiCsfKpiMetric>[
    KgiCsfKpiMetric(
      csf: '重要行動',
      kpi: '完了数',
      actualLabel: '7件',
      targetLabel: '10件',
      progress: .7,
      remainingLabel: '残り3件',
    ),
  ],
);

void main() {
  for (final dense in <bool>[false, true]) {
    for (final dark in <bool>[false, true]) {
      testWidgets('panel material and interaction: dense=$dense dark=$dark',
          (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          await tester.pumpWidget(MaterialApp(
            theme: dark ? ThemeData.dark() : ThemeData.light(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: KgiCsfKpiPanel(
                  plan: _plan,
                  accentColor: const Color(0xFF0F766E),
                  initiallyExpanded: true,
                  dense: dense,
                  dark: dark,
                ),
              ),
            ),
          ));
          await tester.pumpAndSettle();

          final title = find.textContaining('KGI: 成果を最大化する');
          final csf = find.textContaining('CSF: 重要行動');
          final kpi = find.textContaining('KPI: 完了数');
          expect(title, findsOneWidget);
          expect(find.textContaining('テスト領域: 7件 / 10件'), findsOneWidget);
          expect(csf, findsOneWidget);
          expect(kpi, findsOneWidget);

          // The tile and its ink must have a clipped Material inside the
          // decorated panel, otherwise an opaque decoration obscures the ink.
          final material = find.descendant(
            of: find.byType(KgiCsfKpiPanel),
            matching: find.byWidgetPredicate((widget) =>
                widget is Material &&
                widget.type == MaterialType.transparency &&
                widget.borderRadius == BorderRadius.circular(dense ? 10 : 12) &&
                widget.clipBehavior == Clip.antiAlias),
          );
          expect(material, findsOneWidget);
          expect(
            find.descendant(of: material, matching: find.byType(ExpansionTile)),
            findsOneWidget,
          );
          expect(
            tester.getSemantics(title).getSemanticsData().hasAction(SemanticsAction.tap),
            isTrue,
          );

          // Exercise press-down as well as activation; no FlutterError handler
          // or exception suppression is installed.
          final press = await tester.startGesture(tester.getCenter(title));
          await tester.pump(const Duration(milliseconds: 50));
          await press.up();
          await tester.pumpAndSettle();
          expect(csf, findsNothing);
          expect(kpi, findsNothing);

          await tester.tap(title);
          await tester.pumpAndSettle();
          expect(csf, findsOneWidget);
          expect(kpi, findsOneWidget);
        } finally {
          semantics.dispose();
        }
      });
    }
  }
}
