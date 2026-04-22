import 'package:flutter/material.dart';

import '../services/life_waste_elimination_service.dart';
import 'kgi_csf_kpi_panel.dart';

class LifeWasteEliminationPanel extends StatelessWidget {
  final LifeWasteEliminationReport report;
  final LifeWasteAiReview? aiReview;
  final bool isAiReviewLoading;
  final bool isDark;
  final bool isCompact;

  const LifeWasteEliminationPanel({
    super.key,
    required this.report,
    this.aiReview,
    this.isAiReviewLoading = false,
    this.isDark = false,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? const Color(0xFF111827) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor =
        isDark ? Colors.white.withValues(alpha: 0.68) : const Color(0xFF475569);
    final accent = _scoreColor(report.wasteFreeScore);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isCompact ? 14 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.health_and_safety_outlined,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ライフ浪費ゼロ司令塔',
                        style: TextStyle(
                          color: textColor,
                          fontSize: isCompact ? 16 : 18,
                          fontWeight: FontWeight.w800,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '時間・お金・健康・体力・知能・集中力を生命資本として扱い、浪費をAIで分析して次の改善へ戻します。',
                        style: TextStyle(
                          color: subColor,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _ScoreBadge(score: report.wasteFreeScore, color: accent),
              ],
            ),
            const SizedBox(height: 14),
            KgiCsfKpiPanel(
              plan: report.plan,
              accentColor: accent,
              initiallyExpanded: true,
              dark: isDark,
            ),
            const SizedBox(height: 14),
            _AiReviewBox(
              review: aiReview,
              isLoading: isAiReviewLoading,
              isDark: isDark,
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = isCompact || constraints.maxWidth < 720 ? 1 : 2;
                const spacing = 10.0;
                final width = columns == 1
                    ? constraints.maxWidth
                    : (constraints.maxWidth - spacing) / 2;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    for (final signal in report.signals)
                      SizedBox(
                        width: width,
                        child: _ResourceSignalTile(
                          signal: signal,
                          isDark: isDark,
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: isDark ? 0.10 : 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accent.withValues(alpha: 0.22)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.arrow_forward, color: accent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      report.nextAction,
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _scoreColor(int score) {
    if (score >= 80) return const Color(0xFF0F766E);
    if (score >= 60) return const Color(0xFFF59E0B);
    return const Color(0xFFDC2626);
  }
}

class _ScoreBadge extends StatelessWidget {
  final int score;
  final Color color;

  const _ScoreBadge({required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 72),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        children: [
          Text(
            '$score',
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '生命資本',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _AiReviewBox extends StatelessWidget {
  final LifeWasteAiReview? review;
  final bool isLoading;
  final bool isDark;

  const _AiReviewBox({
    required this.review,
    required this.isLoading,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final border =
        isDark ? Colors.white.withValues(alpha: 0.10) : const Color(0xFFE2E8F0);
    final color = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final textColor = isDark ? Colors.white : const Color(0xFF334155);
    final source = review?.source ?? 'ai-hub provider.chat';
    final summary = review?.summary ?? 'AIが生命資本の浪費リスクを分析しています。';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  review?.isFallback == true
                      ? Icons.auto_awesome_motion_outlined
                      : Icons.auto_awesome,
                  size: 18,
                  color: const Color(0xFF2563EB),
                ),
              const SizedBox(width: 8),
              Text(
                'AI現状分析',
                style: TextStyle(
                  color: textColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  height: 1.5,
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  source,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.62),
                    fontSize: 10,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            summary,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResourceSignalTile extends StatelessWidget {
  final LifeWasteResourceSignal signal;
  final bool isDark;

  const _ResourceSignalTile({
    required this.signal,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final color = _resourceColor(signal.resource);
    final icon = _resourceIcon(signal.resource);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor =
        isDark ? Colors.white.withValues(alpha: 0.68) : const Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  signal.label,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
                ),
              ),
              Text(
                '${(signal.progress * 100).round()}%',
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  height: 1.35,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: signal.progress,
              minHeight: 6,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            signal.currentLabel,
            style: TextStyle(
              color: subColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            signal.nextAction,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  IconData _resourceIcon(LifeWasteResource resource) {
    return switch (resource) {
      LifeWasteResource.time => Icons.schedule,
      LifeWasteResource.money => Icons.savings_outlined,
      LifeWasteResource.health => Icons.favorite_border,
      LifeWasteResource.stamina => Icons.directions_run,
      LifeWasteResource.intelligence => Icons.school_outlined,
      LifeWasteResource.focus => Icons.center_focus_strong,
    };
  }

  Color _resourceColor(LifeWasteResource resource) {
    return switch (resource) {
      LifeWasteResource.time => const Color(0xFF2563EB),
      LifeWasteResource.money => const Color(0xFF0F766E),
      LifeWasteResource.health => const Color(0xFFDC2626),
      LifeWasteResource.stamina => const Color(0xFFF97316),
      LifeWasteResource.intelligence => const Color(0xFF7C3AED),
      LifeWasteResource.focus => const Color(0xFF0EA5E9),
    };
  }
}
