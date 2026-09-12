import 'package:flutter/material.dart';

import '../services/asset_cashflow_statement_service.dart';

/// 月次キャッシュフローパネル (Issue #2474)。
///
/// 純サービス [AssetCashflowStatementService] の集計結果
/// ([AssetCashflowStatement]) を受け取り、
/// 「当月CF (月収 − 月支出)」「年初来累積CF」「直近12か月の黒字/赤字月数」を
/// 描画する自己完結ウィジェット。ページ状態へ依存しないため単体検証できる。
class AssetCashflowStatementCard extends StatelessWidget {
  const AssetCashflowStatementCard({
    super.key,
    required this.statement,
    this.currencyFormatter,
    this.recentMonthsToShow = 6,
  });

  final AssetCashflowStatement statement;

  /// 金額整形 (ページの `_formatYen` を渡す)。null なら簡易整形。
  final String Function(double value)? currencyFormatter;

  /// 明細に表示する直近月数。
  final int recentMonthsToShow;

  static const Color _accent = Color(0xFF4F46E5);
  static const Color _danger = Color(0xFFDC2626);
  static const Color _safe = Color(0xFF059669);
  static const Color _muted = Color(0xFF6B7280);

  String _yen(double value) {
    final formatter = currencyFormatter;
    if (formatter != null) {
      return formatter(value);
    }
    return '¥${value.round()}';
  }

  /// 符号付き整形 (黒字 +, 赤字 −)。
  String _signedYen(double value) {
    final sign = value >= 0 ? '+' : '-';
    return '$sign${_yen(value.abs())}';
  }

  Color _cashflowColor(double? value) {
    if (value == null) {
      return _muted;
    }
    return value >= 0 ? _safe : _danger;
  }

  String _monthLabel(String monthKey) {
    final parts = monthKey.split('-');
    if (parts.length < 2) {
      return monthKey;
    }
    final month = int.tryParse(parts[1]);
    if (month == null) {
      return monthKey;
    }
    return '$month月';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!statement.hasData) {
      return const SizedBox.shrink();
    }

    return Card(
      key: const Key('asset_cashflow_statement_card'),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: _accent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '月次キャッシュフロー',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '月収 − 月支出 = 当月現預金出納 / 純資産増減 (B/S実質損益)',
              style: theme.textTheme.bodySmall?.copyWith(color: _muted),
            ),
            const SizedBox(height: 16),
            _buildCurrentMonth(theme),
            const SizedBox(height: 16),
            _buildSummaryRow(theme),
            if (statement.months.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildRecentMonths(theme),
            ],
            if (statement.hasUntrackedYearToDateMonths) ...[
              const SizedBox(height: 12),
              _buildUntrackedNote(theme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentMonth(ThemeData theme) {
    final current = statement.currentMonth;
    final cashflow = statement.currentMonthCashflow;
    final label = current == null ? '当月' : _monthLabel(current.monthKey);

    if (current == null || !statement.hasCurrentMonthCashflow) {
      return Container(
        key: const Key('asset_cashflow_statement_current_untracked'),
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _muted.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '$label の収入データが未登録のため当月キャッシュフローを計算できません。'
          '収入予定を「受領済み」にすると集計されます。',
          style: theme.textTheme.bodySmall?.copyWith(color: _muted),
        ),
      );
    }

    return Container(
      key: const Key('asset_cashflow_statement_current'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cashflowColor(cashflow).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _cashflowColor(cashflow).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label のキャッシュフロー',
            style: theme.textTheme.bodySmall?.copyWith(color: _muted),
          ),
          const SizedBox(height: 4),
          Text(
            _signedYen(cashflow!),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: _cashflowColor(cashflow),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildInlineFigure(theme, '収入', _yen(current.income!), _safe),
              const SizedBox(width: 16),
              _buildInlineFigure(theme, '支出', _yen(current.expense), _danger),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInlineFigure(
    ThemeData theme,
    String label,
    String value,
    Color color,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: theme.textTheme.bodySmall?.copyWith(color: _muted),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: _buildStatTile(
            theme,
            key: const Key('asset_cashflow_statement_ytd'),
            label: '年初来累積CF',
            value: _signedYen(statement.yearToDateCashflow),
            valueColor: _cashflowColor(statement.yearToDateCashflow),
            caption: '${statement.yearToDateTrackedMonths}か月分',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatTile(
            theme,
            key: const Key('asset_cashflow_statement_counts'),
            label: '直近${statement.windowMonths}か月',
            value: '黒字 ${statement.surplusMonthCount} / '
                '赤字 ${statement.deficitMonthCount}',
            valueColor:
                statement.surplusMonthCount >= statement.deficitMonthCount
                    ? _safe
                    : _danger,
            caption: '集計 ${statement.trackedMonthCount}か月',
          ),
        ),
      ],
    );
  }

  Widget _buildStatTile(
    ThemeData theme, {
    required Key key,
    required String label,
    required String value,
    required Color valueColor,
    required String caption,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _muted.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(color: _muted),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            style: theme.textTheme.labelSmall?.copyWith(color: _muted),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentMonths(ThemeData theme) {
    final months = statement.months.reversed
        .take(recentMonthsToShow)
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '月別明細',
          style: theme.textTheme.bodySmall?.copyWith(
            color: _muted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        for (final month in months) _buildMonthRow(theme, month),
      ],
    );
  }

  Widget _buildMonthRow(ThemeData theme, AssetCashflowMonth month) {
    final cashflow = month.cashflow;
    final displayCashflow = month.displayCashflow;
    final usesEstimate = month.usesNetWorthEstimate;
    final detail = cashflow != null
        ? '収入 ${_yen(month.income!)} / 支出 ${_yen(month.expense)}'
        : usesEstimate
            ? '純資産差からの推定CF（評価損益・口座追加等を含む）'
            : '収入未登録';
    final amount = displayCashflow == null
        ? '—'
        : '${usesEstimate ? '≈' : ''}${_signedYen(displayCashflow)}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final monthLabel = SizedBox(
            width: 48,
            child: Text(
              _monthLabel(month.monthKey),
              style: theme.textTheme.bodyMedium,
            ),
          );
          final detailLabel = Text(
            detail,
            key: usesEstimate
                ? Key('asset_cashflow_statement_estimate_${month.monthKey}')
                : null,
            style: theme.textTheme.bodySmall?.copyWith(color: _muted),
          );
          final amountLabel = Text(
            amount,
            key: Key('asset_cashflow_statement_amount_${month.monthKey}'),
            textAlign: TextAlign.end,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: _cashflowColor(displayCashflow),
            ),
          );

          if (constraints.maxWidth < 360) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    monthLabel,
                    Expanded(child: amountLabel),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 48, top: 2),
                  child: detailLabel,
                ),
              ],
            );
          }

          return Row(
            children: [
              monthLabel,
              Expanded(child: detailLabel),
              const SizedBox(width: 8),
              amountLabel,
            ],
          );
        },
      ),
    );
  }

  Widget _buildUntrackedNote(ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, size: 16, color: _muted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '収入が未登録の月 (${statement.yearToDateUntrackedMonths}か月) は'
            '実績の累積・黒字/赤字カウントから除外します。'
            '前月比較できる月は純資産差を推定CFとして表示しますが、'
            '評価損益・口座追加等を含む参考値です。',
            style: theme.textTheme.labelSmall?.copyWith(color: _muted),
          ),
        ),
      ],
    );
  }
}
