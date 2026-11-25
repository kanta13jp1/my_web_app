import 'package:flutter/material.dart';

import '../application/multi_agent_analysis_controller.dart';
import '../domain/multi_agent_analysis_models.dart';

@immutable
class _MultiAgentPalette {
  const _MultiAgentPalette({
    required this.surface,
    required this.surfaceSubtle,
    required this.border,
    required this.ink,
    required this.inkSecondary,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.accentSoftInk,
    required this.warnBg,
    required this.warnBorder,
    required this.warnInk,
    required this.successBg,
    required this.successInk,
  });

  factory _MultiAgentPalette.fromBrightness(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const _MultiAgentPalette(
        surface: Color(0xFF111827),
        surfaceSubtle: Color(0xFF1F2937),
        border: Color(0xFF9CA3AF),
        ink: Color(0xFFF9FAFB),
        inkSecondary: Color(0xFFE5E7EB),
        accent: Color(0xFF93C5FD),
        onAccent: Color(0xFF0B2545),
        accentSoft: Color(0xFF1E3A5F),
        accentSoftInk: Color(0xFFE0F2FE),
        warnBg: Color(0xFF332100),
        warnBorder: Color(0xFFFBBF24),
        warnInk: Color(0xFFFEF3C7),
        successBg: Color(0xFF064E3B),
        successInk: Color(0xFFECFDF5),
      );
    }
    return const _MultiAgentPalette(
      surface: Color(0xFFFFFFFF),
      surfaceSubtle: Color(0xFFF3F5F8),
      border: Color(0xFF4B5563),
      ink: Color(0xFF111827),
      inkSecondary: Color(0xFF374151),
      accent: Color(0xFF0F4C81),
      onAccent: Color(0xFFFFFFFF),
      accentSoft: Color(0xFFE6EFF8),
      accentSoftInk: Color(0xFF0B355C),
      warnBg: Color(0xFFFFF4E5),
      warnBorder: Color(0xFF8A4B00),
      warnInk: Color(0xFF5A2E00),
      successBg: Color(0xFFE6F4EA),
      successInk: Color(0xFF0D4A22),
    );
  }

  final Color surface;
  final Color surfaceSubtle;
  final Color border;
  final Color ink;
  final Color inkSecondary;
  final Color accent;
  final Color onAccent;
  final Color accentSoft;
  final Color accentSoftInk;
  final Color warnBg;
  final Color warnBorder;
  final Color warnInk;
  final Color successBg;
  final Color successInk;
}

/// 3エージェント逐次分析・推論トレース可視化・Human-in-the-Loop 純粋 Presentation View (#2641).
class MultiAgentAnalysisView extends StatelessWidget {
  const MultiAgentAnalysisView({
    super.key,
    required this.state,
    required this.topicController,
    required this.reviewNoteController,
    required this.onRetryLoad,
    required this.onRunAnalysis,
    required this.onSelectRun,
    required this.onSelectStageFilter,
    required this.onSubmitReview,
  });

  final MultiAgentAnalysisState state;
  final TextEditingController topicController;
  final TextEditingController reviewNoteController;
  final VoidCallback onRetryLoad;
  final VoidCallback onRunAnalysis;
  final ValueChanged<String> onSelectRun;
  final ValueChanged<AgentStageFilter> onSelectStageFilter;
  final ValueChanged<HumanReviewStatus> onSubmitReview;

