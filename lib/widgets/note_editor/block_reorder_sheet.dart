import 'package:flutter/material.dart';

import '../../services/markdown_block_service.dart';

/// Modal sheet enabling Notion-style drag-and-drop (and accessible up/down)
/// reordering of Markdown blocks while keeping Markdown as the single source of truth.
class BlockReorderSheet extends StatefulWidget {
  const BlockReorderSheet({
    super.key,
    required this.initialMarkdown,
  });

  static const Key sheetKey = Key('note_editor_block_reorder_sheet');

  final String initialMarkdown;

  @override
  State<BlockReorderSheet> createState() => _BlockReorderSheetState();
}

class _BlockReorderSheetState extends State<BlockReorderSheet> {
  late List<MarkdownBlock> _blocks;

  @override
  void initState() {
    super.initState();
    _blocks = List<MarkdownBlock>.from(
      MarkdownBlockService.parseBlocks(widget.initialMarkdown),
    );
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      int target = newIndex;
      if (oldIndex < target) {
        target -= 1;
      }
      final MarkdownBlock moved = _blocks.removeAt(oldIndex);
      _blocks.insert(target, moved);
    });
  }

  void _moveStep(int index, int delta) {
    final int nextIndex = index + delta;
    if (nextIndex < 0 || nextIndex >= _blocks.length) {
      return;
    }
    setState(() {
      final MarkdownBlock moved = _blocks.removeAt(index);
      _blocks.insert(nextIndex, moved);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return SafeArea(
      key: BlockReorderSheet.sheetKey,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.drag_indicator_rounded),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'ブロックを並び替え',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop<String>(),
                  child: const Text('キャンセル'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  key: const Key('block_reorder_apply_button'),
                  onPressed: () => Navigator.of(context).pop<String>(
                    MarkdownBlockService.serializeBlocks(_blocks),
                  ),
                  child: const Text('並び替えを適用'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_blocks.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    '並び替え可能なブロックがまだありません。',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              Flexible(
                child: ReorderableListView.builder(
                  shrinkWrap: true,
                  itemCount: _blocks.length,
                  onReorder: _onReorder,
                  itemBuilder: (BuildContext context, int index) {
                    final MarkdownBlock block = _blocks[index];
                    return Card(
                      key: ValueKey<String>('reorder_block_$index'),
                      margin: const EdgeInsets.only(bottom: 6),
                      child: ListTile(
                        dense: true,
                        leading: Chip(
                          label: Text(
                            block.previewLabel,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                        title: Text(
                          block.previewSnippet,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            IconButton(
                              tooltip: '上へ移動',
                              icon: const Icon(Icons.arrow_upward, size: 18),
                              onPressed:
                                  index > 0 ? () => _moveStep(index, -1) : null,
                            ),
                            IconButton(
                              tooltip: '下へ移動',
                              icon: const Icon(Icons.arrow_downward, size: 18),
                              onPressed: index < _blocks.length - 1
                                  ? () => _moveStep(index, 1)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
