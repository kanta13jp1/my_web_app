import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/resource_optimization.dart';
import 'package:my_web_app/pages/daily_habits_page.dart';
import 'package:my_web_app/pages/resource_optimization_page.dart';
import 'package:my_web_app/services/resource_optimization_service.dart';
import 'package:my_web_app/widgets/habit_pareto_chart.dart';
import 'package:my_web_app/widgets/habit_resource_metrics_dialog.dart';

void main() {
  test('resource payload distinguishes defaults from self-reported values', () {
    const entry = HabitResourceEntry(
      timeCostMinutes: 20,
      fatigueScore: 4,
      goalContributionScore: 70,
      goalId: 'goal-1',
      goalTitle: '英語力向上',
    );

    final defaultPayload = buildHabitResourceMeasurementPayload(
      entry,
      isSelfReported: false,
    );
    final selfReportedPayload = buildHabitResourceMeasurementPayload(
      entry,
      isSelfReported: true,
    );

    expect(
      defaultPayload['goal_contribution_measurement_source'],
      'habit_default_proxy',
    );
    expect(
      selfReportedPayload['goal_contribution_measurement_source'],
      'self_reported_goal_contribution_proxy',
    );
    expect(selfReportedPayload['goal_contribution_score'], 70);
    expect(selfReportedPayload['goal_id'], 'goal-1');
  });

  testWidgets('resource dialog returns measurable completion data', (
    tester,
  ) async {
    HabitResourceEntry? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                result = await showDialog<HabitResourceEntry>(
                  context: context,
                  builder: (_) => const HabitResourceMetricsDialog(
                    habitTitle: '英語復習',
                    goals: [HabitGoalOption(id: 'goal-1', title: '英語力向上')],
                    initialTimeCostMinutes: 20,
                    initialFatigueScore: 4,
                    initialGoalContributionScore: 70,
                    initialGoalId: 'goal-1',
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('resource_metrics_submit')));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.timeCostMinutes, 20);
    expect(result!.fatigueScore, 4);
    expect(result!.goalContributionScore, 70);
    expect(result!.goalId, 'goal-1');
    expect(result!.goalTitle, '英語力向上');
  });

  testWidgets('resource dialog rejects an invalid time cost', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showDialog<HabitResourceEntry>(
                context: context,
                builder: (_) => const HabitResourceMetricsDialog(
                  habitTitle: '読書',
                  goals: [],
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('resource_time_minutes')),
      '0',
    );
    await tester.tap(find.byKey(const Key('resource_metrics_submit')));
    await tester.pump();

    expect(find.text('1〜1440分で入力してください'), findsOneWidget);
  });

  testWidgets('cancelling resource edit returns no replacement data', (
    tester,
  ) async {
    HabitResourceEntry? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                result = await showDialog<HabitResourceEntry>(
                  context: context,
                  builder: (_) => const HabitResourceMetricsDialog(
                    dialogTitle: '今日の実績を修正',
                    submitLabel: '更新',
                    habitTitle: '読書',
                    goals: [],
                    initialTimeCostMinutes: 25,
                    initialFatigueScore: 4,
                    initialGoalContributionScore: 60,
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });

  testWidgets('Pareto chart renders frontier and comparison points', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: HabitParetoChart(
            metrics: [
              HabitResourceMetric(
                habitId: 'one',
                habitTitle: '短時間習慣',
                goalTitle: null,
                sampleCount: 5,
                averageTimeMinutes: 10,
                averageFatigueScore: 2,
                averageGoalContributionScore: 70,
                resourceCostIndex: 30,
                efficiencyScore: 2.3,
                isParetoOptimal: true,
              ),
              HabitResourceMetric(
                habitId: 'two',
                habitTitle: '比較習慣',
                goalTitle: null,
                sampleCount: 4,
                averageTimeMinutes: 30,
                averageFatigueScore: 5,
                averageGoalContributionScore: 50,
                resourceCostIndex: 80,
                efficiencyScore: 0.6,
                isParetoOptimal: false,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ScatterChart), findsOneWidget);
    final chart = tester.widget<ScatterChart>(find.byType(ScatterChart));
    expect(chart.data.scatterSpots, hasLength(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('optimization report fits a mobile viewport', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const metric = HabitResourceMetric(
      habitId: 'one',
      habitTitle: '英語復習',
      goalTitle: '英語力向上',
      sampleCount: 8,
      averageTimeMinutes: 20,
      averageFatigueScore: 3,
      averageGoalContributionScore: 75,
      resourceCostIndex: 50,
      efficiencyScore: 1.5,
      isParetoOptimal: true,
    );
    const report = ResourceOptimizationReport(
      generatedBy: 'gemini',
      windowDays: 90,
      sampleCount: 8,
      timePerformanceCorrelation: -0.2,
      fatiguePerformanceCorrelation: 0.1,
      metrics: [metric],
      paretoFrontier: [metric],
      mentorSummary: '少ない負荷で成果を維持できています。',
      recommendations: [
        ResourceRecommendation(
          habitId: 'one',
          title: '英語復習',
          reason: '他の候補に支配されない効率です。',
        ),
      ],
      scalingPlan: [
        ResourceScalingStep(
          stage: 1,
          durationDays: 7,
          loadMultiplier: 1.1,
          target: '負荷を10%だけ増やす',
          guardrail: '疲労度が上がったら元に戻す',
        ),
      ],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: ResourceOptimizationPage(service: _FakeOptimizer(report)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('リソース最適化'), findsOneWidget);
    expect(find.text('パレート境界'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('メンター提案'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('メンター提案'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeOptimizer extends ResourceOptimizationService {
  const _FakeOptimizer(this.report);

  final ResourceOptimizationReport report;

  @override
  Future<ResourceOptimizationReport> analyze({int days = 90}) async => report;
}
