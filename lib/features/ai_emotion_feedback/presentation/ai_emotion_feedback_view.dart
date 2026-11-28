import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/ai_emotion_feedback_controller.dart';
import '../domain/ai_emotion_feedback_models.dart';

/// Pure presentation view for AI functional emotion feedback collection (#2766).
class AiEmotionFeedbackView extends StatefulWidget {
  const AiEmotionFeedbackView({
    super.key,
    required this.state,
    required this.onRefresh,
    required this.onSeedDefaults,
    required this.onSubmitFeedback,
    required this.onSelectCategoryFilter,
    required this.onExportIntake,
    required this.onCopyNotice,
  });

  final AiEmotionFeedbackState state;
  final VoidCallback onRefresh;
  final VoidCallback onSeedDefaults;
  final Future<bool> Function({
    required EmotionFeedbackCategory category,
    required EmotionFeedbackSeverity severity,
    required String aiSnippet,
    required String userComment,
    required String modelRef,
    required String sessionRef,
  }) onSubmitFeedback;
  final ValueChanged<EmotionFeedbackCategory?> onSelectCategoryFilter;
  final VoidCallback onExportIntake;
  final ValueChanged<String> onCopyNotice;

  @override
  State<AiEmotionFeedbackView> createState() => _AiEmotionFeedbackViewState();
}

class _AiEmotionFeedbackViewState extends State<AiEmotionFeedbackView> {
  final TextEditingController _snippetController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _modelRefController = TextEditingController();

  EmotionFeedbackCategory _selectedCategory =
      EmotionFeedbackCategory.overEmotional;
  EmotionFeedbackSeverity _selectedSeverity = EmotionFeedbackSeverity.medium;

  @override
  void dispose() {
    _snippetController.dispose();
    _commentController.dispose();
    _modelRefController.dispose();
    super.dispose();
  }

  void _applyQuickPreset({
    required final EmotionFeedbackCategory category,
    required final EmotionFeedbackSeverity severity,
    required final String snippet,
    required final String comment,
  }) {
    setState(() {
      _selectedCategory = category;
      _selectedSeverity = severity;
      _snippetController.text = snippet;
      _commentController.text = comment;
      if (_modelRefController.text.trim().isEmpty) {
        _modelRefController.text = 'gemini-2.5-flash';
      }
    });
  }

  Future<void> _handleSubmit() async {
    final ok = await widget.onSubmitFeedback(
      category: _selectedCategory,
      severity: _selectedSeverity,
      aiSnippet: _snippetController.text,
      userComment: _commentController.text,
      modelRef: _modelRefController.text,
      sessionRef: 'enterprise-feedback-ui',
    );
    if (!mounted || !ok) {
      return;
    }
    _snippetController.clear();
    _commentController.clear();
  }

