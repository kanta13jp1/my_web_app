import 'package:flutter/material.dart';

import '../models/asset_liability_workbook.dart';
import '../services/asset_subscription_catalog.dart';
import 'recurring_fixed_cost_card.dart';

/// AI/クラウド等の月額サブスク (Anthropic / OpenAI / Gemini / GCP / Supabase /
/// Notion など) を登録し、定期固定費 (= 資金繰り上の固定費) として計上するための
/// 自己完結カード。状態・永続化・同期は資産管理ページが持ち、本ウィジェットは表示と
/// コールバックのみを担う (定期固定費カードと同じ設計 / ページ本体を肥大化させない)。
///
/// 登録済みサブスクと未登録のプリセット (テンプレート) を分けて表示し、ワンタップで
/// 追加できる。登録された値は定期固定費と同じパイプラインで資金繰りへ反映される。
class SubscriptionFixedCostCard extends StatelessWidget {
  const SubscriptionFixedCostCard({
    super.key,
    required this.costs,
    required this.sourceAccountNames,
    required this.onAddPreset,
    required this.onAddCustom,
    required this.onEdit,
    required this.onDelete,
    this.presets = AssetSubscriptionCatalog.presets,
  });

  /// 表示する登録済みサブスク (category == subscription / 振替日昇順で渡される想定)。
  final List<AssetRecurringFixedCost> costs;

  /// 振替元口座 ID → 表示名。サブタイトルの「振替元」表示に使う。
  final Map<String, String> sourceAccountNames;

  /// テンプレート一覧 (テスト差し替え用に注入可能)。
  final List<AssetSubscriptionPreset> presets;

  /// プリセットからの追加。
  final void Function(AssetSubscriptionPreset preset) onAddPreset;

  /// テンプレートに無いサブスクを手入力で追加。
  final VoidCallback onAddCustom;
  final void Function(AssetRecurringFixedCost cost) onEdit;
  final void Function(AssetRecurringFixedCost cost) onDelete;

  static String _normalize(String value) =>
      value.replaceAll(RegExp(r'\s+'), '').toLowerCase();

  /// サブタイトルは定期固定費カードの表記に、請求経路 (Apple/Google/au 経由) を付す。
  String _subtitle(AssetRecurringFixedCost cost) {
    final base = RecurringFixedCostCard.subtitleFor(cost, sourceAccountNames);
    final gateway = gatewayLabel(cost.billingGateway);
    return gateway == null ? base : '$base・$gateway経由';
  }

  /// 請求経路の短いラベル。direct (経由なし) は null。
  static String? gatewayLabel(AssetSubscriptionBillingGateway gateway) {
    switch (gateway) {
      case AssetSubscriptionBillingGateway.direct:
        return null;
      case AssetSubscriptionBillingGateway.apple:
        return 'Apple';
      case AssetSubscriptionBillingGateway.googlePlay:
        return 'Google Play';
      case AssetSubscriptionBillingGateway.auKantan:
        return 'auかんたん決済';
    }
  }

  /// 既に登録済み (正規化した名前が一致) のプリセットは候補から除く。
  ///
  /// 名前ベースの簡易判定のため、ユーザーがダイアログでプリセット名を別名へ変更して
  /// 保存した場合はこの一致が外れ、同じプリセットを再登録できてしまう (二重計上の余地)。
  /// 重複は一覧から見える・削除できる低影響のため、現状は名前一致のみで許容する。
  List<AssetSubscriptionPreset> _unregisteredPresets() {
    final registered = costs.map((cost) => _normalize(cost.name)).toSet();
    return [
      for (final preset in presets)
        if (!registered.contains(_normalize(preset.name))) preset,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final availablePresets = _unregisteredPresets();
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
                  Icon(Icons.subscriptions_outlined, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'サブスク (AI/クラウド)',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onAddCustom,
                    icon: const Icon(Icons.add),
                    label: const Text('その他を追加'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Anthropic・OpenAI・Gemini・GCP・Supabase・Notion などの月額サブスクを'
                '登録すると、定期固定費として資金繰り(見込み残高)に自動で反映されます。'
                '金額・請求日は登録後に調整できます。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (availablePresets.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'テンプレートから追加',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final preset in availablePresets)
                      ActionChip(
                        avatar: const Icon(Icons.add, size: 18),
                        label: Text(preset.name),
                        tooltip: preset.note.isEmpty
                            ? '${preset.name} を追加'
                            : '${preset.name}（${preset.note}）を追加',
                        onPressed: () => onAddPreset(preset),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              if (costs.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'まだ登録がありません。テンプレートか「その他を追加」から'
                    'サブスクを登録できます。',
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
