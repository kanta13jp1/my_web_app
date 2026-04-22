import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/life_waste_elimination_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

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

  test('recordDailySnapshot persists history and alerts repeated waste',
      () async {
    const service = LifeWasteEliminationService();
    final day1 = service.buildReport(
      monitoredAt: DateTime(2026, 4, 21, 9),
      timeSlipCount: 3,
      abstinenceSlipCount: 1,
      abstinenceTimeSavedMinutes: 0,
      abstinenceMoneySaved: 0,
      moneyWaste: 18000,
      pendingCriticalTaskCount: 4,
      coreRitualDoneCount: 0,
      coreRitualTarget: 3,
      todayCompletedCount: 0,
      yesterdayCompletedCount: 3,
      featureTotal: 10,
      featureImproveCount: 4,
      featureProgress: 0.4,
    );
    final day2 = service.buildReport(
      monitoredAt: DateTime(2026, 4, 22, 9),
      timeSlipCount: 2,
      abstinenceSlipCount: 1,
      abstinenceTimeSavedMinutes: 10,
      abstinenceMoneySaved: 0,
      moneyWaste: 12000,
      pendingCriticalTaskCount: 3,
      coreRitualDoneCount: 1,
      coreRitualTarget: 3,
      todayCompletedCount: 1,
      yesterdayCompletedCount: 3,
      featureTotal: 10,
      featureImproveCount: 4,
      featureProgress: 0.5,
    );

    await service.recordDailySnapshot(day1);
    final summary = await service.recordDailySnapshot(day2);
    final reloaded = await service.loadMonitoringSummary();

    expect(summary.historyDays, 2);
    expect(summary.alerts, isNotEmpty);
    expect(
      summary.alerts.any((alert) => alert.detail.contains('2日連続')),
      isTrue,
    );
    expect(reloaded.historyDays, 2);
    expect(reloaded.latest?.dateKey, '2026-04-22');
  });

  test('recordDailySnapshot syncs and merges cloud history', () async {
    final remoteSnapshot = LifeWasteDailySnapshot(
      dateKey: '2026-04-21',
      monitoredAt: DateTime(2026, 4, 21, 9),
      wasteFreeScore: 82,
      resourceScores: const {
        LifeWasteResource.time: 82,
        LifeWasteResource.money: 88,
        LifeWasteResource.health: 90,
      },
      priorityResource: LifeWasteResource.time,
      nextAction: '前日の重点行動',
    );
    final repository = _FakeSnapshotRepository(
      remoteSnapshots: [remoteSnapshot],
    );
    final service = LifeWasteEliminationService(
      snapshotRepository: repository,
    );
    final report = service.buildReport(
      monitoredAt: DateTime(2026, 4, 22, 9),
      timeSlipCount: 0,
      abstinenceSlipCount: 0,
      abstinenceTimeSavedMinutes: 60,
      abstinenceMoneySaved: 5000,
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

    final summary = await service.recordDailySnapshot(report);
    final reloaded = await service.loadMonitoringSummary();

    expect(repository.upserted, hasLength(1));
    expect(repository.upserted.single.dateKey, '2026-04-22');
    expect(summary.cloudSynced, isTrue);
    expect(summary.historyDays, 2);
    expect(summary.snapshots.map((snapshot) => snapshot.dateKey), [
      '2026-04-21',
      '2026-04-22',
    ]);
    expect(reloaded.cloudSynced, isTrue);
    expect(reloaded.historyDays, 2);
  });
}

class _FakeSnapshotRepository implements LifeWasteSnapshotRepository {
  final List<LifeWasteDailySnapshot> remoteSnapshots;
  final List<LifeWasteDailySnapshot> upserted = [];

  _FakeSnapshotRepository({
    required this.remoteSnapshots,
  });

  @override
  Future<List<LifeWasteDailySnapshot>> loadRecentSnapshots({
    int limit = 30,
  }) async {
    return remoteSnapshots.take(limit).toList();
  }

  @override
  Future<void> upsertDailySnapshot(LifeWasteDailySnapshot snapshot) async {
    upserted.add(snapshot);
    remoteSnapshots
      ..removeWhere((item) => item.dateKey == snapshot.dateKey)
      ..add(snapshot)
      ..sort((a, b) => a.dateKey.compareTo(b.dateKey));
  }
}
