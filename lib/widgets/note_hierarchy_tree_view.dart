import 'package:flutter/material.dart';

import '../../services/note_hierarchy_service.dart';
import '../../services/note_wiki_link_service.dart';

class NoteHierarchyTreeView extends StatelessWidget {
  static const Key treeKey = Key('note_list_hierarchy_tree_view');

  final List<NoteSummary> notes;
  final Set<String> expandedIds;
  final ValueChanged<String> onToggleExpand;
  final ValueChanged<NoteSummary> onOpenNote;
  final ValueChanged<NoteSummary> onAddSubpage;

  const NoteHierarchyTreeView({
    super.key,
    required this.notes,
    required this.expandedIds,
    required this.onToggleExpand,
    required this.onOpenNote,
    required this.onAddSubpage,
  });

  @override
  Widget build(BuildContext context) {
    final List<NoteTreeNode> nodes = NoteHierarchyService.flattenTree(
      allNotes: notes,
      expandedIds: expandedIds,
    );
    if (nodes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('表示できる階層ノートがありません'),
        ),
      );
    }

    final ColorScheme scheme = Theme.of(context).colorScheme;
    return ListView.builder(
      key: treeKey,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
      itemCount: nodes.length,
      itemBuilder: (BuildContext context, int index) {
        final NoteTreeNode node = nodes[index];
        final int visualDepth = node.depth.clamp(0, 6);
        final String title = node.note.title.trim().isEmpty
            ? '無題のメモ'
            : node.note.title.trim();

        return Card(
          margin: EdgeInsets.fromLTRB(visualDepth * 16.0, 3, 0, 3),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: scheme.outlineVariant),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => onOpenNote(node.note),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: <Widget>[
                  if (node.hasChildren)
                    IconButton(
                      key: Key('note_tree_toggle_${node.note.id}'),
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        node.isExpanded
                            ? Icons.expand_more
                            : Icons.chevron_right,
                        size: 20,
                      ),
                      tooltip: node.isExpanded ? '折りたたむ' : '展開する',
                      onPressed: () => onToggleExpand(node.note.id),
                    )
                  else
                    const SizedBox(
                      width: 32,
                      height: 32,
                      child: Icon(Icons.article_outlined, size: 18),
                    ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (node.depth >= 6)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text(
                        'L${node.depth + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  if (node.hasChildren)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${node.childCount}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  IconButton(
                    key: Key('note_tree_add_subpage_${node.note.id}'),
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.add, size: 18),
                    tooltip: 'サブページを作成',
                    onPressed: () => onAddSubpage(node.note),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
