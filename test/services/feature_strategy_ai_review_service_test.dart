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

        final message = body['message'].toString();
        expect(message, contains('${report.totalFeatures}'));
        expect(message, contains('${report.onTrackCount}'));
        expect(message, contains('${report.watchCount}'));
        expect(message, contains('${report.improveCount}'));
        expect(message, contains('${report.consolidationCount}'));
        expect(message, contains('${report.reviewDueCount}'));
        expect(message, contains('${report.reviewOverdueCount}'));
        expect(message, contains('Daily Command'));
        expect(message, contains('Daily Review'));
        expect(message, contains('Locked Lab'));
        expect(message, contains('action='));

        return {
          'success': true,
          'text': '改善優先の機能を週次レビューへ集約し、未利用導線をAI推薦へ戻します。',
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
    expect(review.summary, isNotEmpty);
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
        id: 'daily-review',
        sectionId: 'today',
        title: 'Daily Review',
        subtitle: 'Review the day',
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
