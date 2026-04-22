import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/life_waste_elimination_service.dart';

void main() {
  test('buildReport creates six KGI/CSF/KPI resource signals', () {
    final report = const LifeWasteEliminationService().buildReport(
      monitoredAt: DateTime(2026, 4, 22, 9, 15),
      timeSlipCount: 1,
      abstinenceSlipCount: 0,
      abstinenceTimeSavedMinutes: 40,
      abstinenceMoneySaved: 3000,
      moneyWaste: 12000,
      pendingCriticalTaskCount: 2,
      coreRitualDoneCount: 2,
      coreRitualTarget: 3,
      todayCompletedCount: 4,
      yesterdayCompletedCount: 4,
      featureTotal: 10,
      featureImproveCount: 2,
      featureProgress: 0.72,
    );

    expect(report.signals, hasLength(6));
    expect(report.plan.kgi, contains('時間・お金・健康・体力・知能・集中力'));
    expect(report.plan.metrics, hasLength(6));
    expect(report.prioritySignals.first.label, isNotEmpty);
    expect(report.nextAction, isNotEmpty);
  });

  test('LifeWasteAiReviewService returns provider review and fallback',
      () async {
    final report = const LifeWasteEliminationService().buildReport(
      monitoredAt: DateTime(2026, 4, 22, 9, 15),
      timeSlipCount: 0,
      abstinenceSlipCount: 0,
      abstinenceTimeSavedMinutes: 60,
      abstinenceMoneySaved: 7000,
      moneyWaste: 0,
      pendingCriticalTaskCount: 0,
      coreRitualDoneCount: 3,
      coreRitualTarget: 3,
      todayCompletedCount: 6,
      yesterdayCompletedCount: 5,
      featureTotal: 10,
      featureImproveCount: 0,
      featureProgress: 1,
    );
    final service = LifeWasteAiReviewService(
      now: () => DateTime(2026, 4, 22, 9, 15),
      invoker: (body) async {
        expect(body['message'].toString(), contains('生命資本スコア'));
        return {'success': true, 'text': '生命資本は順調。次は集中力を守る。'};
      },
    );

    final review = await service.generateReview(report);

    expect(review.isFallback, isFalse);
    expect(review.summary, contains('生命資本'));

    final fallbackService = LifeWasteAiReviewService(
      now: () => DateTime(2026, 4, 22, 9, 15),
      invoker: (_) async => {'success': false, 'message': 'rate limit'},
    );
    final fallback = await fallbackService.generateReview(report);

    expect(fallback.isFallback, isTrue);
    expect(fallback.source, 'local-kpi-engine');
  });
}
