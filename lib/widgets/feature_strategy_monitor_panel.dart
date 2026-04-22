import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/feature_strategy_monitor.dart';
import 'kgi_csf_kpi_panel.dart';

class FeatureStrategyMonitorPanel extends StatelessWidget {
  final FeatureStrategyReport report;
  final FeatureStrategyAiReview? aiReview;
  final bool isDark;
  final bool isCompact;

  const FeatureStrategyMonitorPanel({
    super.key,
    required this.report,
    this.aiReview,
    this.isDark = false,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF7C3AED);
    final surface = isDark ? const Color(0xFF111827) : Colors.white;
    final border =
        isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFE5E7EB);
    final titleColor = isDark ? Colors.white : const Color(0xFF111827);
    final mutedColor =
        isDark ? Colors.white.withValues(alpha: 0.68) : const Color(0xFF64748B);
    final monitoredAt =
        DateFormat('yyyy/MM/dd HH:mm').format(report.monitoredAt);
    final priorities = report.prioritySignals;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isCompact ? 14 : 18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: isDark
            ? const []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Icon(Icons.auto_graph, color: accent),
              Text(
                '全機能AI戦略モニタリング',
                style: TextStyle(
                  color: titleColor,
                  fontSize: isCompact ? 16 : 18,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                ),
              ),
              _StatusPill(
                label: '更新 $monitoredAt',
                color: accent,
                dark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'ホームの全機能を対象に、AI分析、KGI、CSF、KPI、改善アクションを自動生成して横断監視します。',
            style: TextStyle(
              color: mutedColor,
              fontSize: isCompact ? 12 : 13,
              fontWeight: FontWeight.w600,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 14),
          KgiCsfKpiPanel(
            plan: report.portfolioPlan,
            accentColor: accent,
            dense: isCompact,
            dark: isDark,
          ),
          if (aiReview != null) ...[
            const SizedBox(height: 12),
            _AiReviewBox(review: aiReview!, accent: accent, dark: isDark),
          ],
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = isCompact || constraints.maxWidth < 720 ? 2 : 4;
              final gap = isCompact ? 8.0 : 10.0;
              final width =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  _SummaryTile(
                    label: '対象機能',
                    value: '${report.totalFeatures}',
                    color: accent,
                    width: width,
                    dark: isDark,
                  ),
                  _SummaryTile(
                    label: 'AI監視率',
                    value: '${(report.aiCoverageRatio * 100).round()}%',
                    color: const Color(0xFF0891B2),
                    width: width,
                    dark: isDark,
                  ),
                  _SummaryTile(
                    label: '要観察',
                    value: '${report.watchCount}',
                    color: const Color(0xFFF59E0B),
                    width: width,
                    dark: isDark,
                  ),
                  _SummaryTile(
                    label: '改善優先',
                    value: '${report.improveCount}',
                    color: const Color(0xFFDC2626),
                    width: width,
                    dark: isDark,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          _SignalAccordion(
            title: 'AI改善キュー',
            subtitle: priorities.isEmpty
                ? '改善優先の機能はありません'
                : '${priorities.length}機能を優先確認',
            signals: priorities,
            initiallyExpanded: priorities.isNotEmpty,
            dark: isDark,
            compact: isCompact,
          ),
          const SizedBox(height: 8),
          _SignalAccordion(
            title: '全機能AI監視リスト',
            subtitle: '${report.totalFeatures}機能をKGI/CSF/KPIで管理',
            signals: report.signals,
            initiallyExpanded: false,
            dark: isDark,
            compact: isCompact,
          ),
        ],
      ),
    );
  }
}

class _AiReviewBox extends StatelessWidget {
  final FeatureStrategyAiReview review;
  final Color accent;
  final bool dark;

