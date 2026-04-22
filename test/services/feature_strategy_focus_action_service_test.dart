import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/feature_strategy_monitor.dart';
import 'package:my_web_app/models/kgi_csf_kpi.dart';
import 'package:my_web_app/services/feature_strategy_focus_action_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
}
