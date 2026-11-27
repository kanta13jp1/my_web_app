import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_web_app/widgets/grow_together_share_card.dart';

class HomeFeatureRequestFormCard extends StatelessWidget {
  final bool isDark;
  final bool isCompact;
  final GlobalKey<FormState> formKey;
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TextEditingController outcomeController;
  final String category;
  final String priority;
  final bool isSubmitting;
  final bool isAnalyzingAttachment;
  final bool hasAttachment;
  final String? attachmentFileName;
  final String? attachmentSizeLabel;
  final String analysisObservation;
  final String analysisProposal;
  final bool hasSubmission;
  final bool submissionSuccess;
  final int? issueNumber;
  final String issueUrl;
  final bool hasWbsTask;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onPriorityChanged;
  final VoidCallback onPickAttachment;
  final VoidCallback onAnalyzeAttachment;
  final VoidCallback onClearAttachment;
  final VoidCallback onSubmit;
  final Future<bool> Function()? onLaunchXShare;

  const HomeFeatureRequestFormCard({
    super.key,
    required this.isDark,
    required this.isCompact,
    required this.formKey,
    required this.titleController,
    required this.descriptionController,
    required this.outcomeController,
    required this.category,
    required this.priority,
    required this.isSubmitting,
    required this.isAnalyzingAttachment,
    required this.hasAttachment,
    this.attachmentFileName,
    this.attachmentSizeLabel,
    this.analysisObservation = '',
    this.analysisProposal = '',
    this.hasSubmission = false,
    this.submissionSuccess = false,
    this.issueNumber,
    this.issueUrl = '',
    this.hasWbsTask = false,
    required this.onCategoryChanged,
    required this.onPriorityChanged,
    required this.onPickAttachment,
    required this.onAnalyzeAttachment,
    required this.onClearAttachment,
    required this.onSubmit,
    this.onLaunchXShare,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    const categories = ['機能追加', 'UX改善', '不具合', 'AI連携', 'データ連携', 'その他'];
    const priorityLabels = {'high': '高', 'medium': '中', 'low': '低'};
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: colorScheme.outlineVariant),
    );

    Widget buildDropdowns() {
      final categoryField = DropdownButtonFormField<String>(
        key: ValueKey('feature-request-category-$category'),
        initialValue: category,
        decoration: InputDecoration(
          labelText: '分類',
          prefixIcon: const Icon(Icons.category_outlined),
          border: fieldBorder,
          enabledBorder: fieldBorder,
          isDense: true,
        ),
        items: [
          for (final item in categories)
            DropdownMenuItem(value: item, child: Text(item)),
        ],
        onChanged: isSubmitting
            ? null
            : (value) {
                if (value != null) onCategoryChanged(value);
              },
      );
      final priorityField = DropdownButtonFormField<String>(
        key: ValueKey('feature-request-priority-$priority'),
        initialValue: priority,
        decoration: InputDecoration(
          labelText: '優先度',
          prefixIcon: const Icon(Icons.priority_high_outlined),
          border: fieldBorder,
          enabledBorder: fieldBorder,
          isDense: true,
        ),
        items: [
          for (final entry in priorityLabels.entries)
            DropdownMenuItem(value: entry.key, child: Text(entry.value)),
        ],
        onChanged: isSubmitting
            ? null
            : (value) {
                if (value != null) onPriorityChanged(value);
              },
      );

      if (isCompact) {
        return Column(
          children: [categoryField, const SizedBox(height: 10), priorityField],
        );
      }
      return Row(
        children: [
          Expanded(child: categoryField),
          const SizedBox(width: 10),
          Expanded(child: priorityField),
        ],
      );
    }

