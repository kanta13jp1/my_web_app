import 'package:flutter/material.dart';

import '../services/asset_category_budget_service.dart';

/// 予算/カテゴリ予実カード。
///
/// 純関数 [AssetCategoryBudgetService] が作る [CategoryBudgetReport] を受け取り、
/// カテゴリ別の予算 vs 実績(進捗バー + 超過警告)と全体集計を描画する自己完結
/// ウィジェット。ページ状態へ依存しないためウィジェットテストで単体検証できる。
class AssetCategoryBudgetCard extends StatelessWidget {
  const AssetCategoryBudgetCard({
    super.key,
    required this.report,
    this.onEditBudgets,
    this.currencyFormatter,
    this.periodLabel,
  });

  final CategoryBudgetReport report;

  /// 「予算を設定」リンク。null ならリンクを出さない。
  final VoidCallback? onEditBudgets;

  /// 金額整形(ページの `_formatYen` を渡す)。null なら簡易整形。
  final String Function(double value)? currencyFormatter;

  /// 期間ラベル(例: 「5/25〜6/24」)。null なら非表示。
  final String? periodLabel;

  static const Color _accent = Color(0xFF4F46E5);

  String _yen(double value) {
    final formatter = currencyFormatter;
    if (formatter != null) {
      return formatter(value);
    }
    return '¥${value.round()}';
  }

  Color _accentColor(ColorScheme scheme) {
    return scheme.brightness == Brightness.dark ? scheme.primary : _accent;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = _accentColor(scheme);
    return Card(
      key: const Key('asset_category_budget_card'),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.donut_small, color: accent),
                      const SizedBox(width: 8),
                      const Flexible(
                        child: Text(
                          '予算/カテゴリ予実',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (onEditBudgets != null)
                    TextButton(
                      key: const Key('asset_category_budget_edit'),
                      onPressed: onEditBudgets,
                      child: const Text('予算を設定'),
                    ),
                ],
              ),
            ),
            if (periodLabel != null)
              Text(
                periodLabel!,
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            const SizedBox(height: 8),
            if (!report.hasAnyBudget)
              const Padding(
                key: Key('asset_category_budget_empty'),
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'カテゴリ別の予算を設定すると、今月の予算 vs 実績(予実)を表示します。',
                  style: TextStyle(fontSize: 12, height: 1.5),
                ),
              )
            else ...[
              _buildTotalRow(scheme),
              const SizedBox(height: 12),
              for (final row in report.rows) _buildCategoryRow(scheme, row),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTotalRow(ColorScheme scheme) {
    final over = report.totalActual > report.totalBudget;
    final value = report.totalBudget > 0
        ? (report.totalActual / report.totalBudget).clamp(0.0, 1.0).toDouble()
        : 0.0;
    final pct = report.totalBudget > 0
        ? (report.totalActual / report.totalBudget * 100).round()
        : null;
    final accent = _accentColor(scheme);
    final statusColor = over ? scheme.error : scheme.onSurfaceVariant;
    return Semantics(
      container: true,
      liveRegion: over,
      child: MergeSemantics(
        child: Container(
          key: const Key('asset_category_budget_total'),
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (over ? scheme.error : accent).withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 2,
                  children: [
                    const Text(
                      '合計',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${_yen(report.totalActual)} / ${_yen(report.totalBudget)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: over ? scheme.error : null,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 8,
                  backgroundColor: scheme.surfaceContainerHighest,
                  color: over ? scheme.error : accent,
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 2,
                  children: [
                    Text(
                      over
                          ? '予算を ${_yen(report.totalActual - report.totalBudget)} 超過しています'
                          : '残り予算 ${_yen(report.totalRemaining)}',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (pct != null)
                      Text(
                        '消化率 $pct%',
                        key: const Key('asset_category_budget_total_percent'),
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
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

  Widget _buildCategoryRow(ColorScheme scheme, CategoryBudgetRow row) {
    final ratio = row.ratio;
    final over = row.isOver;
    final accent = _accentColor(scheme);
    final statusColor = over ? scheme.error : scheme.onSurfaceVariant;
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 2,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (over) ...[
                        Icon(
                          Icons.warning_amber,
                          color: scheme.error,
                          size: 14,
                        ),
                        const SizedBox(width: 3),
                      ],
                      Flexible(
                        child: Text(
                          row.category,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    row.hasBudget
                        ? '${_yen(row.actual)} / ${_yen(row.budget)}'
                        : '${_yen(row.actual)}(予算未設定)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ),
            if (ratio != null) ...[
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ratio.clamp(0.0, 1.0).toDouble(),
                  minHeight: 6,
                  backgroundColor: scheme.surfaceContainerHighest,
                  color: over ? scheme.error : accent,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                over
                    ? '予算を ${_yen(-row.remaining)} 超過'
                    : '残り ${_yen(row.remaining)}',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.4,
                  color: statusColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