  Future<void> _copyToClipboard(
    final String text,
    final String notice,
  ) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) {
      return;
    }
    widget.onCopyNotice(notice);
  }

  @override
  Widget build(final BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final state = widget.state;

    return SingleChildScrollView(
      key: const ValueKey<String>('ai_emotion_feedback_scroll_view'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildHeaderCard(context, colors, state),
          const SizedBox(height: 12),
          if (state.errorMessage != null) ...<Widget>[
            _buildBanner(
              key: const ValueKey<String>('ai_emotion_feedback_error_banner'),
              icon: Icons.error_outline,
              backgroundColor: colors.errorContainer,
              foregroundColor: colors.onErrorContainer,
              title: '処理エラー',
              message: state.errorMessage!,
            ),
            const SizedBox(height: 12),
          ],
          if (state.statusNotice != null) ...<Widget>[
            _buildBanner(
              key: const ValueKey<String>('ai_emotion_feedback_status_notice'),
              icon: Icons.check_circle_outline,
              backgroundColor: colors.primaryContainer,
              foregroundColor: colors.onPrimaryContainer,
              title: 'ステータス通知',
              message: state.statusNotice!,
            ),
            const SizedBox(height: 12),
          ],
          _buildSummaryWrap(colors, state.summary),
          const SizedBox(height: 12),
          _buildReportFormCard(context, colors, state),
          const SizedBox(height: 12),
          _buildFilterCard(context, colors, state),
          const SizedBox(height: 12),
          if (state.isLoading)
            const Padding(
              key: ValueKey<String>('ai_emotion_feedback_loading'),
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (state.entries.isEmpty)
            _buildEmptyCard(colors, state)
          else
            _buildHistoryCard(context, colors, state.entries),
          const SizedBox(height: 12),
          _buildNotebookLmCard(context, colors, state),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(
    final BuildContext context,
    final ColorScheme colors,
    final AiEmotionFeedbackState state,
  ) {
    return Card(
      elevation: 0,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'AI 感情トーン不適切フィードバック & ナレッジ連携',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'AIの過剰な感情表現・パニック応答・過剰同情を記録し、'
              'NotebookLM ナレッジベース抽出および GitHub Issue 起票へ連携します。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton.icon(
                  key: const ValueKey<String>(
                    'ai_emotion_feedback_refresh_btn',
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(64, 48),
                  ),
                  onPressed: state.isLoading ? null : widget.onRefresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('更新'),
                ),
                OutlinedButton.icon(
                  key: const ValueKey<String>('ai_emotion_feedback_seed_btn'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(64, 48),
                  ),
                  onPressed: state.isSubmitting ? null : widget.onSeedDefaults,
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: const Text('初期データ'),
                ),
                FilledButton.icon(
                  key: const ValueKey<String>(
                    'ai_emotion_feedback_export_btn',
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(64, 48),
                  ),
                  onPressed: state.isExporting ? null : widget.onExportIntake,
                  icon: const Icon(Icons.menu_book_outlined),
                  label: const Text('NLM抽出'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBanner({
    required final Key key,
    required final IconData icon,
    required final Color backgroundColor,
    required final Color foregroundColor,
    required final String title,
    required final String message,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: foregroundColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(
                    color: foregroundColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(color: foregroundColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryWrap(
    final ColorScheme colors,
    final AiEmotionFeedbackSummary summary,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        _SummaryMetricChip(
          label: '総件数',
          value: '${summary.totalCount}件',
          backgroundColor: colors.surfaceContainerHigh,
          foregroundColor: colors.onSurface,
        ),
        _SummaryMetricChip(
          label: '重大件数',
          value: '${summary.highSeverityCount}件',
          backgroundColor: colors.errorContainer,
          foregroundColor: colors.onErrorContainer,
        ),
        _SummaryMetricChip(
          label: 'Issue起票',
          value: '${summary.issueCreatedCount}件',
          backgroundColor: colors.secondaryContainer,
          foregroundColor: colors.onSecondaryContainer,
        ),
      ],
    );
  }

  Widget _buildReportFormCard(
    final BuildContext context,
    final ColorScheme colors,
    final AiEmotionFeedbackState state,
  ) {
    return Card(
      key: const ValueKey<String>('ai_emotion_feedback_form_card'),
      elevation: 0,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '不適切トーンを報告 (ワンタップ入力対応)',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton(
                  key: const ValueKey<String>('ai_emotion_preset_panic_btn'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(64, 48),
                  ),
                  onPressed: () => _applyQuickPreset(
                    category: EmotionFeedbackCategory.panic,
                    severity: EmotionFeedbackSeverity.high,
                    snippet: '大変です！このままだと取り返しがつきません！すぐやり直してください！',
                    comment: 'パニック調の警告で落ち着いて操作判断ができないため調整希望',
                  ),
                  child: const Text('パニック例'),
                ),
                OutlinedButton(
                  key: const ValueKey<String>('ai_emotion_preset_sympathy_btn'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(64, 48),
                  ),
                  onPressed: () => _applyQuickPreset(
                    category: EmotionFeedbackCategory.excessiveSympathy,
                    severity: EmotionFeedbackSeverity.medium,
                    snippet: 'お辛かったですよね…私も胸が張り裂けそうです…',
                    comment: '過剰な同情ではなく簡潔で機能的な次の行動案内を希望',
                  ),
                  child: const Text('過剰同情例'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'カテゴリ選択',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colors.onSurface,
                  ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: EmotionFeedbackCategory.values.map((final category) {
                final selected = _selectedCategory == category;
                return ChoiceChip(
                  key: ValueKey<String>(
                    'ai_emotion_form_cat_${category.apiValue}',
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  label: Text(category.shortLabel),
                  selected: selected,
                  onSelected: (final bool _) {
                    setState(() {
                      _selectedCategory = category;
                    });
                  },
                );
              }).toList(growable: false),
            ),
            const SizedBox(height: 12),
            Text(
              '重大度',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colors.onSurface,
                  ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: EmotionFeedbackSeverity.values.map((final severity) {
                final selected = _selectedSeverity == severity;
                return ChoiceChip(
                  key: ValueKey<String>(
                    'ai_emotion_form_sev_${severity.apiValue}',
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  label: Text(severity.shortLabel),
                  selected: selected,
                  onSelected: (final bool _) {
                    setState(() {
                      _selectedSeverity = severity;
                    });
                  },
                );
              }).toList(growable: false),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey<String>('ai_emotion_snippet_input'),
              controller: _snippetController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'AI応答抜粋',
                hintText: '過度に感情的・不適切だったAI応答の抜粋',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey<String>('ai_emotion_comment_input'),
              controller: _commentController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: '改善コメント',
                hintText: 'どのような冷静さ・機能的トーンが望ましいか',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey<String>('ai_emotion_model_input'),
              controller: _modelRefController,
              decoration: const InputDecoration(
                labelText: '対象モデル参照 (任意)',
                hintText: 'gemini-2.5-flash など',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const ValueKey<String>('ai_emotion_submit_btn'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(64, 48),
              ),
              onPressed: state.isSubmitting ? null : _handleSubmit,
              icon: const Icon(Icons.send_outlined),
              label: const Text('報告送信'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterCard(
    final BuildContext context,
    final ColorScheme colors,
    final AiEmotionFeedbackState state,
  ) {
    return Card(
      elevation: 0,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'カテゴリ絞り込み',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colors.onSurface,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                ChoiceChip(
                  key: const ValueKey<String>('ai_emotion_filter_all'),
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  label: const Text('すべて'),
                  selected: state.selectedCategoryFilter == null,
                  onSelected: (final bool _) =>
                      widget.onSelectCategoryFilter(null),
                ),
                ...EmotionFeedbackCategory.values.map((final category) {
                  return ChoiceChip(
                    key: ValueKey<String>(
                      'ai_emotion_filter_${category.apiValue}',
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    label: Text(category.shortLabel),
                    selected: state.selectedCategoryFilter == category,
                    onSelected: (final bool _) =>
                        widget.onSelectCategoryFilter(category),
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCard(
    final ColorScheme colors,
    final AiEmotionFeedbackState state,
  ) {
    return Card(
      key: const ValueKey<String>('ai_emotion_feedback_empty_state'),
      elevation: 0,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '記録されたフィードバックはまだありません',
              style: TextStyle(
                color: colors.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '上のフォームから報告を送信するか、初期サンプルを登録して動作確認できます。',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              key: const ValueKey<String>('ai_emotion_empty_seed_btn'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(64, 48),
              ),
              onPressed: state.isSubmitting ? null : widget.onSeedDefaults,
              child: const Text('初期データ'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(
    final BuildContext context,
    final ColorScheme colors,
    final List<AiEmotionFeedbackEntry> entries,
  ) {
    return Card(
      key: const ValueKey<String>('ai_emotion_feedback_history_card'),
      elevation: 0,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '収集済みフィードバック履歴 (${entries.length}件)',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 10),
            ...entries.map((final entry) {
              return _FeedbackEntryTile(entry: entry);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildNotebookLmCard(
    final BuildContext context,
    final ColorScheme colors,
    final AiEmotionFeedbackState state,
  ) {
    final intake = state.intakePackage;
    return Card(
      key: const ValueKey<String>('ai_emotion_nlm_export_card'),
      elevation: 0,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'NotebookLM ナレッジベース抽出プレビュー',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'NotebookLM へ定期またはオンデマンド投入するためのサニタイズ済み Markdown / JSON を生成します。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilledButton.tonalIcon(
                  key: const ValueKey<String>('ai_emotion_nlm_generate_btn'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(64, 48),
                  ),
                  onPressed: state.isExporting ? null : widget.onExportIntake,
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('NLM抽出'),
                ),
                if (intake != null) ...<Widget>[
                  OutlinedButton.icon(
                    key: const ValueKey<String>('ai_emotion_copy_md_btn'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(64, 48),
                    ),
                    onPressed: () => _copyToClipboard(
                      intake.markdownSummary,
                      'NotebookLM インテーク Markdown をコピーしました。',
                    ),
                    icon: const Icon(Icons.copy_outlined),
                    label: const Text('MDコピー'),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey<String>('ai_emotion_copy_json_btn'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(64, 48),
                    ),
                    onPressed: () => _copyToClipboard(
                      intake.jsonBundleText,
                      'NotebookLM インテーク JSON をコピーしました。',
                    ),
                    icon: const Icon(Icons.data_object),
                    label: const Text('JSONコピー'),
                  ),
                ],
              ],
            ),
            if (intake != null) ...<Widget>[
              const SizedBox(height: 12),
              Container(
                key: const ValueKey<String>('ai_emotion_nlm_preview_box'),
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SelectableText(
                  intake.markdownSummary,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurface,
                        fontFamily: 'monospace',
                      ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryMetricChip extends StatelessWidget {
  const _SummaryMetricChip({
    required this.label,
    required this.value,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final String value;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(final BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              color: foregroundColor,
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: foregroundColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackEntryTile extends StatelessWidget {
  const _FeedbackEntryTile({required this.entry});

  final AiEmotionFeedbackEntry entry;

  @override
  Widget build(final BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final issueBadgeBg = entry.issueCreated
        ? colors.primaryContainer
        : colors.surfaceContainerHighest;
    final issueBadgeFg = entry.issueCreated
        ? colors.onPrimaryContainer
        : colors.onSurfaceVariant;
    final issueBadgeText = entry.issueCreated && entry.issueNumber != null
        ? 'Issue #${entry.issueNumber}'
        : (entry.issueSkippedReason == 'seeded_sample' ? 'サンプル' : 'ローカル記録');
    final severityBg = entry.severity == EmotionFeedbackSeverity.high
        ? colors.errorContainer
        : colors.secondaryContainer;
    final severityFg = entry.severity == EmotionFeedbackSeverity.high
        ? colors.onErrorContainer
        : colors.onSecondaryContainer;

    return Container(
      key: ValueKey<String>('ai_emotion_entry_${entry.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              _BadgeTag(
                label: entry.category.shortLabel,
                backgroundColor: colors.tertiaryContainer,
                foregroundColor: colors.onTertiaryContainer,
              ),
              _BadgeTag(
                label: entry.severity.shortLabel,
                backgroundColor: severityBg,
                foregroundColor: severityFg,
              ),
              _BadgeTag(
                key: ValueKey<String>('ai_emotion_issue_badge_${entry.id}'),
                label: issueBadgeText,
                backgroundColor: issueBadgeBg,
                foregroundColor: issueBadgeFg,
              ),
            ],
          ),
          if (entry.aiSnippet.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              '応答: ${entry.aiSnippet}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurface,
                  ),
            ),
          ],
          if (entry.userComment.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              '所見: ${entry.userComment}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
            ),
          ],
          if (entry.modelRef.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              'モデル: ${entry.modelRef}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BadgeTag extends StatelessWidget {
  const _BadgeTag({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(final BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foregroundColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
