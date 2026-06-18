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

  /// [monthFlows] は対象月に絞り込み済みの収支フロー。
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
  }) {
    final currentMonth = DateTime(now.year, now.month, 1);
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

    final isCurrentMonth =
        currentMonth.year == now.year && currentMonth.month == now.month;
    final elapsedDays = isCurrentMonth
        ? now.day
        : DateTime(currentMonth.year, currentMonth.month + 1, 0).day;

    return AssetWasteTrainingSnapshot(
      month: currentMonth,
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