  @override
  Widget build(BuildContext context) {
    final palette = _MultiAgentPalette.fromBrightness(
      Theme.of(context).brightness,
    );
    final selectedRun = state.selectedRun;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '役割分割型マルチエージェント分析',
              style: TextStyle(
                color: palette.ink,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '1. データ収集 → 2. 指標計算 → 3. 総合判断 の JSON 逐次連携と人間による最終承認 (Human-in-the-Loop)',
              style: TextStyle(
                color: palette.inkSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            _buildNewRunSection(palette),
            if (state.errorMessage != null) ...<Widget>[
              const SizedBox(height: 12),
              _buildErrorCard(palette, state.errorMessage!),
            ],
            const SizedBox(height: 16),
            if (state.isLoading && state.runs.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: CircularProgressIndicator(color: palette.accent),
                ),
              )
            else if (selectedRun == null)
              _buildEmptyCard(palette)
            else ...<Widget>[
              _buildRunSelector(palette, selectedRun),
              const SizedBox(height: 14),
              _buildHumanInTheLoopBanner(palette, selectedRun),
              const SizedBox(height: 14),
              _buildSequentialStages(palette, selectedRun),
              const SizedBox(height: 14),
              _buildReasoningTraceSection(palette),
              const SizedBox(height: 14),
              _buildHumanReviewPanel(palette, selectedRun),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNewRunSection(_MultiAgentPalette palette) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surfaceSubtle,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextField(
              key: const ValueKey<String>('multi_agent_topic_input'),
              controller: topicController,
              style: TextStyle(color: palette.ink),
              decoration: InputDecoration(
                labelText: '分析テーマ',
                hintText: '例: 月次キャッシュフローと配分バランス評価',
                labelStyle: TextStyle(color: palette.inkSecondary),
                hintStyle: TextStyle(color: palette.inkSecondary),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: palette.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: palette.border),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                child: FilledButton.icon(
                  key: const ValueKey<String>('multi_agent_run_button'),
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.accent,
                    foregroundColor: palette.onAccent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onPressed: state.isSubmitting ? null : onRunAnalysis,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(
                    state.isSubmitting ? '実行中...' : '分析を実行',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(_MultiAgentPalette palette, String message) {
    return DecoratedBox(
      key: const ValueKey<String>('multi_agent_error_banner'),
      decoration: BoxDecoration(
        color: palette.warnBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.warnBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              message,
              style: TextStyle(
                color: palette.warnInk,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: OutlinedButton(
                key: const ValueKey<String>('multi_agent_retry_button'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: palette.warnInk,
                  side: BorderSide(color: palette.warnBorder),
                ),
                onPressed: onRetryLoad,
                child: const Text('再読み込み'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCard(_MultiAgentPalette palette) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surfaceSubtle,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'まだ分析履歴がありません。上の入力欄から分析テーマを指定して実行してください。',
          style: TextStyle(color: palette.inkSecondary),
        ),
      ),
    );
  }

  Widget _buildRunSelector(
    _MultiAgentPalette palette,
    MultiAgentAnalysisRun selectedRun,
  ) {
    if (state.runs.length <= 1) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: state.runs.map((run) {
        final isSelected = run.id == selectedRun.id;
        return ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: Semantics(
            selected: isSelected,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                backgroundColor:
                    isSelected ? palette.accent : palette.surfaceSubtle,
                foregroundColor: isSelected ? palette.onAccent : palette.ink,
                side: BorderSide(color: palette.border),
              ),
              onPressed: () => onSelectRun(run.id),
              child: Text(run.topic),
            ),
          ),
        );
      }).toList(growable: false),
    );
  }

  Widget _buildHumanInTheLoopBanner(
    _MultiAgentPalette palette,
    MultiAgentAnalysisRun run,
  ) {
    final bool isApproved = run.reviewStatus == HumanReviewStatus.approved;
    final Color bg = isApproved ? palette.successBg : palette.warnBg;
    final Color fg = isApproved ? palette.successInk : palette.warnInk;
    final Color border = isApproved ? palette.successInk : palette.warnBorder;

    return DecoratedBox(
      key: const ValueKey<String>('multi_agent_hitl_banner'),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Human-in-the-Loop 確認状態: ${run.reviewStatus.label}',
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              run.advisoryNotice,
              style: TextStyle(color: fg, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSequentialStages(
    _MultiAgentPalette palette,
    MultiAgentAnalysisRun run,
  ) {
    final metricsEntries = run.calculatorMetrics.entries
        .map((e) => '${e.key}: ${e.value}')
        .join(' / ');
    final anomaliesText =
        run.anomalies.isEmpty ? '検出なし' : run.anomalies.join(' / ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'シーケンシャル JSON パイプライン出力',
          style: TextStyle(
            color: palette.ink,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        _buildStageCard(
          palette: palette,
          cardKey: const ValueKey<String>('stage_collector_card'),
          title: 'Stage 1: DataCollectorAgent (データ収集・PII保護)',
          body:
              '${run.collectorSummary}\n収集件数: ${run.collectedObservationCount} / 匿名化件数: ${run.sanitizedRedactionCount}',
        ),
        const SizedBox(height: 8),
        _buildStageCard(
          palette: palette,
          cardKey: const ValueKey<String>('stage_calculator_card'),
          title: 'Stage 2: MetricCalculatorAgent (指標計算・異常検知)',
          body:
              '主要指標: ${metricsEntries.isEmpty ? '未算出' : metricsEntries}\n異常シグナル: $anomaliesText',
        ),
        const SizedBox(height: 8),
        _buildStageCard(
          palette: palette,
          cardKey: const ValueKey<String>('stage_synthesizer_card'),
          title:
              'Stage 3: SynthesisAdvisorAgent (総合判断 / リスク: ${run.riskLevel})',
          body:
              '${run.headline}\n根拠: ${run.rationale.join(' / ')}\n推奨対応: ${run.recommendedActions.join(' / ')}',
        ),
      ],
    );
  }

  Widget _buildStageCard({
    required _MultiAgentPalette palette,
    required Key cardKey,
    required String title,
    required String body,
  }) {
    return DecoratedBox(
      key: cardKey,
      decoration: BoxDecoration(
        color: palette.surfaceSubtle,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: TextStyle(
                color: palette.accentSoftInk,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              body,
              style: TextStyle(color: palette.ink, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReasoningTraceSection(_MultiAgentPalette palette) {
    final steps = state.visibleTraceSteps;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          '判断プロセス（推論トレース）',
          style: TextStyle(
            color: palette.ink,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: AgentStageFilter.values.map((filter) {
            final isSelected = state.stageFilter == filter;
            return ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: Semantics(
                selected: isSelected,
                child: OutlinedButton(
                  key: ValueKey<String>('stage_filter_${filter.roleValue}'),
                  style: OutlinedButton.styleFrom(
                    backgroundColor:
                        isSelected ? palette.accent : palette.surfaceSubtle,
                    foregroundColor:
                        isSelected ? palette.onAccent : palette.ink,
                    side: BorderSide(color: palette.border),
                  ),
                  onPressed: () => onSelectStageFilter(filter),
                  child: Text(filter.label),
                ),
              ),
            );
          }).toList(growable: false),
        ),
        const SizedBox(height: 8),
        for (final step in steps)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: DecoratedBox(
              key: ValueKey<String>('trace_step_${step.stepIndex}'),
              decoration: BoxDecoration(
                color: palette.surfaceSubtle,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: palette.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Step ${step.stepIndex}: ${step.agentName} (${step.inputSchema} -> ${step.outputSchema})',
                      style: TextStyle(
                        color: palette.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '出力要約: ${step.summary}',
                      style: TextStyle(color: palette.ink, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '推論根拠: ${step.decisionBasis} (${step.durationMs.toStringAsFixed(1)} ms)',
                      style: TextStyle(
                        color: palette.inkSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHumanReviewPanel(
    _MultiAgentPalette palette,
    MultiAgentAnalysisRun run,
  ) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.accentSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '最終確認レビュー入力',
              style: TextStyle(
                color: palette.accentSoftInk,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey<String>('multi_agent_review_note_input'),
              controller: reviewNoteController,
              style: TextStyle(color: palette.ink),
              decoration: InputDecoration(
                filled: true,
                fillColor: palette.surface,
                labelText: 'レビューコメント（PII除外対象）',
                hintText: '根拠確認結果や修正指示を記録',
                labelStyle: TextStyle(color: palette.inkSecondary),
                hintStyle: TextStyle(color: palette.inkSecondary),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: palette.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: palette.border),
                ),
              ),
            ),
            if (run.reviewNote.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                '記録済みコメント: ${run.reviewNote}',
                style: TextStyle(
                  color: palette.accentSoftInk,
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                ConstrainedBox(
                  constraints:
                      const BoxConstraints(minWidth: 48, minHeight: 48),
                  child: FilledButton(
                    key: const ValueKey<String>('review_approve_button'),
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.accent,
                      foregroundColor: palette.onAccent,
                    ),
                    onPressed: state.isSubmitting
                        ? null
                        : () => onSubmitReview(HumanReviewStatus.approved),
                    child: const Text('承認'),
                  ),
                ),
                ConstrainedBox(
                  constraints:
                      const BoxConstraints(minWidth: 48, minHeight: 48),
                  child: OutlinedButton(
                    key: const ValueKey<String>('review_revision_button'),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: palette.surface,
                      foregroundColor: palette.ink,
                      side: BorderSide(color: palette.border),
                    ),
                    onPressed: state.isSubmitting
                        ? null
                        : () => onSubmitReview(HumanReviewStatus.needsRevision),
                    child: const Text('要修正'),
                  ),
                ),
                ConstrainedBox(
                  constraints:
                      const BoxConstraints(minWidth: 48, minHeight: 48),
                  child: OutlinedButton(
                    key: const ValueKey<String>('review_reject_button'),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: palette.surface,
                      foregroundColor: palette.ink,
                      side: BorderSide(color: palette.border),
                    ),
                    onPressed: state.isSubmitting
                        ? null
                        : () => onSubmitReview(HumanReviewStatus.rejected),
                    child: const Text('却下'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
