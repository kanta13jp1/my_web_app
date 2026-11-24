import '../models/asset_liability_workbook.dart';

/// 登録済み口座間移動タスクと自動提案の逆方向衝突を検知するサービス (#3298)。
class AssetTransferConflictService {
  const AssetTransferConflictService._();

  /// アクティブな振替タスクと自動提案の間で、同一口座ペアの逆方向移動が
  /// [maxDayGap] 日以内に存在する場合を衝突として検出する。
  static List<AssetTransferConflict> detectReverseConflicts({
    required List<AssetLiabilityTransferTask> tasks,
    required List<AssetLiabilityTransferSuggestion> suggestions,
    int maxDayGap = 1,
  }) {
    final conflicts = <AssetTransferConflict>[];
    for (final task in tasks) {
      if (task.completed || task.canceled) {
        continue;
      }
      for (final suggestion in suggestions) {
        if (!_isReversePair(task, suggestion)) {
          continue;
        }
        final dayGap = _dayGap(task.dueDate, suggestion.neededBy);
        if (dayGap > maxDayGap) {
          continue;
        }
        final diffAmount = (task.amount - suggestion.amount).abs();
        conflicts.add(
          AssetTransferConflict(
            id: '${task.id}::${suggestion.fromAccountId}::${suggestion.toAccountId}',
            task: task,
            suggestion: suggestion,
            dayGap: dayGap,
            recommendedDifferenceAmount: diffAmount,
            summary: '${task.fromAccountName} → ${task.toAccountName}'
                '（${_formatYen(task.amount)}）と逆方向提案 '
                '${suggestion.fromAccountName} → ${suggestion.toAccountName}'
                '（${_formatYen(suggestion.amount)}）が近接しています。',
          ),
        );
      }
    }
    return List<AssetTransferConflict>.unmodifiable(conflicts);
  }

  static bool _isReversePair(
    AssetLiabilityTransferTask task,
    AssetLiabilityTransferSuggestion suggestion,
  ) {
    final idMatch = task.fromAccountId.trim().isNotEmpty &&
        task.toAccountId.trim().isNotEmpty &&
        suggestion.fromAccountId.trim().isNotEmpty &&
        suggestion.toAccountId.trim().isNotEmpty &&
        task.fromAccountId == suggestion.toAccountId &&
        task.toAccountId == suggestion.fromAccountId;
    if (idMatch) {
      return true;
    }
    final taskFromName = task.fromAccountName.trim();
    final taskToName = task.toAccountName.trim();
    final sugFromName = suggestion.fromAccountName.trim();
    final sugToName = suggestion.toAccountName.trim();
    return taskFromName.isNotEmpty &&
        taskToName.isNotEmpty &&
        taskFromName == sugToName &&
        taskToName == sugFromName;
  }

  static int _dayGap(DateTime? left, DateTime? right) {
    if (left == null || right == null) {
      return 0;
    }
    final l = DateTime.utc(left.year, left.month, left.day);
    final r = DateTime.utc(right.year, right.month, right.day);
    return l.difference(r).inDays.abs();
  }

  static String _formatYen(double amount) {
    final sign = amount < 0 ? '-' : '';
    final digits = amount.abs().round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i += 1) {
      final remaining = digits.length - i;
      buffer.write(digits[i]);
      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write(',');
      }
    }
    return '$sign¥$buffer';
  }
}
