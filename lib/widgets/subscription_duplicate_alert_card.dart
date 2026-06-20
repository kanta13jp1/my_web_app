import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/asset_subscription_duplicate_detector.dart';
import 'subscription_fixed_cost_card.dart';

/// 「同じ提供元のサブスクが複数 = プラン重複の可能性」を提示する自己完結カード。
///
/// 確定的な重複判定ではなく「内容が重複していないか確認」を促す soft な注意喚起。
/// 重複でなければ提供元ごとに「重複ではない (非表示)」で今後表示を止められる。状態・
/// 永続化は資産管理ページが持ち、本ウィジェットは表示とコールバックのみを担う。
/// 検出グループが空のときは何も描画しない (SizedBox.shrink)。
class SubscriptionDuplicateAlertCard extends StatelessWidget {
  const SubscriptionDuplicateAlertCard({
    super.key,
    required this.groups,
    required this.onIgnore,
  });

  /// 検出された重複候補グループ (空なら非表示)。
  final List<SubscriptionDuplicateGroup> groups;

  /// 提供元グループを「重複ではない」として今後の提示から除外する。
  final void Function(SubscriptionDuplicateGroup group) onIgnore;

  static final NumberFormat _yen = NumberFormat('#,###');

  String _memberLine(SubscriptionDuplicateMember member) {
    final gateway = SubscriptionFixedCostCard.gatewayLabel(member.gateway);
    final suffix = gateway == null ? '' : '・$gateway経由';
    return '・${member.name} ¥${_yen.format(member.amount)}$suffix';
  }

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        color: scheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: scheme.onErrorContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '重複の可能性',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: scheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '同じ提供元のサブスクが複数あります。プランが内包・重複していないか確認して'
                'ください (例: ストレージや AI プランの二重契約・別アカウントの契約)。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onErrorContainer,
                ),
              ),
              for (final group in groups)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Semantics(
                    container: true,
                    label: '${group.providerLabel} のサブスク '
                        '${group.members.length}件、重複の可能性',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${group.providerLabel}（${group.members.length}件 / '
                          '月 ¥${_yen.format(group.totalAmount)}）',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: scheme.onErrorContainer,
                          ),
                        ),
                        for (final member in group.members)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              _memberLine(member),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onErrorContainer,
                              ),
                            ),
                          ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => onIgnore(group),
                            child: Text(
                              '重複ではない (非表示)',
                              // 各グループのボタンを読み上げで区別できるよう提供元名を付す。
                              semanticsLabel:
                                  '${group.providerLabel} は重複ではない (非表示)',
                              style: TextStyle(color: scheme.onErrorContainer),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
