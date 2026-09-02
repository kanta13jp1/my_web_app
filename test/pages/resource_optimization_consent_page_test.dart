import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/resource_optimization.dart';
import 'package:my_web_app/pages/resource_optimization_page.dart';
import 'package:my_web_app/services/resource_optimization_service.dart';

void main() {
  testWidgets('initial view is deterministic and explains AI consent', (
    tester,
  ) async {
    final service = _FakeOptimizer();

    await tester.pumpWidget(
      MaterialApp(home: ResourceOptimizationPage(service: service)),
    );
    await tester.pumpAndSettle();

    expect(service.deterministicCalls, 1);
    expect(service.aiCalls, 0);
    expect(find.textContaining('第三者AIへは送信していません'), findsOneWidget);
    expect(find.textContaining('自己申告proxy'), findsOneWidget);
    expect(find.textContaining('最低7件'), findsOneWidget);
    expect(find.textContaining('分散が必要'), findsOneWidget);
    expect(find.textContaining('Geminiに集計済みデータを外部送信'), findsOneWidget);
    expect(find.textContaining('測定元・proxy判定・分散・十分性'), findsOneWidget);
    expect(find.textContaining('個々の完了記録は送信しません'), findsOneWidget);
    expect(find.text('同意してAI提案を生成'), findsOneWidget);
  });

  testWidgets('AI button submits once and explains quota fallback', (
    tester,
  ) async {
    final service = _FakeOptimizer();

    await tester.pumpWidget(
      MaterialApp(home: ResourceOptimizationPage(service: service)),
    );
    await tester.pumpAndSettle();
    final button = find.byKey(
      const Key('resource_optimization_ai_generate'),
    );
    await tester.ensureVisible(button);

    await tester.tap(button);
    await tester.tap(button);
    await tester.pump();

    expect(service.aiCalls, 1);
    final disabledButton = tester.widget<FilledButton>(button);
    expect(disabledButton.onPressed, isNull);

    service.completeAi('cooldown');
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        '連続利用を防ぐ待機時間中のため',
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(find.text('統計分析', skipOffstage: false), findsOneWidget);
  });

  testWidgets('empty state explains how to create eligible measurements', (
    tester,
  ) async {
    final service = _FakeOptimizer(report: _emptyReport());

    await tester.pumpWidget(
      MaterialApp(home: ResourceOptimizationPage(service: service)),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('「実績を修正」'), findsOneWidget);
    expect(
      find.textContaining('所要時間・疲労度・目標貢献度を自己申告で保存'),
      findsOneWidget,
    );
    expect(find.textContaining('各習慣7件以上かつ値の分散'), findsOneWidget);
  });
}

class _FakeOptimizer extends ResourceOptimizationService {
  _FakeOptimizer({ResourceOptimizationReport? report})
      : report = report ?? _report();

  int deterministicCalls = 0;
  int aiCalls = 0;
  final ResourceOptimizationReport report;
  Completer<ResourceOptimizationAnalysis>? _aiCompleter;

  @override
  Future<ResourceOptimizationReport> analyze({int days = 90}) async {
    deterministicCalls++;
    return report;
  }

  @override
  Future<ResourceOptimizationAnalysis> analyzeWithAiConsent({
    int days = 90,
  }) {
    aiCalls++;
    return (_aiCompleter ??= Completer<ResourceOptimizationAnalysis>()).future;
  }

  void completeAi(String status) {
    _aiCompleter!.complete(
      ResourceOptimizationAnalysis(report: report, aiStatus: status),
    );
  }
}

ResourceOptimizationReport _emptyReport() {
  return const ResourceOptimizationReport(
    generatedBy: 'deterministic',
    windowDays: 90,
    sampleCount: 0,
    timePerformanceCorrelation: null,
    fatiguePerformanceCorrelation: null,
    metrics: [],
    paretoFrontier: [],
    mentorSummary: '',
    recommendations: [],
    scalingPlan: [],
  );
}

ResourceOptimizationReport _report() {
  const metric = HabitResourceMetric(
    habitId: 'habit-1',
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
  return const ResourceOptimizationReport(
    generatedBy: 'deterministic',
    windowDays: 90,
    sampleCount: 8,
    timePerformanceCorrelation: -0.2,
    fatiguePerformanceCorrelation: 0.1,
    metrics: [metric],
    paretoFrontier: [metric],
    mentorSummary: '統計分析による提案です。',
    recommendations: [],
    scalingPlan: [],
  );
}
