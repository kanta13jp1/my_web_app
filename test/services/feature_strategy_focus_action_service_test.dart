import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/feature_strategy_monitor.dart';
import 'package:my_web_app/models/kgi_csf_kpi.dart';
import 'package:my_web_app/services/feature_strategy_focus_action_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryFocusActionRepository
    implements FeatureStrategyFocusActionRepository {
  final List<FeatureStrategyFocusActionState> states;
  final List<FeatureStrategyFocusActionState> upserted =
      <FeatureStrategyFocusActionState>[];

  _MemoryFocusActionRepository({
    List<FeatureStrategyFocusActionState> initialStates =
        const <FeatureStrategyFocusActionState>[],
  }) : states = List<FeatureStrategyFocusActionState>.from(initialStates);

  @override
  Future<List<FeatureStrategyFocusActionState>> loadRecentActionStates({
    required Iterable<String> featureIds,
    required DateTime startDate,
    required DateTime endDate,
    int limit = 500,
  }) async {
    final ids = featureIds.toSet();
    const service = FeatureStrategyFocusActionService();
    final startKey = service.formatDateKey(startDate);
    final endKey = service.formatDateKey(endDate);
    return states
        .where(
          (state) =>
              ids.contains(state.featureId) &&
              state.dateKey.compareTo(startKey) >= 0 &&
              state.dateKey.compareTo(endKey) <= 0,
        )
        .take(limit)
        .toList(growable: false);
  }

  @override
  Future<void> upsertActionState({
    required FeatureStrategyFocusRecommendation recommendation,
    required FeatureStrategyFocusActionState state,
  }) async {
    upserted.add(state);
    states.removeWhere(
      (item) =>
          item.featureId == state.featureId && item.dateKey == state.dateKey,
    );
    states.add(state.copyWith(cloudSynced: true));
  }
}

