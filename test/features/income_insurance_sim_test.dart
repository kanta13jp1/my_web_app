import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/features/income_insurance_sim/application/income_insurance_controller.dart';
import 'package:my_web_app/features/income_insurance_sim/domain/income_insurance_models.dart';
import 'package:my_web_app/features/income_insurance_sim/income_insurance_sim_container.dart';

void main() {
  group('IncomeInsuranceEngine deterministic boundaries & CSV', () {
    test('0% price decline produces zero payouts and zero erosion', () {
      final result = IncomeInsuranceEngine.simulate(
        const IncomeInsuranceSimulationConfig(
          baseRevenue: 1000,
          annualDeclinePercent: 0,
          years: 5,
          movingAverageWindow: 5,
          fixedBenchmarkRevenue: 1000,
        ),
      );

      expect(result.points.length, 5);
      for (final pt in result.points) {
        expect(pt.actualRevenue, 1000.0);
        expect(pt.movingAverageBenchmark, 1000.0);
        expect(pt.movingAveragePayout, 0.0);
        expect(pt.fixedDirectPayout, 0.0);
        expect(pt.benchmarkErosionPercent, 0.0);
      }
      expect(result.cumulativePayoutGap, 0.0);
    });

    test('100% decline erodes 5-year moving average to zero by year 6', () {
      final result = IncomeInsuranceEngine.simulate(
        const IncomeInsuranceSimulationConfig(
          baseRevenue: 1000,
          annualDeclinePercent: 100,
          years: 6,
          movingAverageWindow: 5,
          coverageLimitRate: 0.9,
          payoutRate: 0.9,
          fixedBenchmarkRevenue: 1000,
          directPaymentSubsidyRate: 0.9,
        ),
      );

      expect(result.points[0].actualRevenue, 0.0);
      expect(result.points[0].movingAverageBenchmark, 1000.0);
      expect(result.points[0].movingAveragePayout, closeTo(810.0, 0.01));
      expect(result.points[1].movingAverageBenchmark, closeTo(800.0, 0.01));
      expect(result.points[1].movingAveragePayout, closeTo(648.0, 0.01));
      expect(result.points[5].movingAverageBenchmark, 0.0);
      expect(result.points[5].movingAveragePayout, 0.0);
      expect(result.points[5].fixedDirectPayout, closeTo(900.0, 0.01));
      expect(result.points[5].benchmarkErosionPercent, 100.0);
    });

    test(
        'multi-year 10% decline shows shrinking moving-avg vs rising fixed pay',
        () {
      final result = IncomeInsuranceEngine.simulate(
        const IncomeInsuranceSimulationConfig(
          baseRevenue: 1000,
          annualDeclinePercent: 10,
          years: 8,
          movingAverageWindow: 3,
          coverageLimitRate: 0.9,
          payoutRate: 0.9,
          fixedBenchmarkRevenue: 1000,
          directPaymentSubsidyRate: 0.9,
        ),
      );

      expect(
        result.points.last.benchmarkErosionPercent,
        greaterThan(result.points[1].benchmarkErosionPercent),
      );
      expect(
        result.points.last.fixedDirectPayout,
        greaterThan(result.points.first.fixedDirectPayout),
      );
      expect(
        result.cumulativeFixedDirectPayout,
        greaterThan(result.cumulativeMovingAveragePayout),
      );
    });

    test('rejects invalid out-of-range configuration cleanly', () {
      expect(
        () => IncomeInsuranceEngine.simulate(
          const IncomeInsuranceSimulationConfig(annualDeclinePercent: 120),
        ),
        throwsArgumentError,
      );
      expect(
        () => IncomeInsuranceEngine.simulate(
          const IncomeInsuranceSimulationConfig(years: 0),
        ),
        throwsArgumentError,
      );
      expect(
        () => IncomeInsuranceEngine.simulate(
          const IncomeInsuranceSimulationConfig(movingAverageWindow: 15),
        ),
        throwsArgumentError,
      );
    });

    test('escapes CSV commas, quotes, and spreadsheet formula prefixes', () {
      final result = IncomeInsuranceEngine.simulate(
        const IncomeInsuranceSimulationConfig(
          scenarioLabel: '=SUM(A1), "米"シナリオ',
          years: 2,
          annualDeclinePercent: 10,
        ),
      );
      final csv = IncomeInsuranceCsvExporter.toCsv(result);
      final lines = csv.trim().split('\n');
      expect(lines.length, 3);
      expect(
        lines.first,
        'year,scenario_label,actual_revenue,moving_avg_benchmark,'
        'moving_avg_trigger_floor,moving_avg_payout,fixed_benchmark,'
        'fixed_direct_payout,payout_gap,benchmark_erosion_percent',
      );
      expect(lines[1], contains('"\'=SUM(A1), ""米""シナリオ"'));
    });
  });

  group('IncomeInsuranceSimContainer UI', () {
    testWidgets(
      'runs presets, handles validation errors, and exports RFC-4180 CSV',
      (final WidgetTester tester) async {
        final exported = <String>[];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: IncomeInsuranceSimContainer(
                clipboardWriter: (final String text) async {
                  exported.add(text);
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('income_sim_chart_canvas')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('income_sim_kpi_card')),
          findsOneWidget,
        );

        final steepPreset = find.byKey(
          const ValueKey<String>('income_sim_preset_steep_decline'),
        );
        await tester.ensureVisible(steepPreset);
        await tester.tap(steepPreset);
        await tester.pumpAndSettle();

        expect(find.textContaining('継続急落シナリオ'), findsWidgets);

        final declineInput = find.byKey(
          const ValueKey<String>('income_sim_decline_input'),
        );
        await tester.ensureVisible(declineInput);
        await tester.enterText(declineInput, '150');

        final runBtn = find.byKey(
          const ValueKey<String>('income_sim_run_button'),
        );
        await tester.ensureVisible(runBtn);
        await tester.tap(runBtn);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('income_sim_error_banner')),
          findsOneWidget,
        );

        await tester.ensureVisible(declineInput);
        await tester.enterText(declineInput, '12.0');
        final yearsInput = find.byKey(
          const ValueKey<String>('income_sim_years_input'),
        );
        await tester.ensureVisible(yearsInput);
        await tester.enterText(yearsInput, '6');

        await tester.ensureVisible(runBtn);
        await tester.tap(runBtn);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('income_sim_error_banner')),
          findsNothing,
        );

        final exportBtn = find.byKey(
          const ValueKey<String>('income_sim_export_csv_button'),
        );
        await tester.ensureVisible(exportBtn);
        await tester.tap(exportBtn);
        await tester.pumpAndSettle();

        expect(exported.length, 1);
        expect(exported.single.trim().split('\n').length, 7);
        expect(
          find.byKey(const ValueKey<String>('income_sim_notice_banner')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('income_sim_csv_preview')),
          findsOneWidget,
        );
      },
    );

    testWidgets('ignores pending clipboard export completion after dispose',
        (final WidgetTester tester) async {
      final completer = Completer<void>();
      final controller = IncomeInsuranceController(
        clipboardWriter: (final String _) => completer.future,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IncomeInsuranceSimContainer(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final exportBtn = find.byKey(
        const ValueKey<String>('income_sim_export_csv_button'),
      );
      await tester.ensureVisible(exportBtn);
      await tester.tap(exportBtn);
      await tester.pump();

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
      );
      controller.dispose();
      completer.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    for (final viewport in const <Size>[Size(360, 800), Size(1280, 800)]) {
      for (final brightness in const <Brightness>[
        Brightness.light,
        Brightness.dark,
      ]) {
        testWidgets(
          'passes a11y guidelines at ${viewport.width.toInt()}x${viewport.height.toInt()} ${brightness.name} 2.0x textScale',
          (final WidgetTester tester) async {
            final semanticsHandle = tester.ensureSemantics();
            tester.view.physicalSize = viewport;
            tester.view.devicePixelRatio = 1.0;
            try {
              await tester.pumpWidget(
                MaterialApp(
                  key: ValueKey<String>(
                    'income_sim_${viewport.width.toInt()}_${brightness.name}',
                  ),
                  theme: brightness == Brightness.dark
                      ? ThemeData.dark()
                      : ThemeData.light(),
                  home: Builder(
                    builder: (final BuildContext context) {
                      return MediaQuery(
                        data: MediaQuery.of(context).copyWith(
                          textScaler: const TextScaler.linear(2.0),
                        ),
                        child: const Scaffold(
                          body: IncomeInsuranceSimContainer(),
                        ),
                      );
                    },
                  ),
                ),
              );
              await tester.pumpAndSettle();

              await expectLater(
                tester,
                meetsGuideline(androidTapTargetGuideline),
              );
              await expectLater(
                tester,
                meetsGuideline(labeledTapTargetGuideline),
              );
              await expectLater(
                tester,
                meetsGuideline(textContrastGuideline),
              );
              expect(tester.takeException(), isNull);
            } finally {
              semanticsHandle.dispose();
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
            }
          },
        );
      }
    }
  });
}
