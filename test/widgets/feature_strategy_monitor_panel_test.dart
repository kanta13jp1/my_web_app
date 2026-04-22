import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/feature_strategy_monitor.dart';
import 'package:my_web_app/services/feature_strategy_monitor_service.dart';
import 'package:my_web_app/widgets/feature_strategy_monitor_panel.dart';

void main() {
  testWidgets('FeatureStrategyMonitorPanel renders portfolio and queues', (
    tester,
  ) async {
    final report = const FeatureStrategyMonitorService().buildReport(
      catalog: const <FeatureStrategyCatalogItem>[
        FeatureStrategyCatalogItem(
          id: 'daily-command',
          sectionId: 'today',
          title: 'Daily Command',
          subtitle: 'Start the day',
          keywords: <String>['daily'],
        ),
        FeatureStrategyCatalogItem(
          id: 'locked-lab',
          sectionId: 'knowledge',
          title: 'Locked Lab',
          subtitle: 'Needs clear deck',
          keywords: <String>['lab'],
          requiresClearDeck: true,
        ),
      ],
      recentToolIds: const <String>['daily-command'],
      sectionNamesById: const <String, String>{
        'today': 'Today',
        'knowledge': 'Knowledge',
      },
      monitoredAt: DateTime(2026, 4, 22, 9, 15),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FeatureStrategyMonitorPanel(
              report: report,
              aiReview: FeatureStrategyAiReview(
                summary: 'AIが改善優先を確認しました。',
                source: 'ai-hub provider.chat / deepinfra',
                generatedAt: DateTime(2026, 4, 22, 9, 15),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('全機能AI戦略モニタリング'), findsOneWidget);
    expect(find.text('AI監視率'), findsOneWidget);
    expect(find.text('生命資本'), findsOneWidget);
    expect(find.text('浪費削減'), findsOneWidget);
    expect(find.text('今日の低ハードル1手'), findsWidgets);
    expect(find.text('生命資本・浪費ゼロKPI'), findsOneWidget);
    expect(find.text('AI戦略レビュー'), findsOneWidget);
    expect(find.text('AI改善キュー'), findsOneWidget);
    expect(find.text('全機能AI監視リスト'), findsOneWidget);
    expect(find.text('Locked Lab'), findsOneWidget);
    expect(find.text('改善優先'), findsWidgets);
  });
}