void main() {
  const service = FeatureStrategyFocusActionService();
  const recommendation = FeatureStrategyFocusRecommendation(
    resource: FeatureLifeCapitalResource.time,
    label: '時間',
    featureId: 'life-command',
    featureName: 'ライフ司令塔',
    sectionName: 'Home',
    csf: '低ハードルから習慣化する',
    kpi: '今日の低ハードル実行 1回',
    action: 'ライフ司令塔を今日1回だけ開く',
    rationale: '時間の浪費を先に止めるため',
    monitoringCadence: '毎日',
    progress: 0.4,
    parkedResourceCount: 5,
    parkedFeatureCount: 12,
    actionStats: FeatureStrategyFocusActionStats(
      featureId: 'life-command',
      completedDaysLast7: 0,
      deferredDaysLast7: 0,
      currentStreakDays: 0,
      lastCompletedAt: null,
    ),
    plan: KgiCsfKpiPlan(
      domain: '時間 / 今日の1手',
      kgi: '低ハードル行動を習慣化する',
      actualLabel: '0件',
      targetLabel: '1件',
      progress: 0,
      metrics: <KgiCsfKpiMetric>[],
    ),
  );

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('loads pending state before any action is recorded', () async {
    final state = await service.loadState(
      recommendation,
      now: DateTime(2026, 4, 23, 8),
    );

    expect(state.featureId, 'life-command');
    expect(state.dateKey, '2026-04-23');
    expect(state.completed, isFalse);
    expect(state.deferred, isFalse);
    expect(state.completionStreakDays, 0);
  });

  test('markCompleted stores today and increments streak', () async {
    final completed = await service.markCompleted(
      recommendation,
      now: DateTime(2026, 4, 23, 8),
    );
    final loaded = await service.loadState(
      recommendation,
      now: DateTime(2026, 4, 23, 21),
    );

    expect(completed.completed, isTrue);
    expect(loaded.completed, isTrue);
    expect(loaded.deferred, isFalse);
    expect(loaded.completionStreakDays, 1);
  });

  test('markCompleted syncs the closed action to a cloud repository', () async {
    final repository = _MemoryFocusActionRepository();
    final syncedService = FeatureStrategyFocusActionService(
      actionRepository: repository,
    );

    final completed = await syncedService.markCompleted(
      recommendation,
      now: DateTime(2026, 4, 23, 8),
    );

    expect(completed.completed, isTrue);
    expect(completed.cloudSynced, isTrue);
    expect(repository.upserted, hasLength(1));
    expect(repository.upserted.single.featureId, 'life-command');
    expect(repository.upserted.single.dateKey, '2026-04-23');
  });

  test('completion streak counts consecutive completed days', () async {
    await service.markCompleted(
      recommendation,
      now: DateTime(2026, 4, 21, 8),
    );
    await service.markCompleted(
      recommendation,
      now: DateTime(2026, 4, 22, 8),
    );
    final loaded = await service.loadState(
      recommendation,
      now: DateTime(2026, 4, 23, 8),
    );

    expect(loaded.completed, isFalse);
    expect(loaded.completionStreakDays, 2);
  });

  test('deferToday closes the action without counting as completion', () async {
    final deferred = await service.deferToday(
      recommendation,
      now: DateTime(2026, 4, 23, 8),
    );

    expect(deferred.completed, isFalse);
    expect(deferred.deferred, isTrue);
    expect(deferred.completionStreakDays, 0);
  });

  test('loadStatsByFeatureIds summarizes seven-day completion feedback',
      () async {
    await service.markCompleted(
      recommendation,
      now: DateTime(2026, 4, 21, 8),
    );
    await service.deferToday(
      recommendation,
      now: DateTime(2026, 4, 22, 8),
    );
    await service.markCompleted(
      recommendation,
      now: DateTime(2026, 4, 23, 8),
    );

    final statsByFeature = await service.loadStatsByFeatureIds(
      <String>['life-command'],
      now: DateTime(2026, 4, 23, 21),
    );
    final stats = statsByFeature['life-command']!;

    expect(stats.completedDaysLast7, 2);
    expect(stats.deferredDaysLast7, 1);
    expect(stats.currentStreakDays, 1);
    expect(stats.isHabitStable, isFalse);
    expect(stats.remainingUnlockDays, 1);
    expect(stats.closeRateLast7, greaterThan(0));
  });

  test('loadStatsByFeatureIds merges recent cloud outcomes', () async {
    final syncedService = FeatureStrategyFocusActionService(
      actionRepository: _MemoryFocusActionRepository(
        initialStates: <FeatureStrategyFocusActionState>[
          FeatureStrategyFocusActionState(
            featureId: 'life-command',
            dateKey: '2026-04-22',
            completed: true,
            deferred: false,
            completedAt: DateTime(2026, 4, 22, 8),
            deferredAt: null,
            completionStreakDays: 1,
            cloudSynced: true,
          ),
          FeatureStrategyFocusActionState(
            featureId: 'life-command',
            dateKey: '2026-04-23',
            completed: false,
            deferred: true,
            completedAt: null,
            deferredAt: DateTime(2026, 4, 23, 8),
            completionStreakDays: 1,
            cloudSynced: true,
          ),
        ],
      ),
    );

    final stats = await syncedService.loadStatsByFeatureIds(
      <String>['life-command'],
      now: DateTime(2026, 4, 23, 21),
    );
    final state = await syncedService.loadState(
      recommendation,
      now: DateTime(2026, 4, 23, 21),
    );

    expect(stats['life-command']!.completedDaysLast7, 1);
    expect(stats['life-command']!.deferredDaysLast7, 1);
    expect(state.deferred, isTrue);
    expect(state.cloudSynced, isTrue);
  });

  test('markCompleted removes same-day defer history', () async {
    await service.deferToday(
      recommendation,
      now: DateTime(2026, 4, 23, 8),
    );
    await service.markCompleted(
      recommendation,
      now: DateTime(2026, 4, 23, 9),
    );

    final stats = await service.loadStatsByFeatureIds(
      <String>['life-command'],
      now: DateTime(2026, 4, 23, 21),
    );

    expect(stats['life-command']!.completedDaysLast7, 1);
    expect(stats['life-command']!.deferredDaysLast7, 0);
  });

  test('focus stats unlock after three completed days', () async {
    await service.markCompleted(
      recommendation,
      now: DateTime(2026, 4, 21, 8),
    );
    await service.markCompleted(
      recommendation,
      now: DateTime(2026, 4, 22, 8),
    );
    await service.markCompleted(
      recommendation,
      now: DateTime(2026, 4, 23, 8),
    );

    final stats = await service.loadStatsByFeatureIds(
      <String>['life-command'],
      now: DateTime(2026, 4, 23, 21),
    );

    expect(stats['life-command']!.isHabitStable, isTrue);
    expect(stats['life-command']!.unlockStatusLabel, '次へ進める');
  });
}
