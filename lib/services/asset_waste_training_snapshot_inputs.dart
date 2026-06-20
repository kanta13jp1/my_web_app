import 'dart:math';

import 'asset_waste_training_ai_service.dart';

/// `_buildWasteTrainingSnapshot` の純粋集計部分を切り出した純関数ビルダー。
///
/// description のパース(浪費カテゴリ判定)・支出判定・借金ロックダウンの集計値は
/// ページから関数/値として注入する(深依存は注入 = 3 手法②)。月内フローと現在時刻
/// から浪費トレーニング指標 [AssetWasteTrainingSnapshot] を組み立てる。スキーマ非依存・
/// 完全テスト可。
class AssetWasteTrainingSnapshotInputs {
  const AssetWasteTrainingSnapshotInputs();

  /// [monthFlows] は対象期間に絞り込み済みの収支フロー。
  ///
  /// [cycleStart] / [cycleEndExclusive] を両方渡すと、集計窓・経過日数を給料日
  /// サイクル `[cycleStart, cycleEndExclusive)` で扱う(資産管理の「今月 = 給料日
  /// サイクル」統一)。どちらか欠けると従来どおり [now] の暦月で扱う(後方互換)。
  static AssetWasteTrainingSnapshot build({
    required List<Map<String, dynamic>> monthFlows,
    required DateTime now,
    required bool Function(String actionType) isExpense,
    required String? Function(String description, String actionType)
        wasteCategoryOf,
    required int ruleCompletedCount,
    required int ruleTargetCount,
    required int todayViolationCount,
    required int compliantStreakDays,
    required bool lockdownActive,
    DateTime? cycleStart,
    DateTime? cycleEndExclusive,
  }) {
    final usingCycle = cycleStart != null && cycleEndExclusive != null;
    final periodStart = usingCycle
        ? DateTime(cycleStart.year, cycleStart.month, cycleStart.day)
        : DateTime(now.year, now.month, 1);
    var totalExpense = 0;
    var wasteExpense = 0;
    var expenseEntryCount = 0;
    var wasteEntryCount = 0;
    final wasteDateKeys = <String>{};

    for (final item in monthFlows) {
      final actionType = item['action_type']?.toString() ?? '';
      if (!isExpense(actionType)) {
        continue;
      }
      final amount = ((item['amount'] as num?)?.toDouble() ?? 0).abs().round();
      totalExpense += amount;
      expenseEntryCount += 1;

      final description = item['description']?.toString() ?? '';
      if (wasteCategoryOf(description, actionType) == null) {
        continue;
      }

      wasteExpense += amount;
      wasteEntryCount += 1;
      final occurredAt = DateTime.tryParse(
        item['occurred_at']?.toString() ?? '',
      )?.toLocal();
      if (occurredAt != null) {
        wasteDateKeys.add(
          '${occurredAt.year}-${occurredAt.month}-${occurredAt.day}',
        );
      }
    }

    final int elapsedDays;
    if (usingCycle) {
      // サイクル内なら開始日からの経過日数、終了済みサイクルなら全日数。
      final nowWithinCycle =
          !now.isBefore(cycleStart) && now.isBefore(cycleEndExclusive);
      final fullCycleDays = cycleEndExclusive.difference(periodStart).inDays;
      elapsedDays = nowWithinCycle
          ? now.difference(periodStart).inDays + 1
          : fullCycleDays;
    } else {
      final isCurrentMonth =
          periodStart.year == now.year && periodStart.month == now.month;
      elapsedDays = isCurrentMonth
          ? now.day
          : DateTime(periodStart.year, periodStart.month + 1, 0).day;
    }

    return AssetWasteTrainingSnapshot(
      month: periodStart,
      monitoredAt: now,
      totalExpense: totalExpense,
      wasteExpense: wasteExpense,
      expenseEntryCount: expenseEntryCount,
      wasteEntryCount: wasteEntryCount,
      noWasteDays: max(0, elapsedDays - wasteDateKeys.length),
      elapsedDays: max(1, elapsedDays),
      ruleCompletedCount: ruleCompletedCount,
      ruleTargetCount: ruleTargetCount,
      todayViolationCount: todayViolationCount,
      compliantStreakDays: compliantStreakDays,
      lockdownActive: lockdownActive,
    );
  }
}
