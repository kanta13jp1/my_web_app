import 'package:flutter/material.dart';

import '../application/ai_reasoning_depth_controller.dart';
import '../domain/ai_reasoning_depth_models.dart';

@immutable
class _ReasoningDepthPalette {
  const _ReasoningDepthPalette({
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
    required this.errorBg,
    required this.errorBorder,
    required this.errorInk,
  });

  factory _ReasoningDepthPalette.fromBrightness(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const _ReasoningDepthPalette(
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
        errorBg: Color(0xFF450A0A),
        errorBorder: Color(0xFFFCA5A5),
        errorInk: Color(0xFFFEE2E2),
      );
    }
    return const _ReasoningDepthPalette(
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
      errorBg: Color(0xFFFDECEC),
      errorBorder: Color(0xFF991B1B),
      errorInk: Color(0xFF7F1D1D),
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
  final Color errorBg;
  final Color errorBorder;
  final Color errorInk;
}

/// AI推論深度切り替え・コスト/所要時間比較・非同期キュー監視 View (#2654).
class AiReasoningDepthView extends StatelessWidget {
  const AiReasoningDepthView({
    super.key,
    required this.state,
    required this.promptController,
    required this.onSelectMode,
    required this.onSelectJob,
    required this.onRetryLoad,
    required this.onSubmitJob,
    required this.onPollSelectedJob,
    required this.onCancelSelectedJob,
  });

  final AiReasoningDepthState state;
  final TextEditingController promptController;
  final ValueChanged<ReasoningDepthMode> onSelectMode;
  final ValueChanged<String> onSelectJob;
  final VoidCallback onRetryLoad;
  final VoidCallback onSubmitJob;
  final VoidCallback onPollSelectedJob;
  final VoidCallback onCancelSelectedJob;

