import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
    required this.onScanStatement,
    required this.onEdit,
    required this.onDelete,
    required this.onReviewDecisionChanged,
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
  final VoidCallback onScanStatement;
  final void Function(AssetRecurringFixedCost cost) onEdit;
  final void Function(AssetRecurringFixedCost cost) onDelete;
  final void Function(
    AssetRecurringFixedCost cost,
    AssetSubscriptionReviewDecision decision,
  ) onReviewDecisionChanged;

  static final NumberFormat _yen = NumberFormat('#,##0');

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

  static String reviewDecisionLabel(AssetSubscriptionReviewDecision decision) {
    return switch (decision) {
      AssetSubscriptionReviewDecision.unreviewed => '未判定',
      AssetSubscriptionReviewDecision.keep => '残す',
      AssetSubscriptionReviewDecision.hold => '保留',
      AssetSubscriptionReviewDecision.cancelCandidate => '解約候補',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final availablePresets = _unregisteredPresets();
    final monthlyTotal = costs.fold<double>(
      0,
      (sum, cost) => sum + cost.amount,
    );
    final cancelMonthly = costs
        .where(
          (cost) =>
              cost.subscriptionReviewDecision ==
              AssetSubscriptionReviewDecision.cancelCandidate,
        )
        .fold<double>(0, (sum, cost) => sum + cost.amount);
    final unreviewedCount = costs
        .where(
          (cost) =>
              cost.subscriptionReviewDecision ==
              AssetSubscriptionReviewDecision.unreviewed,
        )
        .length;
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
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    key: const Key('subscription_statement_scan_open'),
                    onPressed: onScanStatement,
                    icon: const Icon(Icons.document_scanner_outlined),
                    label: const Text('明細画像から棚卸し'),
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
              if (costs.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _SummaryChip(
                      label: '月額合計',
                      value: '¥${_yen.format(monthlyTotal)}',
                    ),
                    _SummaryChip(
                      label: '年間合計',
                      value: '¥${_yen.format(monthlyTotal * 12)}',
                    ),
                    if (cancelMonthly > 0)
                      _SummaryChip(
                        label: '解約候補',
                        value: '月 ¥${_yen.format(cancelMonthly)}',
                        color: scheme.errorContainer,
                        foregroundColor: scheme.onErrorContainer,
                      ),
                    if (unreviewedCount > 0)
                      _SummaryChip(
                        label: '未判定',
                        value: '$unreviewedCount件',
                        color: scheme.secondaryContainer,
                        foregroundColor: scheme.onSecondaryContainer,
                      ),
                  ],
                ),
              ],
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  '上の合計は登録サブスクの金額を集計したもので、当サイクルの未払い額ではありません。通常の固定費とは別管理です。解約済み・請求周期・請求先を照合してください。',
                  key: Key('subscription_totals_scope'),
                  style: TextStyle(fontSize: 11, height: 1.5),
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
                        PopupMenuButton<AssetSubscriptionReviewDecision>(
                          key: Key('subscription_review_${cost.id}'),
                          tooltip: '${cost.name} の棚卸し判定',
                          initialValue: cost.subscriptionReviewDecision,
                          onSelected: (decision) =>
                              onReviewDecisionChanged(cost, decision),
                          itemBuilder: (context) => [
                            for (final decision
                                in AssetSubscriptionReviewDecision.values)
                              PopupMenuItem(
                                value: decision,
                                child: Text(reviewDecisionLabel(decision)),
                              ),
                          ],
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: Chip(
                              visualDensity: VisualDensity.compact,
                              label: Text(
                                reviewDecisionLabel(
                                  cost.subscriptionReviewDecision,
                                ),
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

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.value,
    this.color,
    this.foregroundColor,
  });

  final String label;
  final String value;
  final Color? color;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color ?? theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '$label '),
            TextSpan(
              text: value,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        style: theme.textTheme.labelMedium?.copyWith(color: foregroundColor),
      ),
    );
  }
}
