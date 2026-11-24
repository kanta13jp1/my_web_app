import 'package:flutter/material.dart';

import '../application/prompt_templates_controller.dart';
import '../domain/prompt_template_models.dart';

/// 5要素構造化プロンプトテンプレート管理の純粋プレゼンテーションビュー (#2665).
class PromptTemplatesView extends StatelessWidget {
  const PromptTemplatesView({
    super.key,
    required this.state,
    required this.currentUserId,
    required this.titleController,
    required this.roleController,
    required this.contextController,
    required this.deliverableController,
    required this.constraintsController,
    required this.thinkingController,
    required this.searchController,
    required this.onTitleChanged,
    required this.onRoleChanged,
    required this.onContextChanged,
    required this.onDeliverableChanged,
    required this.onConstraintsChanged,
    required this.onThinkingChanged,
    required this.onSharedChanged,
    required this.onSavePressed,
    required this.onResetPressed,
    required this.onCopyPressed,
    required this.onSendPressed,
    required this.onSearchChanged,
    required this.onFilterChanged,
    required this.onRefreshPressed,
    required this.onReuseTemplate,
    required this.onEditTemplate,
    required this.onDeleteTemplate,
  });

  final PromptTemplatesState state;
  final String? currentUserId;
  final TextEditingController titleController;
  final TextEditingController roleController;
  final TextEditingController contextController;
  final TextEditingController deliverableController;
  final TextEditingController constraintsController;
  final TextEditingController thinkingController;
  final TextEditingController searchController;
  final ValueChanged<String> onTitleChanged;
  final ValueChanged<String> onRoleChanged;
  final ValueChanged<String> onContextChanged;
  final ValueChanged<String> onDeliverableChanged;
  final ValueChanged<String> onConstraintsChanged;
  final ValueChanged<String> onThinkingChanged;
  final ValueChanged<bool> onSharedChanged;
  final VoidCallback onSavePressed;
  final VoidCallback onResetPressed;
  final VoidCallback onCopyPressed;
  final VoidCallback onSendPressed;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<PromptTemplateFilter> onFilterChanged;
  final VoidCallback onRefreshPressed;
  final ValueChanged<PromptTemplate> onReuseTemplate;
  final ValueChanged<PromptTemplate> onEditTemplate;
  final ValueChanged<PromptTemplate> onDeleteTemplate;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final filtered = state.filteredTemplates(currentUserId: currentUserId);
    final busy = state.isSubmitting || state.isSending;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      Text(
                        state.isEditing
                            ? '5要素プロンプトテンプレート編集'
                            : '5要素プロンプトテンプレート作成',
                        style: theme.textTheme.titleLarge,
                      ),
                      if (state.isLoading)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '役割設定・コンテキスト情報・成果物の定義・制約条件・思考プロセスの5要素を独立管理してチームで再利用できます。',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (state.errorMessage != null) ...<Widget>[
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      child: Container(
                        key: const ValueKey<String>(
                          'prompt-template-error-banner',
                        ),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          state.errorMessage!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (state.statusMessage != null) ...<Widget>[
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      child: Container(
                        key: const ValueKey<String>(
                          'prompt-template-status-banner',
                        ),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          state.statusMessage!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    key: const ValueKey<String>('prompt-template-title-input'),
                    controller: titleController,
                    onChanged: onTitleChanged,
                    maxLength: PromptTemplateLimits.maxTitleLength,
                    decoration: const InputDecoration(
                      labelText: 'テンプレート名',
                      hintText: '例: YouTube 台本生成・構成レビュー用',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey<String>('prompt-template-role-input'),
                    controller: roleController,
                    onChanged: onRoleChanged,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: '1. 役割設定',
                      hintText: 'AI に担わせる専門ロール・視点・トーンを記述',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey<String>(
                      'prompt-template-context-input',
                    ),
                    controller: contextController,
                    onChanged: onContextChanged,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: '2. コンテキスト情報',
                      hintText: '前提条件・ターゲット読者・入力データの背景を記述',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey<String>(
                      'prompt-template-deliverable-input',
                    ),
                    controller: deliverableController,
                    onChanged: onDeliverableChanged,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: '3. 成果物の定義',
                      hintText: '期待する出力形式・構成・分量・フォーマットを記述',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey<String>(
                      'prompt-template-constraints-input',
                    ),
                    controller: constraintsController,
                    onChanged: onConstraintsChanged,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: '4. 制約条件',
                      hintText: '禁止事項・文字数上限・事実根拠ルールを記述',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey<String>(
                      'prompt-template-thinking-input',
                    ),
                    controller: thinkingController,
                    onChanged: onThinkingChanged,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: '5. 思考プロセス',
                      hintText: '段階的な推論手順・自己検証ステップを記述',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    key: const ValueKey<String>(
                      'prompt-template-shared-switch',
                    ),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('チームに共有する'),
                    subtitle: const Text(
                      'オンにすると他のメンバーも一覧検索・再利用できます',
                    ),
                    value: state.draftIsShared,
                    onChanged: busy ? null : onSharedChanged,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: <Widget>[
                      FilledButton.icon(
                        key: const ValueKey<String>(
                          'prompt-template-save-button',
                        ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(48, 48),
                        ),
                        onPressed: busy ? null : onSavePressed,
                        icon: state.isSubmitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(
                          state.isEditing ? 'テンプレートを更新' : 'テンプレートを保存',
                        ),
                      ),
                      OutlinedButton.icon(
                        key: const ValueKey<String>(
                          'prompt-template-reset-button',
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(48, 48),
                        ),
                        onPressed: busy ? null : onResetPressed,
                        icon: const Icon(Icons.add),
                        label: const Text('新規入力にクリア'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            key: const ValueKey<String>('prompt-template-preview-card'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    '結合プレーンテキスト プレビュー',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      state.liveCompiledPrompt,
                      key: const ValueKey<String>(
                        'prompt-template-preview-text',
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: <Widget>[
                      OutlinedButton.icon(
                        key: const ValueKey<String>(
                          'prompt-template-copy-button',
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(48, 48),
                        ),
                        onPressed: busy ? null : onCopyPressed,
                        icon: const Icon(Icons.copy_all_outlined),
                        label: const Text('テキストをコピー'),
                      ),
                      FilledButton.tonalIcon(
                        key: const ValueKey<String>(
                          'prompt-template-send-button',
                        ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(48, 48),
                        ),
                        onPressed: busy ? null : onSendPressed,
                        icon: state.isSending
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send_outlined),
                        label: const Text('外部APIへ送信'),
                      ),
                    ],
                  ),
                  if (state.lastApiResponse != null) ...<Widget>[
                    const SizedBox(height: 12),
                    Container(
                      key: const ValueKey<String>(
                        'prompt-template-api-response-card',
                      ),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Text(
                            '外部API応答 (${state.lastSendProviderLabel ?? 'ai-hub'})',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: colorScheme.onSecondaryContainer,
                            ),
                          ),
                          const SizedBox(height: 4),
                          SelectableText(
                            state.lastApiResponse!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSecondaryContainer,
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
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      Text(
                        'チーム内ナレッジ一覧 (${filtered.length}件)',
                        style: theme.textTheme.titleMedium,
                      ),
                      IconButton(
                        key: const ValueKey<String>(
                          'prompt-template-refresh-button',
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        tooltip: 'テンプレート一覧を再読み込み',
                        onPressed: state.isLoading ? null : onRefreshPressed,
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey<String>(
                      'prompt-template-search-input',
                    ),
                    controller: searchController,
                    onChanged: onSearchChanged,
                    decoration: const InputDecoration(
                      labelText: 'テンプレート検索',
                      hintText: 'タイトルや5要素のキーワードで絞り込み',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<PromptTemplateFilter>(
                    key: const ValueKey<String>(
                      'prompt-template-filter-select',
                    ),
                    initialValue: state.filter,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: '表示範囲',
                      border: OutlineInputBorder(),
                    ),
                    items: PromptTemplateFilter.values
                        .map(
                          (final PromptTemplateFilter filterOption) =>
                              DropdownMenuItem<PromptTemplateFilter>(
                            value: filterOption,
                            child: Text(
                              filterOption.labelJa,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (final PromptTemplateFilter? nextFilter) {
                      if (nextFilter != null) {
                        onFilterChanged(nextFilter);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  if (filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        '該当するプロンプトテンプレートがありません。',
                        key: const ValueKey<String>(
                          'prompt-template-empty-state',
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: filtered
                          .map(
                            (final PromptTemplate template) => _TemplateCard(
                              template: template,
                              isOwnedByCurrentUser: currentUserId != null &&
                                  template.userId == currentUserId,
                              busy: busy,
                              onReuse: () => onReuseTemplate(template),
                              onEdit: () => onEditTemplate(template),
                              onDelete: () => onDeleteTemplate(template),
                            ),
                          )
                          .toList(growable: false),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.isOwnedByCurrentUser,
    required this.busy,
    required this.onReuse,
    required this.onEdit,
    required this.onDelete,
  });

  final PromptTemplate template;
  final bool isOwnedByCurrentUser;
  final bool busy;
  final VoidCallback onReuse;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      key: ValueKey<String>('prompt-template-card-${template.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      color: colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              template.title,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: template.isShared
                        ? colorScheme.primaryContainer
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    template.isShared ? 'チーム共有' : '非公開',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: template.isShared
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurface,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '利用回数: ${template.usageCount}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '役割: ${template.elements.roleSetting}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '成果物: ${template.elements.deliverableDefinition}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                FilledButton.tonalIcon(
                  key: ValueKey<String>('prompt-template-reuse-${template.id}'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: busy ? null : onReuse,
                  icon: const Icon(Icons.play_for_work),
                  label: const Text('再利用'),
                ),
                if (isOwnedByCurrentUser)
                  OutlinedButton.icon(
                    key: ValueKey<String>(
                      'prompt-template-edit-${template.id}',
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: busy ? null : onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('編集'),
                  ),
                if (isOwnedByCurrentUser)
                  IconButton(
                    key: ValueKey<String>(
                      'prompt-template-delete-${template.id}',
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    tooltip: 'テンプレート「${template.title}」を削除',
                    onPressed: busy ? null : onDelete,
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
