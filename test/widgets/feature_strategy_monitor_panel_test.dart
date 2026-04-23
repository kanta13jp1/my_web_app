import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/feature_strategy_monitor.dart';
import 'package:my_web_app/services/feature_strategy_monitor_service.dart';
import 'package:my_web_app/services/feature_strategy_report_snapshot_service.dart';
import 'package:my_web_app/widgets/feature_strategy_monitor_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('FeatureStrategyMonitorPanel renders portfolio and queues', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
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
              monitoringSummary: FeatureStrategyMonitoringSummary(
                cloudSynced: true,
                snapshots: <FeatureStrategyDailySnapshot>[
                  FeatureStrategyDailySnapshot.fromReport(report),
                ],
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
    expect(find.text('レビュー期限'), findsOneWidget);
    expect(find.text('代表導線'), findsOneWidget);
    expect(find.text('統合削減'), findsOneWidget);
    expect(find.text('今日の低ハードル1手'), findsWidgets);
    await tester.pump();
    expect(find.textContaining('7日完了'), findsWidgets);
    expect(find.textContaining('固定 あと'), findsWidgets);
    expect(find.text('1手完了'), findsOneWidget);
    await tester.ensureVisible(find.text('1手完了'));
    await tester.pump();
    await tester.tap(find.text('1手完了'));
    await tester.pumpAndSettle();
    expect(find.text('完了済み'), findsOneWidget);
    expect(find.text('生命資本・浪費ゼロKPI'), findsOneWidget);
    expect(find.text('生命資本別 代表導線レーン'), findsOneWidget);
    expect(find.text('AI戦略レビュー'), findsOneWidget);
    expect(find.text('AI改善キュー'), findsOneWidget);
    expect(find.text('全機能AI監視リスト'), findsOneWidget);
    expect(find.text('Locked Lab'), findsOneWidget);
    expect(find.text('Monitoring snapshots'), findsOneWidget);
    expect(find.text('Cloud sync'), findsOneWidget);
    expect(find.text('改善優先'), findsWidgets);
  });
}
