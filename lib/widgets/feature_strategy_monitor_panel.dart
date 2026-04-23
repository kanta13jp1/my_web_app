import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/feature_strategy_monitor.dart';
import '../services/feature_strategy_focus_action_service.dart';
import '../services/feature_strategy_report_snapshot_service.dart';
import 'kgi_csf_kpi_panel.dart';

typedef FeatureStrategyOpenFeature = Future<void> Function(String featureId);

class FeatureStrategyMonitorPanel extends StatefulWidget {
  final FeatureStrategyReport report;
  final FeatureStrategyAiReview? aiReview;
  final FeatureStrategyMonitoringSummary? monitoringSummary;
  final bool isDark;
  final bool isCompact;
  final FeatureStrategyFocusActionService? focusActionService;
  final FeatureStrategyOpenFeature? onOpenFeature;

  const FeatureStrategyMonitorPanel({
    super.key,
    required this.report,
    this.aiReview,
    this.monitoringSummary,
    this.isDark = false,
    this.isCompact = false,
    this.focusActionService,
    this.onOpenFeature,
  });

  @override
  State<FeatureStrategyMonitorPanel> createState() =>
      _FeatureStrategyMonitorPanelState();
}

class _FeatureStrategyMonitorPanelState
    extends State<FeatureStrategyMonitorPanel> {
  static const _localFocusActionService = FeatureStrategyFocusActionService();

  FeatureStrategyFocusActionService get _focusActionService =>
      widget.focusActionService ?? _localFocusActionService;

  FeatureStrategyFocusActionState? _focusActionState;
  bool _focusActionLoading = false;
  String? _focusActionError;

  @override
  void initState() {
    super.initState();
    _focusActionLoading = widget.report.focusRecommendation != null;
    _loadFocusActionState(showLoading: false);
  }

  @override
  void didUpdateWidget(covariant FeatureStrategyMonitorPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldFeatureId = oldWidget.report.focusRecommendation?.featureId;
    final nextFeatureId = widget.report.focusRecommendation?.featureId;
    if (oldFeatureId != nextFeatureId) {
      _loadFocusActionState();
    }
  }

  Future<void> _loadFocusActionState({bool showLoading = true}) async {
    final recommendation = widget.report.focusRecommendation;
    if (recommendation == null) {
      if (!mounted) return;
      setState(() {
        _focusActionState = null;
        _focusActionLoading = false;
        _focusActionError = null;
      });
      return;
    }

    if (showLoading && mounted) {
      setState(() {
        _focusActionLoading = true;
        _focusActionError = null;
      });
    }

    try {
      final state = await _focusActionService.loadState(recommendation);
      if (!mounted ||
          widget.report.focusRecommendation?.featureId !=
              recommendation.featureId) {
        return;
      }
      setState(() {
        _focusActionState = state;
        _focusActionLoading = false;
        _focusActionError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _focusActionLoading = false;
        _focusActionError = '今日の1手の記録を読み込めませんでした';
      });
    }
  }

  Future<void> _markFocusActionCompleted() async {
    final recommendation = widget.report.focusRecommendation;
    if (recommendation == null || _focusActionLoading) return;
    setState(() {
      _focusActionLoading = true;
      _focusActionError = null;
    });
    try {
      final state = await _focusActionService.markCompleted(recommendation);
      if (!mounted) return;
      setState(() {
        _focusActionState = state;
        _focusActionLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _focusActionLoading = false;
        _focusActionError = '完了を保存できませんでした';
      });
    }
  }

  Future<void> _deferFocusAction() async {
    final recommendation = widget.report.focusRecommendation;
    if (recommendation == null || _focusActionLoading) return;
    setState(() {
      _focusActionLoading = true;
      _focusActionError = null;
    });
    try {
      final state = await _focusActionService.deferToday(recommendation);
      if (!mounted) return;
      setState(() {
        _focusActionState = state;
        _focusActionLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _focusActionLoading = false;
        _focusActionError = '観察扱いを保存できませんでした';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final aiReview = widget.aiReview;
    final isDark = widget.isDark;
    final isCompact = widget.isCompact;
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
            'ホームの全機能を対象に、AI分析、KGI、CSF、KPI、改善アクションを自動生成して横断監視します。時間・お金・健康・体力・知能・集中力の浪費を減らす軸で整理し、類似機能は統合候補として抽象化します。',
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
            _AiReviewBox(review: aiReview, accent: accent, dark: isDark),
          ],
          if (widget.monitoringSummary != null) ...[
            const SizedBox(height: 12),
            _MonitoringHistoryBox(
              summary: widget.monitoringSummary!,
              accent: accent,
              dark: isDark,
              compact: isCompact,
            ),
          ],
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = isCompact || constraints.maxWidth < 720 ? 2 : 3;
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
                    label: '生命資本',
                    value:
                        '${(report.lifeCapitalCoverageRatio * 100).round()}%',
                    color: const Color(0xFF059669),
                    width: width,
                    dark: isDark,
                  ),
                  _SummaryTile(
                    label: '代表導線',
                    value:
                        '${report.lifeCapitalLaneCount}/${FeatureLifeCapitalResource.values.length}',
                    color: const Color(0xFF0D9488),
                    width: width,
                    dark: isDark,
                  ),
                  _SummaryTile(
                    label: '浪費削減',
                    value: '${report.highWasteReductionCount}',
                    color: const Color(0xFFF97316),
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
                    label: 'レビュー期限',
                    value: '${report.reviewDueCount}',
                    color: report.reviewOverdueCount > 0
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF0EA5E9),
                    width: width,
                    dark: isDark,
                  ),
                  _SummaryTile(
                    label: '統合候補',
                    value: '${report.consolidationCount}',
                    color: const Color(0xFF2563EB),
                    width: width,
                    dark: isDark,
                  ),
                  _SummaryTile(
                    label: '統合削減',
                    value: '${report.consolidationWasteMinutesSaved}分',
                    color: const Color(0xFF9333EA),
                    width: width,
                    dark: isDark,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          if (report.focusRecommendation != null) ...[
            _FocusRecommendationCard(
              recommendation: report.focusRecommendation!,
              queuedRecommendation: report.queuedFocusRecommendation,
              dark: isDark,
              compact: isCompact,
              actionState: _focusActionState,
              actionLoading: _focusActionLoading,
              actionError: _focusActionError,
              onComplete: _markFocusActionCompleted,
              onDefer: _deferFocusAction,
            ),
            const SizedBox(height: 8),
          ],
          _RecoveryRoadmapAccordion(
            steps: report.recoveryRoadmap,
            dark: isDark,
            compact: isCompact,
            onOpenFeature: widget.onOpenFeature,
          ),
          const SizedBox(height: 8),
          _LifeCapitalAccordion(
            summaries: report.lifeCapitalSummaries,
            dark: isDark,
            compact: isCompact,
          ),
          const SizedBox(height: 8),
          _LifeCapitalLaneAccordion(
            lanes: report.lifeCapitalConsolidationLanes,
            dark: isDark,
            compact: isCompact,
            onOpenFeature: widget.onOpenFeature,
          ),
          const SizedBox(height: 8),
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
          _ConsolidationAccordion(
            candidates: report.consolidationCandidates,
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

class _MonitoringHistoryBox extends StatelessWidget {
  final FeatureStrategyMonitoringSummary summary;
  final Color accent;
  final bool dark;
  final bool compact;

  const _MonitoringHistoryBox({
    required this.summary,
    required this.accent,
    required this.dark,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final latest = summary.latest;
    final titleColor = dark ? Colors.white : const Color(0xFF0F172A);
    final subColor =
        dark ? Colors.white.withValues(alpha: 0.70) : const Color(0xFF64748B);
    final alertColor =
        summary.needsReview ? const Color(0xFFDC2626) : const Color(0xFF059669);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 11 : 13),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: dark ? 0.14 : 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(Icons.history_toggle_off, size: 18, color: accent),
              Text(
                'Monitoring snapshots',
                style: TextStyle(
                  color: titleColor,
                  fontSize: compact ? 12 : 13,
                  fontWeight: FontWeight.w900,
                  height: 1.35,
                ),
              ),
              _StatusPill(
                label: summary.syncLabel,
                color: summary.cloudSynced ? const Color(0xFF2563EB) : accent,
                dark: dark,
              ),
              _StatusPill(
                label: '${summary.snapshotCount} days',
                color: const Color(0xFF0891B2),
                dark: dark,
              ),
              _StatusPill(
                label: summary.progressDeltaLabel,
                color: summary.portfolioProgressDelta >= 0
                    ? const Color(0xFF059669)
                    : const Color(0xFFDC2626),
                dark: dark,
              ),
              if (latest != null)
                _StatusPill(
                  label: 'overdue ${latest.reviewOverdueCount}',
                  color: alertColor,
                  dark: dark,
                ),
            ],
          ),
          if (latest != null) ...[
            const SizedBox(height: 6),
            Text(
              'KGI ${latest.portfolioProgressPercent}% / AI ${latest.aiCoveragePercent}% / life capital ${latest.lifeCapitalCoveragePercent}% / focus streak ${latest.focusStreakDays}d',
              style: TextStyle(
                color: subColor,
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              latest.nextAction,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: titleColor,
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w800,
                height: 1.45,
              ),
            ),
          ],
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

class _FocusRecommendationCard extends StatelessWidget {
  final FeatureStrategyFocusRecommendation recommendation;
  final FeatureStrategyQueuedRecommendation? queuedRecommendation;
  final bool dark;
  final bool compact;
  final FeatureStrategyFocusActionState? actionState;
  final bool actionLoading;
  final String? actionError;
  final VoidCallback? onComplete;
  final VoidCallback? onDefer;

  const _FocusRecommendationCard({
    required this.recommendation,
    required this.queuedRecommendation,
    required this.dark,
    required this.compact,
    required this.actionState,
    required this.actionLoading,
    required this.actionError,
    required this.onComplete,
    required this.onDefer,
  });

  @override
  Widget build(BuildContext context) {
    final color = _lifeCapitalColor(recommendation.resource);
    final titleColor = dark ? Colors.white : const Color(0xFF0F172A);
    final subColor =
        dark ? Colors.white.withValues(alpha: 0.70) : const Color(0xFF64748B);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? 0.16 : 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(Icons.flag_circle, size: 20, color: color),
              Text(
                '今日の低ハードル1手',
                style: TextStyle(
                  color: titleColor,
                  fontSize: compact ? 13 : 14,
                  fontWeight: FontWeight.w900,
                  height: 1.35,
                ),
              ),
              _StatusPill(
                label: recommendation.label,
                color: color,
                dark: dark,
              ),
              _StatusPill(
                label: recommendation.monitoringCadence,
                color: const Color(0xFF2563EB),
                dark: dark,
              ),
              _StatusPill(
                label: '保留 ${recommendation.parkedResourceCount}資本',
                color: const Color(0xFFF97316),
                dark: dark,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${recommendation.sectionName} / ${recommendation.featureName}',
            style: TextStyle(
              color: titleColor,
              fontSize: compact ? 13 : 15,
              fontWeight: FontWeight.w900,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            recommendation.action,
            style: TextStyle(
              color: titleColor,
              fontSize: compact ? 12 : 13,
              fontWeight: FontWeight.w800,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            recommendation.rationale,
            style: TextStyle(
              color: subColor,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _StatusPill(
                label: '7日完了 ${recommendation.actionStats.completedDaysLast7}日',
                color: const Color(0xFF059669),
                dark: dark,
              ),
              _StatusPill(
                label: '観察 ${recommendation.actionStats.deferredDaysLast7}日',
                color: const Color(0xFFF59E0B),
                dark: dark,
              ),
              _StatusPill(
                label: '継続 ${recommendation.actionStats.currentStreakDays}日',
                color: const Color(0xFF2563EB),
                dark: dark,
              ),
              _StatusPill(
                label: recommendation.actionStats.unlockStatusLabel,
                color: recommendation.actionStats.isHabitStable
                    ? const Color(0xFF059669)
                    : const Color(0xFFDC2626),
                dark: dark,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            recommendation.actionStats.isHabitStable
                ? '定着条件を満たしました。次の弱い生命資本へ広げてもよい状態です。'
                : '定着までは他の継続タスクを増やさず、この1手だけを固定します。',
            style: TextStyle(
              color: subColor,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 8),
          KgiCsfKpiPanel(
            plan: recommendation.plan,
            accentColor: color,
            dense: true,
            dark: dark,
          ),
          if (queuedRecommendation != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(compact ? 10 : 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: dark ? 0.06 : 0.38),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withValues(alpha: 0.14)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _StatusPill(
                        label: '解放後の次候補',
                        color: const Color(0xFF2563EB),
                        dark: dark,
                      ),
                      _StatusPill(
                        label: queuedRecommendation!.label,
                        color: color,
                        dark: dark,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${queuedRecommendation!.sectionName} / ${queuedRecommendation!.featureName}',
                    style: TextStyle(
                      color: titleColor,
                      fontSize: compact ? 12 : 13,
                      fontWeight: FontWeight.w900,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    queuedRecommendation!.action,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: compact ? 11 : 12,
                      fontWeight: FontWeight.w700,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    queuedRecommendation!.unlockCondition,
                    style: TextStyle(
                      color: subColor,
                      fontSize: compact ? 11 : 12,
                      fontWeight: FontWeight.w700,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          _FocusActionControls(
            state: actionState,
            loading: actionLoading,
            error: actionError,
            color: color,
            dark: dark,
            compact: compact,
            onComplete: onComplete,
            onDefer: onDefer,
          ),
        ],
      ),
    );
  }
}

class _RecoveryRoadmapAccordion extends StatelessWidget {
  final List<FeatureStrategyRecoveryRoadmapStep> steps;
  final bool dark;
  final bool compact;
  final FeatureStrategyOpenFeature? onOpenFeature;

  const _RecoveryRoadmapAccordion({
    required this.steps,
    required this.dark,
    required this.compact,
    required this.onOpenFeature,
  });

  @override
  Widget build(BuildContext context) {
    final border =
        dark ? Colors.white.withValues(alpha: 0.10) : const Color(0xFFE5E7EB);
    final titleColor = dark ? Colors.white : const Color(0xFF111827);
    final subtitleColor =
        dark ? Colors.white.withValues(alpha: 0.62) : const Color(0xFF64748B);
    final currentCount = steps.where((step) => step.isCurrent).length;
    final queuedCount = steps.where((step) => step.isQueued).length;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: steps.isNotEmpty,
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
          leading: const Icon(Icons.route_rounded, color: Color(0xFF2563EB)),
          title: Text(
            '生命資本回復ロードマップ',
            style: TextStyle(
              color: titleColor,
              fontSize: compact ? 13 : 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: Text(
            steps.isEmpty
                ? 'まだ順番はありません'
                : '${steps.length}資本を順番固定 / 今$currentCount / 次$queuedCount',
            style: TextStyle(
              color: subtitleColor,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          children: steps.isEmpty
              ? [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '回復ロードマップを作る対象がまだありません。',
                      style: TextStyle(color: subtitleColor, fontSize: 12),
                    ),
                  ),
                ]
              : [
                  for (final step in steps) ...[
                    _RecoveryRoadmapRow(
                      step: step,
                      dark: dark,
                      compact: compact,
                      onOpenFeature: onOpenFeature,
                    ),
                    if (step != steps.last) const SizedBox(height: 8),
                  ],
                ],
        ),
      ),
    );
  }
}

class _RecoveryRoadmapRow extends StatelessWidget {
  final FeatureStrategyRecoveryRoadmapStep step;
  final bool dark;
  final bool compact;
  final FeatureStrategyOpenFeature? onOpenFeature;

  const _RecoveryRoadmapRow({
    required this.step,
    required this.dark,
    required this.compact,
    required this.onOpenFeature,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = dark ? Colors.white : const Color(0xFF0F172A);
    final subColor =
        dark ? Colors.white.withValues(alpha: 0.68) : const Color(0xFF64748B);
    final color = _lifeCapitalColor(step.resource);
    final stageColor = step.isCurrent
        ? const Color(0xFF059669)
        : step.isQueued
            ? const Color(0xFF2563EB)
            : const Color(0xFFF59E0B);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? 0.14 : 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _StatusPill(
                label: '${step.order}番目',
                color: const Color(0xFF64748B),
                dark: dark,
              ),
              _StatusPill(
                label: step.stageLabel,
                color: stageColor,
                dark: dark,
              ),
              _StatusPill(
                label: step.label,
                color: color,
                dark: dark,
              ),
              _StatusPill(
                label: '${(step.progress * 100).round()}%',
                color: const Color(0xFF7C3AED),
                dark: dark,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${step.sectionName} / ${step.featureName}',
            style: TextStyle(
              color: titleColor,
              fontSize: compact ? 12 : 13,
              fontWeight: FontWeight.w900,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            step.action,
            style: TextStyle(
              color: titleColor,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            step.gate,
            style: TextStyle(
              color: subColor,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            step.rationale,
            style: TextStyle(
              color: subColor,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'KGI: ${step.plan.kgi}',
            style: TextStyle(
              color: titleColor,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
          if (onOpenFeature != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                key: Key('feature_strategy_roadmap_open_${step.resource.name}'),
                onPressed: () => onOpenFeature!(step.featureId),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('この導線を開く'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: color,
                  side: BorderSide(color: color.withValues(alpha: 0.32)),
                  textStyle: TextStyle(
                    fontSize: compact ? 12 : 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FocusActionControls extends StatelessWidget {
  final FeatureStrategyFocusActionState? state;
  final bool loading;
  final String? error;
  final Color color;
  final bool dark;
  final bool compact;
  final VoidCallback? onComplete;
  final VoidCallback? onDefer;

  const _FocusActionControls({
    required this.state,
    required this.loading,
    required this.error,
    required this.color,
    required this.dark,
    required this.compact,
    required this.onComplete,
    required this.onDefer,
  });

  @override
  Widget build(BuildContext context) {
    final subColor =
        dark ? Colors.white.withValues(alpha: 0.70) : const Color(0xFF64748B);
    final completed = state?.completed ?? false;
    final deferred = state?.deferred ?? false;
    final streak = state?.completionStreakDays ?? 0;

    if (completed || deferred) {
      return Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _StatusPill(
            label: completed ? _completedLabel(streak) : '今日は観察',
            color:
                completed ? const Color(0xFF059669) : const Color(0xFFF59E0B),
            dark: dark,
          ),
          _StatusPill(
            label: state?.cloudSynced == true ? 'Cloud sync' : 'Local save',
            color: state?.cloudSynced == true
                ? const Color(0xFF2563EB)
                : const Color(0xFF64748B),
            dark: dark,
          ),
          Text(
            completed
                ? '今日の1手を閉じました。次は明日のモニタリングで再選定します。'
                : '今日は広げず、現状観察だけにします。',
            style: TextStyle(
              color: subColor,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: loading ? null : onComplete,
              icon: loading
                  ? SizedBox(
                      width: compact ? 14 : 16,
                      height: compact ? 14 : 16,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('1手完了'),
              style: FilledButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 12 : 14,
                  vertical: compact ? 9 : 11,
                ),
                textStyle: TextStyle(
                  fontSize: compact ? 12 : 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: loading ? null : onDefer,
              icon: const Icon(Icons.visibility_outlined, size: 18),
              label: const Text('今日は観察'),
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color.withValues(alpha: 0.42)),
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 12 : 14,
                  vertical: compact ? 9 : 11,
                ),
                textStyle: TextStyle(
                  fontSize: compact ? 12 : 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        if (error != null) ...[
          const SizedBox(height: 6),
          Text(
            error!,
            style: TextStyle(
              color: const Color(0xFFDC2626),
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }

  String _completedLabel(int streak) {
    if (streak <= 1) return '完了済み';
    return '完了済み $streak日継続';
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

class _LifeCapitalAccordion extends StatelessWidget {
  final List<FeatureLifeCapitalSummary> summaries;
  final bool dark;
  final bool compact;

  const _LifeCapitalAccordion({
    required this.summaries,
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
    final coveredCount =
        summaries.where((summary) => summary.hasCoverage).length;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
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
          leading: const Icon(Icons.self_improvement, color: Color(0xFF059669)),
          title: Text(
            '生命資本・浪費ゼロKPI',
            style: TextStyle(
              color: titleColor,
              fontSize: compact ? 13 : 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: Text(
            '$coveredCount/6資本をAI分析とKGI/CSF/KPIで監視',
            style: TextStyle(
              color: subtitleColor,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          children: [
            for (final summary in summaries) ...[
              _LifeCapitalRow(
                summary: summary,
                dark: dark,
                compact: compact,
              ),
              if (summary != summaries.last) const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _LifeCapitalRow extends StatelessWidget {
  final FeatureLifeCapitalSummary summary;
  final bool dark;
  final bool compact;

  const _LifeCapitalRow({
    required this.summary,
    required this.dark,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = dark ? Colors.white : const Color(0xFF0F172A);
    final subColor =
        dark ? Colors.white.withValues(alpha: 0.68) : const Color(0xFF64748B);
    final color = _lifeCapitalColor(summary.resource);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? 0.15 : 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.16)),
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
                summary.label,
                style: TextStyle(
                  color: textColor,
                  fontSize: compact ? 13 : 14,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                ),
              ),
              _StatusPill(
                label: '${summary.featureCount}機能',
                color: color,
                dark: dark,
              ),
              _StatusPill(
                label: '高効果 ${summary.highImpactFeatureCount}',
                color: const Color(0xFFF97316),
                dark: dark,
              ),
              _StatusPill(
                label: '${(summary.averageProgress * 100).round()}%',
                color: const Color(0xFF2563EB),
                dark: dark,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            summary.hasCoverage
                ? '伸びている機能: ${summary.topFeatureName} / 先に低ハードル化: ${summary.bottleneckFeatureName}'
                : 'この資本を守る導線がまだありません。既存機能に紐づけるか、重複機能を統合して入口を作ります。',
            style: TextStyle(
              color: subColor,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 8),
          KgiCsfKpiPanel(
            plan: summary.plan,
            accentColor: color,
            dense: true,
            dark: dark,
          ),
        ],
      ),
    );
  }
}

class _LifeCapitalLaneAccordion extends StatelessWidget {
  final List<FeatureLifeCapitalConsolidationLane> lanes;
  final bool dark;
  final bool compact;
  final FeatureStrategyOpenFeature? onOpenFeature;

  const _LifeCapitalLaneAccordion({
    required this.lanes,
    required this.dark,
    required this.compact,
    required this.onOpenFeature,
  });

  @override
  Widget build(BuildContext context) {
    final border =
        dark ? Colors.white.withValues(alpha: 0.10) : const Color(0xFFE5E7EB);
    final titleColor = dark ? Colors.white : const Color(0xFF111827);
    final subtitleColor =
        dark ? Colors.white.withValues(alpha: 0.62) : const Color(0xFF64748B);
    final activeCount = lanes.where((lane) => lane.hasFeatures).length;
    final savedMinutes = lanes.fold<int>(
      0,
      (sum, lane) => sum + lane.estimatedWasteMinutesSaved,
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
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
          leading: const Icon(Icons.alt_route, color: Color(0xFF0D9488)),
          title: Text(
            '生命資本別 代表導線レーン',
            style: TextStyle(
              color: titleColor,
              fontSize: compact ? 13 : 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: Text(
            '$activeCount/6資本で代表導線を固定 / 迷い削減見込み$savedMinutes分',
            style: TextStyle(
              color: subtitleColor,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          children: [
            for (final lane in lanes) ...[
              _LifeCapitalLaneRow(
                lane: lane,
                dark: dark,
                compact: compact,
                onOpenFeature: onOpenFeature,
              ),
              if (lane != lanes.last) const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _LifeCapitalLaneRow extends StatelessWidget {
  final FeatureLifeCapitalConsolidationLane lane;
  final bool dark;
  final bool compact;
  final FeatureStrategyOpenFeature? onOpenFeature;

  const _LifeCapitalLaneRow({
    required this.lane,
    required this.dark,
    required this.compact,
    required this.onOpenFeature,
  });

  List<MapEntry<String, String>> _featureLinks() {
    final items = <MapEntry<String, String>>[];
    final seen = <String>{};
    for (var i = 0; i < lane.featureIds.length; i++) {
      final id = lane.featureIds[i];
      if (!seen.add(id)) continue;
      final name = i < lane.featureNames.length ? lane.featureNames[i] : id;
      items.add(MapEntry<String, String>(id, name));
    }
    return items;
  }

  Future<void> _openFeature(BuildContext context, String featureId) async {
    final opener = onOpenFeature;
    if (opener == null) return;
    await opener(featureId);
  }

  Future<void> _showFeatureSheet(
    BuildContext context,
    List<MapEntry<String, String>> featureLinks,
  ) async {
    final opener = onOpenFeature;
    if (opener == null || featureLinks.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final titleColor = dark ? Colors.white : const Color(0xFF0F172A);
        final subColor = dark
            ? Colors.white.withValues(alpha: 0.68)
            : const Color(0xFF64748B);
        final color = _lifeCapitalColor(lane.resource);
        return Container(
          color: dark ? const Color(0xFF111827) : Colors.white,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            children: [
              Text(
                '${lane.label} の代表導線',
                style: TextStyle(
                  color: titleColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '代表機能に寄せつつ、必要なサブ導線だけここから開けます。',
                style: TextStyle(
                  color: subColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < featureLinks.length; i++)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    i == 0
                        ? Icons.star_rounded
                        : Icons.subdirectory_arrow_right,
                    color: i == 0 ? color : subColor,
                  ),
                  title: Text(
                    featureLinks[i].value,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    i == 0 ? '代表導線' : 'サブ導線',
                    style: TextStyle(
                      color: subColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await opener(featureLinks[i].key);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final textColor = dark ? Colors.white : const Color(0xFF0F172A);
    final subColor =
        dark ? Colors.white.withValues(alpha: 0.68) : const Color(0xFF64748B);
    final color = _lifeCapitalColor(lane.resource);
    final featureLinks = _featureLinks();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? 0.14 : 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.16)),
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
                lane.label,
                style: TextStyle(
                  color: textColor,
                  fontSize: compact ? 13 : 14,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                ),
              ),
              _StatusPill(
                label: lane.canonicalFeatureName,
                color: color,
                dark: dark,
              ),
              _StatusPill(
                label: '${lane.featureCount}機能',
                color: const Color(0xFF2563EB),
                dark: dark,
              ),
              _StatusPill(
                label: '統合候補 ${lane.consolidationCandidateCount}',
                color: const Color(0xFF7C3AED),
                dark: dark,
              ),
              _StatusPill(
                label: '${lane.estimatedWasteMinutesSaved}分削減',
                color: const Color(0xFF9333EA),
                dark: dark,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            lane.hasFeatures ? '対象: ${lane.featureLabel}' : '対象機能が未接続です',
            style: TextStyle(
              color: subColor,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            lane.nextAction,
            style: TextStyle(
              color: textColor,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w800,
              height: 1.45,
            ),
          ),
          if (lane.hasFeatures && onOpenFeature != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  key: Key('feature_strategy_lane_open_${lane.resource.name}'),
                  onPressed: () =>
                      _openFeature(context, lane.canonicalFeatureId),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('代表導線を開く'),
                  style: FilledButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                  ),
                ),
                if (featureLinks.length > 1)
                  OutlinedButton.icon(
                    onPressed: () => _showFeatureSheet(context, featureLinks),
                    icon: const Icon(Icons.account_tree_outlined, size: 16),
                    label: Text('束ねた機能 ${featureLinks.length}'),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          KgiCsfKpiPanel(
            plan: lane.plan,
            accentColor: color,
            dense: true,
            dark: dark,
          ),
        ],
      ),
    );
  }
}

class _ConsolidationAccordion extends StatelessWidget {
  final List<FeatureConsolidationCandidate> candidates;
  final bool dark;
  final bool compact;

  const _ConsolidationAccordion({
    required this.candidates,
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
          initiallyExpanded: candidates.isNotEmpty,
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
          leading: const Icon(Icons.merge_type, color: Color(0xFF2563EB)),
          title: Text(
            '類似機能の抽象化・統合候補',
            style: TextStyle(
              color: titleColor,
              fontSize: compact ? 13 : 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: Text(
            candidates.isEmpty
                ? '現時点で明確な統合候補はありません'
                : '${candidates.length}候補を次回レビューで判断',
            style: TextStyle(
              color: subtitleColor,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          children: candidates.isEmpty
              ? [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '機能名・キーワード・セクションをもとに、重複が見つかり次第ここへ表示します。',
                      style: TextStyle(color: subtitleColor, fontSize: 12),
                    ),
                  ),
                ]
              : [
                  for (final candidate in candidates) ...[
                    _ConsolidationRow(
                      candidate: candidate,
                      dark: dark,
                      compact: compact,
                    ),
                    if (candidate != candidates.last) const SizedBox(height: 8),
                  ],
                ],
        ),
      ),
    );
  }
}

class _ConsolidationRow extends StatelessWidget {
  final FeatureConsolidationCandidate candidate;
  final bool dark;
  final bool compact;

  const _ConsolidationRow({
    required this.candidate,
    required this.dark,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = dark ? Colors.white : const Color(0xFF0F172A);
    final subColor =
        dark ? Colors.white.withValues(alpha: 0.68) : const Color(0xFF64748B);
    const color = Color(0xFF2563EB);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? 0.15 : 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.16)),
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
                candidate.canonicalFeatureName,
                style: TextStyle(
                  color: textColor,
                  fontSize: compact ? 13 : 14,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                ),
              ),
              _StatusPill(
                label: '${candidate.duplicateCount}機能',
                color: color,
                dark: dark,
              ),
              _StatusPill(
                label: candidate.sharedAxis,
                color: const Color(0xFF7C3AED),
                dark: dark,
              ),
              _StatusPill(
                label: '${candidate.estimatedWasteMinutesSaved}分削減見込',
                color: const Color(0xFF9333EA),
                dark: dark,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '対象: ${candidate.sectionLabel} / 代表ID: ${candidate.canonicalFeatureId}',
            style: TextStyle(
              color: subColor,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            candidate.summary,
            style: TextStyle(
              color: subColor,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 8),
          KgiCsfKpiPanel(
            plan: candidate.plan,
            accentColor: color,
            dense: true,
            dark: dark,
          ),
        ],
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
              _StatusPill(
                label: _lifeCapitalLabel(signal.lifeCapitalResource),
                color: _lifeCapitalColor(signal.lifeCapitalResource),
                dark: dark,
              ),
              _StatusPill(
                label: '浪費削減 ${signal.wasteReductionScore}/5',
                color: const Color(0xFFF97316),
                dark: dark,
              ),
              _StatusPill(
                label: signal.reviewDueLabel,
                color: _reviewColor(signal),
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
            'CSF: ${signal.wasteReductionCsf} / 監視頻度: ${signal.monitoringCadence}',
            style: TextStyle(
              color: labelColor,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w700,
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

Color _reviewColor(FeatureStrategySignal signal) {
  if (signal.reviewOverdueDays > 0) {
    return const Color(0xFFDC2626);
  }
  if (signal.reviewDue) {
    return const Color(0xFFF59E0B);
  }
  return const Color(0xFF0EA5E9);
}

String _statusLabel(FeatureStrategyStatus status) {
  return switch (status) {
    FeatureStrategyStatus.onTrack => '順調',
    FeatureStrategyStatus.watch => '要観察',
    FeatureStrategyStatus.improve => '改善優先',
  };
}

String _lifeCapitalLabel(FeatureLifeCapitalResource resource) {
  return switch (resource) {
    FeatureLifeCapitalResource.time => '時間',
    FeatureLifeCapitalResource.money => 'お金',
    FeatureLifeCapitalResource.health => '健康',
    FeatureLifeCapitalResource.stamina => '体力',
    FeatureLifeCapitalResource.intelligence => '知能',
    FeatureLifeCapitalResource.focus => '集中力',
  };
}

Color _lifeCapitalColor(FeatureLifeCapitalResource resource) {
  return switch (resource) {
    FeatureLifeCapitalResource.time => const Color(0xFF0891B2),
    FeatureLifeCapitalResource.money => const Color(0xFF0F766E),
    FeatureLifeCapitalResource.health => const Color(0xFF16A34A),
    FeatureLifeCapitalResource.stamina => const Color(0xFFEA580C),
    FeatureLifeCapitalResource.intelligence => const Color(0xFF7C3AED),
    FeatureLifeCapitalResource.focus => const Color(0xFF2563EB),
  };
}