    Widget buildAttachmentAnalyzer() {
      final hasAnalysisText =
          analysisObservation.isNotEmpty || analysisProposal.isNotEmpty;
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.image_search_outlined,
                  color: colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'スクリーンショット・写真からAIが追加要望を下書きします',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (hasAttachment && attachmentFileName != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.surface.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$attachmentFileName / ${attachmentSizeLabel ?? ''}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: isSubmitting || isAnalyzingAttachment
                      ? null
                      : onPickAttachment,
                  icon: const Icon(Icons.attach_file_outlined),
                  label: Text(hasAttachment ? '画像を変更' : '画像を選択'),
                ),
                FilledButton.tonalIcon(
                  onPressed:
                      !hasAttachment || isSubmitting || isAnalyzingAttachment
                          ? null
                          : onAnalyzeAttachment,
                  icon: isAnalyzingAttachment
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome_outlined),
                  label: Text(isAnalyzingAttachment ? 'AI診断中' : 'AI診断'),
                ),
                if (hasAttachment)
                  TextButton.icon(
                    onPressed: isSubmitting || isAnalyzingAttachment
                        ? null
                        : onClearAttachment,
                    icon: const Icon(Icons.close_outlined),
                    label: const Text('クリア'),
                  ),
              ],
            ),
            if (hasAnalysisText) ...[
              const SizedBox(height: 10),
              Text(
                [
                  if (analysisObservation.isNotEmpty)
                    '観察: $analysisObservation',
                  if (analysisProposal.isNotEmpty) '改善案: $analysisProposal',
                ].join('\n'),
                style: theme.textTheme.bodySmall?.copyWith(height: 1.55),
              ),
            ],
          ],
        ),
      );
    }

    final formCard = Card(
      elevation: 0,
      color: isDark ? const Color(0xFF111827) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : const Color(0xFFDDE8E4),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(isCompact ? 14 : 18),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F766E).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.add_comment_outlined,
                      color: Color(0xFF0F766E),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '改善内容を送る',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            height: 1.5,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '送信内容はサービス改善の検討に利用し、受付番号を発行します。',
                          style: TextStyle(fontSize: 12, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: titleController,
                enabled: !isSubmitting,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: '要望タイトル',
                  hintText: '例: カレンダーから習慣の優先度を調整したい',
                  prefixIcon: const Icon(Icons.title_outlined),
                  border: fieldBorder,
                  enabledBorder: fieldBorder,
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.length < 3) return '3文字以上で入力してください';
                  return null;
                },
              ),
              const SizedBox(height: 10),
              buildDropdowns(),
              const SizedBox(height: 10),
              buildAttachmentAnalyzer(),
              const SizedBox(height: 10),
              TextFormField(
                controller: descriptionController,
                enabled: !isSubmitting,
                minLines: 3,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: '内容',
                  hintText: '困っていること、使いたい場面、現在の回避策など',
                  alignLabelWithHint: true,
                  prefixIcon: const Icon(Icons.notes_outlined),
                  border: fieldBorder,
                  enabledBorder: fieldBorder,
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.length < 10) return '10文字以上で入力してください';
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: outcomeController,
                enabled: !isSubmitting,
                minLines: 2,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: '期待する成果',
                  hintText: 'この機能で何が速く、楽に、確実になるか',
                  alignLabelWithHint: true,
                  prefixIcon: const Icon(Icons.check_circle_outline),
                  border: fieldBorder,
                  enabledBorder: fieldBorder,
                ),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: isSubmitting ? null : onSubmit,
                  icon: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_outlined),
                  label: Text(isSubmitting ? '登録中' : '登録する'),
                ),
              ),
              if (hasSubmission) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0A2A1A)
                        : const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF1A5A3A)
                          : const Color(0xFFA7F3D0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.task_alt,
                            color: Color(0xFF047857),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            submissionSuccess ? '登録完了' : '一部登録完了',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF065F46),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        issueNumber == null
                            ? '受付番号を発行しています'
                            : '受付番号: #$issueNumber',
                        style: const TextStyle(
                          color: Color(0xFF065F46),
                          height: 1.5,
                        ),
                      ),
                      Text(
                        hasWbsTask ? '改善タスクに登録済み' : '改善タスクへの登録を確認中',
                        style: const TextStyle(
                          color: Color(0xFF065F46),
                          height: 1.5,
                        ),
                      ),
                      if (issueUrl.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            await Clipboard.setData(
                              ClipboardData(text: issueUrl),
                            );
                            if (!context.mounted) return;
                            messenger.showSnackBar(
                              const SnackBar(content: Text('受付URLをコピーしました')),
                            );
                          },
                          icon: const Icon(Icons.copy, size: 16),
                          label: const Text('受付URLをコピー'),
                        ),
                      ],
                      const SizedBox(height: 10),
                      const Divider(height: 1, color: Color(0x33047857)),
                      const SizedBox(height: 10),
                      const Text(
                        '要望をありがとうございます。あなたの一言がそのまま開発タスクになります。'
                        'この仕組みをXで広めて、一緒にアプリを育てる仲間を増やしませんか？',
                        style: TextStyle(
                          color: Color(0xFF065F46),
                          fontSize: 12,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.icon(
                          key: const Key('feature_request_share_x_button'),
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final launcher = onLaunchXShare ??
                                GrowTogetherShare.launchXShare;
                            final opened = await launcher();
                            if (!context.mounted || opened) return;
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Xの投稿画面を開けませんでした。本文をコピーして共有してください。',
                                ),
                              ),
                            );
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF000000),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Text(
                            '𝕏',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          label: const Text('Xでシェアして仲間を増やす'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        formCard,
        const SizedBox(height: 16),
        GrowTogetherShareCard(isDark: isDark, isCompact: isCompact),
      ],
    );
  }
}
