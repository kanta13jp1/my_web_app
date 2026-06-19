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

    // 浪費は2日 (10日・12日)。elapsedDays 15 → noWasteDays = 13。
    expect(snapshot.wasteEntryCount, 3);
    expect(snapshot.noWasteDays, 13);
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
    expect(snapshot.noWasteDays, 1);
    expect(snapshot.ruleCompletedCount, 4);
    expect(snapshot.ruleTargetCount, 6);
    expect(snapshot.todayViolationCount, 0);
    expect(snapshot.lockdownActive, isTrue);
  });
}
