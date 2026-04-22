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
      monitoredAt: DateTime(2026, 4, 22, 9, 15),
    );

    expect(report.signals, hasLength(3));
    expect(report.portfolioPlan.kgi, contains('全機能'));
    expect(report.consolidationCandidates, hasLength(1));
    expect(
      report.consolidationCandidates.single.summary,
      contains('タスクボード'),
    );
  });
}