  @override
  Widget build(BuildContext context) {
    final palette = _ReasoningDepthPalette.fromBrightness(
      Theme.of(context).brightness,
    );
    final selectedJob = state.selectedJob;
    final selectedComparison = state.selectedComparison;

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
              'AI推論深度コントロール (Standard / Deep Research / Background)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: palette.ink,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              '課題の複雑さに応じてツール呼び出し上限・タイムアウト・推定コストと待機時間を切り替えます。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: palette.inkSecondary,
                  ),
            ),
            const SizedBox(height: 12),
            _buildModeSelectorSection(context, palette),
            const SizedBox(height: 12),
            _buildComparisonPanel(context, palette, selectedComparison),
            const SizedBox(height: 12),
            _buildPromptComposer(context, palette),
            if (state.errorMessage != null) ...<Widget>[
              const SizedBox(height: 12),
              _buildErrorBanner(context, palette, state.errorMessage!),
            ],
            const SizedBox(height: 16),
            if (state.isLoading)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: CircularProgressIndicator(color: palette.accent),
                ),
              )
            else ...<Widget>[
              if (selectedJob != null) ...<Widget>[
                _buildSelectedJobCard(context, palette, selectedJob),
                const SizedBox(height: 16),
              ],
              _buildJobHistorySection(context, palette, selectedJob),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildModeSelectorSection(
    BuildContext context,
    _ReasoningDepthPalette palette,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: ReasoningDepthMode.values.map((mode) {
        final selected = state.selectedMode == mode;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Semantics(
            button: true,
            selected: selected,
            label: '${mode.displayName} モードを選択',
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: Material(
                color: selected ? palette.accentSoft : palette.surfaceSubtle,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: selected ? palette.accent : palette.border,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: InkWell(
                  key: ValueKey<String>('depth_mode_${mode.wireValue}'),
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => onSelectMode(mode),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: <Widget>[
                            Text(
                              mode.displayName,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    color: selected
                                        ? palette.accentSoftInk
                                        : palette.ink,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: mode.isAsyncQueue
                                    ? palette.warnBg
                                    : palette.successBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                mode.isAsyncQueue ? '非同期キュー' : '即時同期',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: mode.isAsyncQueue
                                          ? palette.warnInk
                                          : palette.successInk,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                            if (selected)
                              Text(
                                '選択中',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: palette.accentSoftInk,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          mode.description,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: selected
                                        ? palette.accentSoftInk
                                        : palette.inkSecondary,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ツール上限 ${mode.maxToolCalls} 回 / タイムアウト ${mode.timeoutSeconds} 秒',
                          style:
                              Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: selected
                                        ? palette.accentSoftInk
                                        : palette.ink,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildComparisonPanel(
    BuildContext context,
    _ReasoningDepthPalette palette,
    ReasoningModeComparison selectedComparison,
  ) {
    return Container(
      key: const ValueKey<String>('depth_cost_latency_comparison'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surfaceSubtle,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'コスト・所要時間比較 (${selectedComparison.mode.displayName} 選択中)',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: palette.ink,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            '選択中モード試算: ${selectedComparison.formattedCost} '
            '(${selectedComparison.formattedCostDelta}) / '
            '所要時間目安 ${selectedComparison.formattedLatency} '
            '(${selectedComparison.formattedLatencyDelta})',
            key: const ValueKey<String>('depth_selected_comparison_summary'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: palette.ink,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          for (final entry in state.comparisons) ...<Widget>[
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '• ${entry.mode.displayName}: ${entry.formattedCost} / '
                '${entry.formattedLatency} (${entry.formattedCostDelta})',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: entry.mode == state.selectedMode
                          ? palette.accent
                          : palette.inkSecondary,
                      fontWeight: entry.mode == state.selectedMode
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPromptComposer(
    BuildContext context,
    _ReasoningDepthPalette palette,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextField(
          key: const ValueKey<String>('depth_prompt_input'),
          controller: promptController,
          maxLines: 2,
          style: TextStyle(color: palette.ink),
          decoration: InputDecoration(
            labelText: 'AIアシスタントへの推論タスク',
            hintText: '例: 複数プロジェクトの進行遅れ原因と予算リスクを横断分析',
            labelStyle: TextStyle(color: palette.inkSecondary),
            hintStyle: TextStyle(color: palette.inkSecondary),
            filled: true,
            fillColor: palette.surfaceSubtle,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: palette.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: palette.border),
            ),
          ),
        ),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: ElevatedButton(
            key: const ValueKey<String>('depth_run_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: palette.accent,
              foregroundColor: palette.onAccent,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onPressed: state.isSubmitting ? null : onSubmitJob,
            child: Text(
              state.isSubmitting
                  ? '推論ジョブを登録中...'
                  : '${state.selectedMode.displayName} モードで実行',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner(
    BuildContext context,
    _ReasoningDepthPalette palette,
    String message,
  ) {
    return Container(
      key: const ValueKey<String>('depth_error_banner'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.errorBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.errorBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: palette.errorInk,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: OutlinedButton(
                key: const ValueKey<String>('depth_retry_button'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: palette.errorInk,
                  side: BorderSide(color: palette.errorBorder),
                ),
                onPressed: onRetryLoad,
                child: const Text('履歴を再読み込み'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedJobCard(
    BuildContext context,
    _ReasoningDepthPalette palette,
    ReasoningDepthJob job,
  ) {
    final isActive = !job.jobStatus.isTerminal;
    return Container(
      key: const ValueKey<String>('depth_selected_job_card'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surfaceSubtle,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isActive ? palette.warnBorder : palette.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(
                'ジョブ詳細 (${job.reasoningMode.displayName})',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: palette.ink,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Container(
                key: const ValueKey<String>('depth_job_status_badge'),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive ? palette.warnBg : palette.successBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  job.jobStatus.displayLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: isActive ? palette.warnInk : palette.successInk,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            job.promptSummary,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: palette.ink,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: job.progressFraction,
            backgroundColor: palette.surface,
            color: palette.accent,
          ),
          const SizedBox(height: 6),
          Text(
            'ツール進捗: ${job.toolCallsCompleted}/${job.maxToolCalls} 回 '
            '(上限タイムアウト ${job.timeoutSeconds} 秒 / 推定 USD ${job.estimatedCostUsd.toStringAsFixed(4)})',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: palette.inkSecondary,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            job.progressNote,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: palette.ink,
                ),
          ),
          if (job.resultSummary.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: palette.border),
              ),
              child: Text(
                job.resultSummary,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: palette.ink,
                    ),
              ),
            ),
          ],
          if (isActive) ...<Widget>[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                ConstrainedBox(
                  constraints:
                      const BoxConstraints(minWidth: 48, minHeight: 48),
                  child: ElevatedButton(
                    key: const ValueKey<String>('depth_poll_button'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: palette.accent,
                      foregroundColor: palette.onAccent,
                    ),
                    onPressed: state.isPolling ? null : onPollSelectedJob,
                    child: Text(
                      state.isPolling ? '進行状況を確認中...' : '進行状況を確認 (ポーリング)',
                    ),
                  ),
                ),
                ConstrainedBox(
                  constraints:
                      const BoxConstraints(minWidth: 48, minHeight: 48),
                  child: OutlinedButton(
                    key: const ValueKey<String>('depth_cancel_button'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.ink,
                      side: BorderSide(color: palette.border),
                    ),
                    onPressed: state.isPolling ? null : onCancelSelectedJob,
                    child: const Text('ジョブをキャンセル'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildJobHistorySection(
    BuildContext context,
    _ReasoningDepthPalette palette,
    ReasoningDepthJob? selectedJob,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          '実行履歴・非同期キュー (${state.jobs.length} 件)',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: palette.ink,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        if (state.jobs.isEmpty)
          Text(
            'まだ推論ジョブがありません。上の入力欄からモードを選択して実行してください。',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: palette.inkSecondary,
                ),
          )
        else
          for (final job in state.jobs)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Semantics(
                button: true,
                selected: selectedJob?.id == job.id,
                label: '${job.reasoningMode.displayName}: ${job.promptSummary}',
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(minWidth: 48, minHeight: 48),
                  child: Material(
                    color: selectedJob?.id == job.id
                        ? palette.accentSoft
                        : palette.surfaceSubtle,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: selectedJob?.id == job.id
                            ? palette.accent
                            : palette.border,
                      ),
                    ),
                    child: InkWell(
                      key: ValueKey<String>('depth_job_history_item_${job.id}'),
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => onSelectJob(job.id),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(
                          '${job.reasoningMode.displayName} [${job.jobStatus.displayLabel}] '
                          '${job.promptSummary} '
                          '(${job.toolCallsCompleted}/${job.maxToolCalls})',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: selectedJob?.id == job.id
                                        ? palette.accentSoftInk
                                        : palette.ink,
                                  ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
      ],
    );
  }
}
