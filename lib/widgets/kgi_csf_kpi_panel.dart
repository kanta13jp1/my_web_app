import 'package:flutter/material.dart';

import '../models/kgi_csf_kpi.dart';

class KgiCsfKpiPanel extends StatelessWidget {
  final KgiCsfKpiPlan plan;
  final Color accentColor;
  final bool dense;
  final bool initiallyExpanded;
  final bool dark;

  const KgiCsfKpiPanel({
    super.key,
    required this.plan,
    this.accentColor = const Color(0xFF2563EB),
    this.dense = false,
    this.initiallyExpanded = false,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    final surface = dark
        ? Colors.white.withValues(alpha: 0.06)
        : accentColor.withValues(alpha: 0.06);
    final borderColor = accentColor.withValues(alpha: dark ? 0.30 : 0.18);
    final titleColor = dark ? Colors.white : const Color(0xFF0F172A);
    final labelColor =
        dark ? Colors.white.withValues(alpha: 0.72) : const Color(0xFF475569);
    final progress = plan.displayProgress;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(dense ? 10 : 12),
        border: Border.all(color: borderColor),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: EdgeInsets.symmetric(
            horizontal: dense ? 10 : 12,
            vertical: dense ? 0 : 2,
          ),
          childrenPadding: EdgeInsets.fromLTRB(
            dense ? 10 : 12,
            0,
            dense ? 10 : 12,
            dense ? 10 : 12,
          ),
          leading: Icon(
            Icons.account_tree_outlined,
            color: accentColor,
            size: dense ? 18 : 22,
          ),
          title: Text(
            'KGI: ${plan.kgi}',
            maxLines: dense ? 1 : 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: titleColor,
              fontSize: dense ? 12 : 14,
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${plan.domain}: ${plan.actualLabel} / ${plan.targetLabel}',
                  maxLines: dense ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: labelColor,
                    fontSize: dense ? 10 : 12,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: dense ? 5 : 7,
                    backgroundColor: accentColor.withValues(alpha: 0.14),
                    valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                  ),
                ),
              ],
            ),
          ),
          children: [
            for (final metric in plan.metrics) ...[
              _CsfKpiMetricRow(
                metric: metric,
                accentColor: accentColor,
                dense: dense,
                dark: dark,
              ),
              if (metric != plan.metrics.last) SizedBox(height: dense ? 8 : 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _CsfKpiMetricRow extends StatelessWidget {
  final KgiCsfKpiMetric metric;
  final Color accentColor;
  final bool dense;
  final bool dark;

  const _CsfKpiMetricRow({
    required this.metric,
    required this.accentColor,
    required this.dense,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = dark ? Colors.white : const Color(0xFF111827);
    final labelColor =
        dark ? Colors.white.withValues(alpha: 0.66) : const Color(0xFF64748B);
    final valueColor = dark ? Colors.white : const Color(0xFF0F172A);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                'CSF: ${metric.csf}',
                style: TextStyle(
                  color: titleColor,
                  fontSize: dense ? 11 : 13,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${metric.actualLabel}/${metric.targetLabel}',
              style: TextStyle(
                color: valueColor,
                fontSize: dense ? 11 : 13,
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          'KPI: ${metric.kpi}'
          '${metric.remainingLabel == null ? '' : ' / ${metric.remainingLabel}'}',
          style: TextStyle(
            color: labelColor,
            fontSize: dense ? 10 : 12,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
        if (metric.progress != null) ...[
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: metric.progress!.clamp(0, 1).toDouble(),
              minHeight: dense ? 4 : 6,
              backgroundColor: accentColor.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            ),
          ),
        ],
      ],
    );
  }
}
