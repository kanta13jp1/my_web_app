import 'package:flutter/material.dart';

import '../application/ai_rlhf_feedback_controller.dart';
import '../domain/ai_rlhf_feedback_models.dart';

@immutable
class _RlhfPalette {
  const _RlhfPalette({
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

  factory _RlhfPalette.fromBrightness(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const _RlhfPalette(
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
    return const _RlhfPalette(
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

/// RLHF Bad-Output -> GitHub Issue (AI-Feedback) 純粋 Presentation View (#2659).
class AiRlhfFeedbackView extends StatelessWidget {
  const AiRlhfFeedbackView({
    super.key,
    required this.state,
    required this.actionController,
    required this.modelController,
    required this.promptController,
    required this.outputController,
    required this.commentController,
    required this.onSelectRating,
    required this.onRetryLoad,
    required this.onSubmitFeedback,
    required this.onDispatchIssue,
  });

  final AiRlhfFeedbackState state;
  final TextEditingController actionController;
  final TextEditingController modelController;
  final TextEditingController promptController;
  final TextEditingController outputController;
  final TextEditingController commentController;
  final ValueChanged<RlhfRatingStatus> onSelectRating;
  final VoidCallback onRetryLoad;
  final VoidCallback onSubmitFeedback;
  final ValueChanged<String> onDispatchIssue;

  @override
  Widget build(BuildContext context) {
    final palette = _RlhfPalette.fromBrightness(
      Theme.of(context).brightness,
    );

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
              'RLHF Bad-Output 自動 Issue 起票 (AI-Feedback)',
              style: TextStyle(
                color: palette.ink,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'AI 回答に問題あり・要改善フラグを付けると、プロンプト・出力・コメントを整理して GitHub Issue を起票します。',
              style: TextStyle(color: palette.inkSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            _buildSummaryRow(palette),
            if (state.errorMessage != null) ...<Widget>[
              const SizedBox(height: 12),
              _buildErrorBanner(palette, state.errorMessage!),
            ],
            if (state.statusNotice != null) ...<Widget>[
              const SizedBox(height: 12),
              _buildNoticeBanner(palette, state.statusNotice!),
            ],
            const SizedBox(height: 12),
            _buildFormSection(palette),
            const SizedBox(height: 16),
            _buildEntriesSection(palette),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(_RlhfPalette palette) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        _SummaryMetricBox(
          key: const ValueKey<String>('rlhf_metric_total'),
          label: '記録件数',
          value: '${state.entries.length}件',
          palette: palette,
        ),
        _SummaryMetricBox(
          key: const ValueKey<String>('rlhf_metric_bad'),
          label: '要改善評価',
          value: '${state.badFeedbackCount}件',
          palette: palette,
        ),
        _SummaryMetricBox(
          key: const ValueKey<String>('rlhf_metric_issues'),
          label: '起票済み Issue',
          value: '${state.dispatchedIssueCount}件',
          palette: palette,
        ),
      ],
    );
  }

  Widget _buildErrorBanner(_RlhfPalette palette, String message) {
    return Container(
      key: const ValueKey<String>('rlhf_error_banner'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.warnBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.warnBorder),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: palette.warnInk,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: OutlinedButton(
              key: const ValueKey<String>('rlhf_retry_button'),
              style: OutlinedButton.styleFrom(
                backgroundColor: palette.surface,
                foregroundColor: palette.ink,
                side: BorderSide(color: palette.warnBorder),
              ),
              onPressed: onRetryLoad,
              child: const Text('再読込'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoticeBanner(_RlhfPalette palette, String message) {
    return Container(
      key: const ValueKey<String>('rlhf_status_notice'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.successBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: palette.successInk,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildFormSection(_RlhfPalette palette) {
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
              '評価区分',
              style: TextStyle(
                color: palette.accentSoftInk,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final rating in RlhfRatingStatus.values)
                  ConstrainedBox(
                    constraints:
                        const BoxConstraints(minWidth: 48, minHeight: 48),
                    child: OutlinedButton(
                      key: ValueKey<String>('rlhf_rating_${rating.dbValue}'),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: state.selectedRating == rating
                            ? palette.accent
                            : palette.surface,
                        foregroundColor: state.selectedRating == rating
                            ? palette.onAccent
                            : palette.ink,
                        side: BorderSide(color: palette.border),
                      ),
                      onPressed: state.isSubmitting
                          ? null
                          : () => onSelectRating(rating),
                      child: Text(rating.label),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            _buildInputField(
              palette: palette,
              fieldKey: const ValueKey<String>('rlhf_action_input'),
              controller: actionController,
              labelText: 'AI アクション名',
              hintText: '例: weekly_summary',
              maxLines: 1,
            ),
            const SizedBox(height: 8),
            _buildInputField(
              palette: palette,
              fieldKey: const ValueKey<String>('rlhf_model_input'),
              controller: modelController,
              labelText: 'モデル ID',
              hintText: '例: gemini-2.5-flash',
              maxLines: 1,
            ),
            const SizedBox(height: 8),
            _buildInputField(
              palette: palette,
              fieldKey: const ValueKey<String>('rlhf_prompt_input'),
              controller: promptController,
              labelText: '実行プロンプト',
              hintText: 'AI に送信したプロンプト内容',
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            _buildInputField(
              palette: palette,
              fieldKey: const ValueKey<String>('rlhf_output_input'),
              controller: outputController,
              labelText: '実際の AI 出力',
              hintText: '問題があった AI の出力内容',
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            _buildInputField(
              palette: palette,
              fieldKey: const ValueKey<String>('rlhf_comment_input'),
              controller: commentController,
              labelText: '改善コメント (任意)',
              hintText: '期待した回答との差分・不具合の詳細',
              maxLines: 2,
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: FilledButton(
                key: const ValueKey<String>('rlhf_submit_button'),
                style: FilledButton.styleFrom(
                  backgroundColor: palette.accent,
                  foregroundColor: palette.onAccent,
                ),
                onPressed: state.isSubmitting ? null : onSubmitFeedback,
                child: Text(
                  state.isSubmitting
                      ? '送信中...'
                      : (state.selectedRating.triggersGitHubIssue
                          ? '問題ありとして報告・AI-Feedback Issue起票'
                          : '問題なしとして RLHF 履歴に保存'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required _RlhfPalette palette,
    required Key fieldKey,
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    required int maxLines,
  }) {
    return TextField(
      key: fieldKey,
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(color: palette.ink),
      decoration: InputDecoration(
        filled: true,
        fillColor: palette.surface,
        labelText: labelText,
        hintText: hintText,
        labelStyle: TextStyle(color: palette.inkSecondary),
        hintStyle: TextStyle(color: palette.inkSecondary),
        border: OutlineInputBorder(
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: palette.border),
        ),
      ),
    );
  }

  Widget _buildEntriesSection(_RlhfPalette palette) {
    if (state.isLoading && state.entries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.entries.isEmpty) {
      return Container(
        key: const ValueKey<String>('rlhf_empty_state'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: palette.surfaceSubtle,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: palette.border),
        ),
        child: Text(
          'まだ RLHF 評価履歴がありません。',
          style: TextStyle(color: palette.inkSecondary),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          '最近の RLHF フィードバック履歴',
          style: TextStyle(
            color: palette.ink,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        for (final entry in state.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              key: ValueKey<String>('rlhf_entry_${entry.id}'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: palette.surfaceSubtle,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: palette.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          '${entry.actionName} (${entry.ratingStatus.label})',
                          style: TextStyle(
                            color: palette.ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        entry.githubIssueNumber != null
                            ? 'Issue #${entry.githubIssueNumber} [AI-Feedback]'
                            : entry.dispatchStatus.label,
                        style: TextStyle(
                          color: palette.inkSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  if (entry.userComment.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      entry.userComment,
                      style: TextStyle(color: palette.ink, fontSize: 13),
                    ),
                  ],
                  if (entry.ratingStatus.triggersGitHubIssue &&
                      entry.githubIssueNumber == null) ...<Widget>[
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints:
                          const BoxConstraints(minWidth: 48, minHeight: 48),
                      child: OutlinedButton(
                        key: ValueKey<String>(
                          'rlhf_dispatch_button_${entry.id}',
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: palette.surface,
                          foregroundColor: palette.ink,
                          side: BorderSide(color: palette.border),
                        ),
                        onPressed: state.isSubmitting
                            ? null
                            : () => onDispatchIssue(entry.id),
                        child: const Text('Webhook Issue 起票を再実行'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _SummaryMetricBox extends StatelessWidget {
  const _SummaryMetricBox({
    super.key,
    required this.label,
    required this.value,
    required this.palette,
  });

  final String label;
  final String value;
  final _RlhfPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.surfaceSubtle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(color: palette.inkSecondary, fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: palette.ink,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
