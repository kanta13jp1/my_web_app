import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_waste_training_ai_service.dart';
import 'package:my_web_app/services/asset_waste_training_snapshot_inputs.dart';

void main() {
  Map<String, dynamic> flow(
    String actionType,
    int amount, {
    String description = '',
    String? occurredAt,
  }) {
    return <String, dynamic>{
      'action_type': actionType,
      'amount': amount,
      'description': description,
      if (occurredAt != null) 'occurred_at': occurredAt,
    };
  }

  // 浪費は description に「#浪費」を含むものとする(注入する判定関数)。
  AssetWasteTrainingSnapshot build(
    List<Map<String, dynamic>> flows, {
    DateTime? now,
    int ruleCompletedCount = 2,
    int ruleTargetCount = 5,
    int todayViolationCount = 1,
  }) {
    return AssetWasteTrainingSnapshotInputs.build(
      monthFlows: flows,
      now: now ?? DateTime(2026, 6, 15),
      isExpense: (actionType) => actionType == 'expense',
      wasteCategoryOf: (description, actionType) =>
          description.contains('#浪費') ? '浪費' : null,
      ruleCompletedCount: ruleCompletedCount,
      ruleTargetCount: ruleTargetCount,
      todayViolationCount: todayViolationCount,
      compliantStreakDays: 3,
      lockdownActive: true,
    );
  }

  test('sparse records do not turn unrecorded days into zero-waste days', () {
    final snapshot = build([
      flow('expense', 100, occurredAt: '2026-06-10T09:00:00'),
      flow('expense', 200, occurredAt: '2026-06-10T12:00:00'),
      flow('expense', 300, occurredAt: '2026-06-12T09:00:00', description: '#浪費'),
      flow('expense', 400),
      flow('expense', 500, occurredAt: '2026-06-20T09:00:00'),
      flow('expense', 600, occurredAt: '2026-05-20T09:00:00'),
    ]);
    expect(snapshot.elapsedDays, 15);
    expect(snapshot.recordedExpenseDays, 2);
    expect(snapshot.noWasteDays, 1);
  });

  test('aggregates expenses and waste, ignoring income/transfer', () {
    final snapshot = build([
      flow('expense', 1000, description: 'ランチ'),
      flow(
        'expense',
        2000,
        description: 'ゲーム #浪費',
        occurredAt: '2026-06-10T09:00:00',
      ),
      flow('income', 5000),
      flow('transfer', 3000),
    ]);

    expect(snapshot.totalExpense, 3000);
    expect(snapshot.expenseEntryCount, 2);
    expect(snapshot.wasteExpense, 2000);
    expect(snapshot.wasteEntryCount, 1);
    expect(snapshot.month, DateTime(2026, 6, 1));
    expect(snapshot.monitoredAt, DateTime(2026, 6, 15));
    expect(snapshot.elapsedDays, 15); // 今月 → now.day
  });

  test('noWasteDays counts unique waste days', () {
    final snapshot = build([
      flow(
        'expense',
        1000,
        description: 'A #浪費',
        occurredAt: '2026-06-10T09:00:00',
      ),
      flow(
        'expense',
        1500,
        description: 'B #浪費',
        occurredAt: '2026-06-10T20:00:00',
      ),
      flow(
        'expense',
        800,
        description: 'C #浪費',
        occurredAt: '2026-06-12T12:00:00',
      ),
    ]);

    // 記録のある2日はいずれも浪費分類あり。未記録13日は不明。
    expect(snapshot.wasteEntryCount, 3);
    expect(snapshot.noWasteDays, 0);
    expect(snapshot.recordedExpenseDays, 2);
  });

  test('passes through lockdown metrics and clamps elapsedDays to >= 1', () {
    final snapshot = build(
      const [],
      now: DateTime(2026, 6, 1),
      ruleCompletedCount: 4,
      ruleTargetCount: 6,
      todayViolationCount: 0,
    );

    expect(snapshot.totalExpense, 0);
    expect(snapshot.elapsedDays, 1); // 1日 → max(1, 1)
    expect(snapshot.noWasteDays, 0);
    expect(snapshot.recordedExpenseDays, 0);
    expect(snapshot.ruleCompletedCount, 4);
    expect(snapshot.ruleTargetCount, 6);
    expect(snapshot.todayViolationCount, 0);
    expect(snapshot.lockdownActive, isTrue);
  });

  // --- Phase 3: 給料日サイクル窓 ---

  AssetWasteTrainingSnapshot buildCycle(
    List<Map<String, dynamic>> flows, {
    required DateTime now,
    required DateTime cycleStart,
    required DateTime cycleEndExclusive,
  }) {
    return AssetWasteTrainingSnapshotInputs.build(
      monthFlows: flows,
      now: now,
      cycleStart: cycleStart,
      cycleEndExclusive: cycleEndExclusive,
      isExpense: (actionType) => actionType == 'expense',
      wasteCategoryOf: (description, actionType) =>
          description.contains('#浪費') ? '浪費' : null,
      ruleCompletedCount: 2,
      ruleTargetCount: 5,
      todayViolationCount: 1,
      compliantStreakDays: 3,
      lockdownActive: true,
    );
  }

  test('salary cycle: month=cycleStart and elapsedDays counts from cycle start',
      () {
    final snapshot = buildCycle(
      [
        flow(
          'expense',
          2000,
          description: 'ゲーム #浪費',
          occurredAt: '2026-05-27T09:00:00',
        ),
        flow(
          'expense',
          1000,
          description: 'ランチ',
          occurredAt: '2026-06-10T09:00:00',
        ),
      ],
      now: DateTime(2026, 6, 15),
      cycleStart: DateTime(2026, 5, 25),
      cycleEndExclusive: DateTime(2026, 6, 25),
    );

    expect(snapshot.month, DateTime(2026, 5, 25));
    expect(snapshot.totalExpense, 3000);
    expect(snapshot.wasteExpense, 2000);
    expect(snapshot.elapsedDays, 22); // 5/25→6/15 = 21日 + 1
    expect(snapshot.noWasteDays, 1); // 記録あり・浪費分類なしは6/10だけ
    expect(snapshot.recordedExpenseDays, 2);
  });

  test('ended salary cycle uses the full cycle length for elapsedDays', () {
    final snapshot = buildCycle(
      const [],
      now: DateTime(2026, 7, 10), // サイクル終了後
      cycleStart: DateTime(2026, 5, 25),
      cycleEndExclusive: DateTime(2026, 6, 25),
    );

    expect(snapshot.elapsedDays, 31); // 5/25→6/25 = 31日
    expect(snapshot.month, DateTime(2026, 5, 25));
  });
}
