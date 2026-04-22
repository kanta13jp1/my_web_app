import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/feature_strategy_monitor.dart';
import 'package:my_web_app/services/feature_strategy_monitor_service.dart';

void main() {
  test('buildReport creates KGI/CSF/KPI signals for every feature', () {
    const catalog = <FeatureStrategyCatalogItem>[
      FeatureStrategyCatalogItem(
        id: 'daily-command',
        sectionId: 'today',
        title: 'Daily Command',
        subtitle: 'Start the day',
        keywords: ['daily', 'focus'],
      ),
      FeatureStrategyCatalogItem(
        id: 'growth-report',
        sectionId: 'growth',
        title: 'Growth Report',
        subtitle: 'Review acquisition',
        keywords: ['growth'],
      ),
      FeatureStrategyCatalogItem(
        id: 'locked-lab',
        sectionId: 'knowledge',
        title: 'Locked Lab',
        subtitle: 'Needs clear deck',
        keywords: ['lab'],
        requiresClearDeck: true,
      ),
    ];

    final report = const FeatureStrategyMonitorService().buildReport(
      catalog: catalog,
      recentToolIds: const ['daily-command', 'growth-report'],
      sectionNamesById: const {
        'today': 'Today',
        'growth': 'Growth',
        'knowledge': 'Knowledge',
      },
      monitoredAt: DateTime(2026, 4, 22, 9, 15),
    );

    expect(report.totalFeatures, 3);
    expect(report.monitoredFeatures, 3);
    expect(report.portfolioPlan.metrics, hasLength(3));
    expect(report.signals.first.status, FeatureStrategyStatus.onTrack);
    expect(
      report.signals
          .singleWhere((signal) => signal.featureId == 'locked-lab')
          .status,
      FeatureStrategyStatus.improve,
    );
    expect(report.signals.first.aiSummary, contains('AI分析'));
    expect(
      report.prioritySignals.map((signal) => signal.featureId),
      contains('locked-lab'),
    );
  });
}
