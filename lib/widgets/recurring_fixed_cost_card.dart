import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/asset_liability_workbook.dart';

/// 定期固定費 (家賃・光熱費・通信費など) を一覧表示し、追加/編集/削除を行う
/// 自己完結カード。状態・永続化は資産管理ページが持ち、本ウィジェットは表示と
/// コールバックのみを担う (ページ本体を肥大化させずに単体テスト可能にする)。
class RecurringFixedCostCard extends StatelessWidget {
  const RecurringFixedCostCard({
    super.key,
    required this.costs,
    required this.sourceAccountNames,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  /// 表示する定期固定費 (振替日昇順で渡される想定)。
  final List<AssetRecurringFixedCost> costs;

  /// 振替元口座 ID → 表示名。サブタイトルの「振替元」表示に使う。
  final Map<String, String> sourceAccountNames;

  final VoidCallback onAdd;
  final void Function(AssetRecurringFixedCost cost) onEdit;
  final void Function(AssetRecurringFixedCost cost) onDelete;

  static final NumberFormat _yen = NumberFormat('#,###');

  static String cadenceLabel(AssetRecurringFixedCostCadence cadence) {
    switch (cadence) {
      case AssetRecurringFixedCostCadence.monthly:
        return '毎月';
      case AssetRecurringFixedCostCadence.bimonthlyEvenMonth:
        return '隔月(偶数月)';
      case AssetRecurringFixedCostCadence.bimonthlyOddMonth:
        return '隔月(奇数月)';
    }
  }

  /// 「周期+振替日 / ¥金額 [/ 振替元: 口座]」のサブタイトル文字列を組み立てる。
  /// 定期固定費カードとサブスクカードで同一表記を共有する (フォーマット drift 防止)。
  static String subtitleFor(
    AssetRecurringFixedCost cost,
    Map<String, String> sourceAccountNames,
  ) {
    final buffer = StringBuffer(
      '${cadenceLabel(cost.cadence)}${cost.paymentDay}日 / ¥${_yen.format(cost.amount)}',
    );
    final sourceId = cost.sourceAccountId;
    if (sourceId != null && sourceId.isNotEmpty) {
      final name = sourceAccountNames[sourceId];
      if (name != null && name.isNotEmpty) {
        buffer.write(' / 振替元: $name');
      }
    }
    return buffer.toString();
  }

  String _subtitle(AssetRecurringFixedCost cost) =>
      subtitleFor(cost, sourceAccountNames);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.event_repeat, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '定期固定費',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add),
                    label: const Text('追加'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '家賃・光熱費・通信費など、毎月/隔月に口座振替される固定費を登録すると'
                '資金繰り(見込み残高)に自動で反映されます。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              if (costs.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    '通常の固定費（家賃・光熱費など）は未登録です。サブスクは下の専用一覧で別管理しています。同じ請求を両方へ登録しないでください。',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                for (final cost in costs)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Expanded(
                          // 名称 + 内訳を 1 ノードへまとめて読み上げる。
                          child: Semantics(
                            container: true,
                            label: '${cost.name}、${_subtitle(cost)}',
                            child: MergeSemantics(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cost.name,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    _subtitle(cost),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: '${cost.name} を編集',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => onEdit(cost),
                        ),
                        IconButton(
                          tooltip: '${cost.name} を削除',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => onDelete(cost),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
