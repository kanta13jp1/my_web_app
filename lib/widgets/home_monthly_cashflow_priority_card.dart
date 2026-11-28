import 'package:flutter/material.dart';

class HomeMonthlyCashflowPriorityCard extends StatelessWidget {
  final String monthLabel;
  final String summaryLine;
  final String incomeLabel;
  final String expenseLabel;
  final String netLabel;
  final double netTotal;
  final bool reviewDone;
  final int recordCount;
  final String? lastRecordedLabel;
  final bool isHighlighted;
  final VoidCallback onOpenReview;

  const HomeMonthlyCashflowPriorityCard({
    super.key,
    required this.monthLabel,
    required this.summaryLine,
    required this.incomeLabel,
    required this.expenseLabel,
    required this.netLabel,
    required this.netTotal,
    required this.reviewDone,
    required this.recordCount,
    this.lastRecordedLabel,
    required this.isHighlighted,
    required this.onOpenReview,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor =
        netTotal >= 0 ? const Color(0xFF4CAF50) : const Color(0xFFEF9A9A);
    final cardColor =
        isDark ? const Color(0xFF1E1E1E) : Colors.white.withValues(alpha: 0.92);
    final borderColor = isHighlighted
        ? accentColor.withValues(alpha: 0.7)
        : accentColor.withValues(alpha: 0.22);
    final recordLabel = recordCount == 0 ? '未記録' : '$recordCount件記録';

    return Container(
      key: const Key('home_monthly_cashflow_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: isHighlighted ? 1.6 : 1),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: isHighlighted ? 0.18 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.receipt_long, color: accentColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$monthLabelの収支を最優先',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xDE000000),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      summaryLine,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.6,
                        color: (isDark ? Colors.white : const Color(0xDE000000))
                            .withValues(alpha: 0.78),
                      ),
                    ),
                  ],
                ),
              ),
              if (isHighlighted)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'NOW',
                    style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _CashflowMetricBox(
                label: '収入',
                value: incomeLabel,
                color: const Color(0xFF388E3C),
              ),
              _CashflowMetricBox(
                label: '支出',
                value: expenseLabel,
                color: const Color(0xFFE53935),
              ),
              _CashflowMetricBox(
                label: '差額',
                value: netLabel,
                color: accentColor,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _CashflowStatusChip(
                icon: reviewDone ? Icons.visibility : Icons.priority_high,
                label: reviewDone ? '今月レビュー済み' : '今月レビュー未実施',
                color: reviewDone ? const Color(0xFFB0B0B0) : accentColor,
              ),
              _CashflowStatusChip(
                icon: Icons.edit_note,
                label: recordLabel,
                color: recordCount > 0
                    ? const Color(0xFF6366F1)
                    : const Color(0xFFFF6B35),
              ),
              if (lastRecordedLabel != null)
                _CashflowStatusChip(
                  icon: Icons.schedule,
                  label: '最終記録 $lastRecordedLabel',
                  color: const Color(0xFF3D5AFE),
                ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('home_monthly_cashflow_cta'),
            onPressed: onOpenReview,
            icon: const Icon(Icons.arrow_forward),
            label: Text(recordCount == 0 ? '今月の収支を記録する' : '今月の収支を確認する'),
            style: FilledButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _CashflowMetricBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _CashflowMetricBox({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 104),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _CashflowStatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _CashflowStatusChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
