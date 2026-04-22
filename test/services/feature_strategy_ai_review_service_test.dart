import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/feature_strategy_monitor.dart';
import 'package:my_web_app/services/feature_strategy_ai_review_service.dart';
import 'package:my_web_app/services/feature_strategy_monitor_service.dart';

void main() {
  test('generateReview returns ai-hub provider summary when available',
      () async {
    final report = _buildReport();
    final service = FeatureStrategyAiReviewService(
      now: () => DateTime(2026, 4, 22, 9, 15),
      invoker: (body) async {
        expect(body['action'], 'provider.chat');
        expect(body['provider'], 'deepinfra');
        expect(body['message'].toString(), contains('総機能数'));
        return {
          'success': true,
          'text': '改善優先の機能を週次レビューに集約し、直近利用のない導線をAI推薦へ戻します。',
        };
      },
    );

    final review = await service.generateReview(report);

    expect(review.isFallback, isFalse);
    expect(review.source, contains('ai-hub provider.chat'));
    expect(review.summary, contains('週次レビュー'));
  });

  test('generateReview falls back when provider fails', () async {
    final report = _buildReport();
    final service = FeatureStrategyAiReviewService(
      now: () => DateTime(2026, 4, 22, 9, 15),
      invoker: (_) async => {'success': false, 'message': 'rate limit'},
    );

    final review = await service.generateReview(report);

    expect(review.isFallback, isTrue);
    expect(review.source, 'local-kpi-engine');
    expect(review.summary, contains('改善優先'));
  });
}

FeatureStrategyReport _buildReport() {
  return const FeatureStrategyMonitorService().buildReport(
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
}
