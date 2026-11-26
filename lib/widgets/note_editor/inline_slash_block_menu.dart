import 'package:flutter/material.dart';

import '../../services/markdown_block_service.dart';

/// Compact inline `/` block insertion palette rendered directly above the
/// Markdown editor surface.
class InlineSlashBlockMenu extends StatelessWidget {
  const InlineSlashBlockMenu({
    super.key,
    required this.templates,
    required this.query,
    required this.onSelect,
    required this.onDismiss,
  });

  static const Key menuKey = Key('note_editor_inline_slash_menu');

  final List<SlashBlockTemplate> templates;
  final String query;
  final ValueChanged<SlashBlockTemplate> onSelect;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Card(
      key: menuKey,
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.primary.withValues(alpha: 0.35),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.bolt_rounded,
                  size: 16,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    query.isEmpty ? 'ブロックを挿入 (/)' : 'ブロック検索: /$query',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '閉じる',
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  onPressed: onDismiss,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            if (templates.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  '一致するブロックがありません',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: templates.map((SlashBlockTemplate template) {
                  return ActionChip(
                    key: Key('inline_slash_item_${template.id}'),
                    avatar: Text(
                      template.command,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    label: Text(template.label),
                    tooltip: template.description,
                    onPressed: () => onSelect(template),
                  );
                }).toList(growable: false),
              ),
          ],
        ),
      ),
    );
  }
}