  const _AiReviewBox({
    required this.review,
    required this.accent,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = dark ? Colors.white : const Color(0xFF111827);
    final labelColor =
        dark ? Colors.white.withValues(alpha: 0.68) : const Color(0xFF64748B);
    final sourceColor =
        review.isFallback ? const Color(0xFFF59E0B) : const Color(0xFF059669);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: dark ? 0.16 : 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(Icons.auto_awesome, size: 18, color: accent),
              Text(
                'AI戦略レビュー',
                style: TextStyle(
                  color: titleColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  height: 1.35,
                ),
              ),
              _StatusPill(
                label: review.source,
                color: sourceColor,
                dark: dark,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            review.summary,
            style: TextStyle(
              color: labelColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final double width;
  final bool dark;

  const _SummaryTile({
    required this.label,
    required this.value,
    required this.color,
    required this.width,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: dark ? 0.18 : 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: dark
                    ? Colors.white.withValues(alpha: 0.70)
                    : const Color(0xFF64748B),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                color: dark ? Colors.white : color,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignalAccordion extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<FeatureStrategySignal> signals;
  final bool initiallyExpanded;
  final bool dark;
  final bool compact;

  const _SignalAccordion({
    required this.title,
    required this.subtitle,
    required this.signals,
    required this.initiallyExpanded,
    required this.dark,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final border =
        dark ? Colors.white.withValues(alpha: 0.10) : const Color(0xFFE5E7EB);
    final titleColor = dark ? Colors.white : const Color(0xFF111827);
    final subtitleColor =
        dark ? Colors.white.withValues(alpha: 0.62) : const Color(0xFF64748B);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: compact ? 0 : 2,
          ),
          childrenPadding: EdgeInsets.fromLTRB(
            compact ? 10 : 12,
            0,
            compact ? 10 : 12,
            compact ? 10 : 12,
          ),
          title: Text(
            title,
            style: TextStyle(
              color: titleColor,
              fontSize: compact ? 13 : 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              color: subtitleColor,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          children: signals.isEmpty
              ? [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'AI分析上の追加アクションはありません。',
                      style: TextStyle(color: subtitleColor, fontSize: 12),
                    ),
                  ),
                ]
              : [
                  for (final signal in signals) ...[
                    _SignalRow(signal: signal, dark: dark, compact: compact),
                    if (signal != signals.last) const SizedBox(height: 8),
                  ],
                ],
        ),
      ),
    );
  }
}

class _SignalRow extends StatelessWidget {
  final FeatureStrategySignal signal;
  final bool dark;
  final bool compact;

  const _SignalRow({
    required this.signal,
    required this.dark,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = dark ? Colors.white : const Color(0xFF0F172A);
    final labelColor =
        dark ? Colors.white.withValues(alpha: 0.68) : const Color(0xFF64748B);
    final statusColor = _statusColor(signal.status);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: dark ? 0.16 : 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: statusColor.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                signal.featureName,
                style: TextStyle(
                  color: titleColor,
                  fontSize: compact ? 13 : 14,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                ),
              ),
              _StatusPill(
                label: _statusLabel(signal.status),
                color: statusColor,
                dark: dark,
              ),
              _StatusPill(
                label: '${(signal.progress * 100).round()}%',
                color: const Color(0xFF2563EB),
                dark: dark,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${signal.sectionName} / ${signal.aiSummary}',
            style: TextStyle(
              color: labelColor,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '次の改善: ${signal.nextImprovement}',
            style: TextStyle(
              color: titleColor,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final bool dark;

  const _StatusPill({
    required this.label,
    required this.color,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? 0.20 : 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: dark ? Colors.white : color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          height: 1.2,
        ),
      ),
    );
  }
}

Color _statusColor(FeatureStrategyStatus status) {
  return switch (status) {
    FeatureStrategyStatus.onTrack => const Color(0xFF059669),
    FeatureStrategyStatus.watch => const Color(0xFFF59E0B),
    FeatureStrategyStatus.improve => const Color(0xFFDC2626),
  };
}

String _statusLabel(FeatureStrategyStatus status) {
  return switch (status) {
    FeatureStrategyStatus.onTrack => '順調',
    FeatureStrategyStatus.watch => '要観察',
    FeatureStrategyStatus.improve => '改善優先',
  };
}
