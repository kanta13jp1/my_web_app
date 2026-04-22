import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/feature_strategy_monitor.dart';
import 'package:my_web_app/services/feature_strategy_monitor_service.dart';

void main() {
  test('buildReport creates AI strategy signals and consolidation candidates',
      () {
    final report = const FeatureStrategyMonitorService().buildReport(
      catalog: const <FeatureStrategyCatalogItem>[
        FeatureStrategyCatalogItem(
          id: 'task-board',
          sectionId: 'work',
          title: 'タスクボード',
          subtitle: '今日の仕事を整理する',
          keywords: <String>['仕事', 'ボード'],
        ),
        FeatureStrategyCatalogItem(
          id: 'task-kanban',
          sectionId: 'work',
          title: 'タスクかんばん',
          subtitle: '仕事の流れを整理する',
          keywords: <String>['仕事', 'かんばん'],
        ),
        FeatureStrategyCatalogItem(
          id: 'asset-training',
          sectionId: 'money',
          title: '浪費トレーニング',
          subtitle: '支出を見直す',
          keywords: <String>['資産', '浪費'],
        ),
      ],
      recentToolIds: <String>['task-board'],
      sectionNamesById: <String, String>{
        'work': '仕事',
        'money': 'お金',
      },
      focusActionStatsByFeatureId: const <String,
          FeatureStrategyFocusActionStats>{
        'asset-training': FeatureStrategyFocusActionStats(
          featureId: 'asset-training',
          completedDaysLast7: 2,
          deferredDaysLast7: 1,
          currentStreakDays: 2,
          lastCompletedAt: null,
        ),
      },
      monitoredAt: DateTime(2026, 4, 22, 9, 15),
    );

    expect(report.signals, hasLength(3));
    expect(report.portfolioPlan.kgi, contains('全機能'));
    expect(report.consolidationCandidates, hasLength(1));
    expect(
      report.lifeCapitalSummaries,
      hasLength(FeatureLifeCapitalResource.values.length),
    );
    expect(report.lifeCapitalCoverageRatio, greaterThan(0));
    expect(report.highWasteReductionCount, greaterThan(0));
    expect(
      report.signals
          .singleWhere((signal) => signal.featureId == 'asset-training')
          .lifeCapitalResource,
      FeatureLifeCapitalResource.money,
    );
    expect(
      report.portfolioPlan.metrics.map((metric) => metric.csf).join(' / '),
      contains('浪費'),
    );
    expect(report.focusRecommendation, isNotNull);
    expect(report.focusRecommendation!.featureId, 'asset-training');
    expect(report.focusRecommendation!.action, contains('今日'));
    expect(report.focusRecommendation!.rationale, contains('あと1日'));
    expect(
      report.focusRecommendation!.actionStats.completedDaysLast7,
      2,
    );
    expect(report.focusRecommendation!.actionStats.isHabitStable, isFalse);
    expect(report.focusActionsCompletedLast7, 2);
    expect(
      report.focusRecommendation!.parkedResourceCount,
      greaterThanOrEqualTo(0),
    );
    expect(
      report.portfolioPlan.metrics.map((metric) => metric.kpi).join(' / '),
      contains('今日の低ハードル1手'),
    );
    expect(
      report.portfolioPlan.metrics.map((metric) => metric.kpi).join(' / '),
      contains('7日内の低ハードル完了'),
    );
    expect(
      report.portfolioPlan.metrics.map((metric) => metric.kpi).join(' / '),
      contains('次へ進むための習慣化証跡'),
    );
    expect(
      report.consolidationCandidates.single.summary,
      contains('タスクボード'),
    );
  });
}
