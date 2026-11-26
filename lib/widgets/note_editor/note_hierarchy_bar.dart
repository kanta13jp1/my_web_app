import 'package:flutter/material.dart';

import '../../services/note_hierarchy_service.dart';
import '../../services/note_wiki_link_service.dart';

class NoteHierarchyBar extends StatelessWidget {
  static const Key barKey = Key('note_editor_breadcrumbs_bar');
  static const Key subpagesKey = Key('note_editor_subpages_section');
  static const Key addSubpageButtonKey = Key('note_editor_add_subpage_button');
  static const Key changeParentButtonKey =
      Key('note_editor_change_parent_button');

  final String? currentNoteId;
  final String? parentNoteId;
  final String currentTitle;
  final List<NoteSummary> allNotes;
  final ValueChanged<NoteSummary> onOpenNote;
  final VoidCallback onAddSubpage;
  final VoidCallback onChangeParent;

  const NoteHierarchyBar({
    super.key,
    required this.currentNoteId,
    required this.parentNoteId,
    required this.currentTitle,
    required this.allNotes,
    required this.onOpenNote,
    required this.onAddSubpage,
    required this.onChangeParent,
  });

  List<NoteSummary> _resolveAncestors() {
    if (parentNoteId == null || parentNoteId!.isEmpty) {
      return const <NoteSummary>[];
    }
    return NoteHierarchyService.buildBreadcrumbs(
      noteId: parentNoteId!,
      allNotes: allNotes,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<NoteSummary> ancestors = _resolveAncestors();
    final List<NoteSummary> children =
        currentNoteId == null || currentNoteId!.isEmpty
            ? const <NoteSummary>[]
            : NoteHierarchyService.directChildren(
                parentNoteId: currentNoteId!,
                allNotes: allNotes,
              );
    final String displayCurrent =
        currentTitle.trim().isEmpty ? '無題のメモ' : currentTitle.trim();

    return Container(
      key: barKey,
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.account_tree_outlined,
                size: 16,
                color: scheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: <Widget>[
                      Text(
                        '階層:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 4),
                      if (ancestors.isEmpty)
                        Text(
                          'ルート',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        )
                      else
                        ...ancestors.map(
                          (NoteSummary ancestor) => Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              InkWell(
                                borderRadius: BorderRadius.circular(6),
                                onTap: () => onOpenNote(ancestor),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  child: Text(
                                    ancestor.title.trim().isEmpty
                                        ? '無題のメモ'
                                        : ancestor.title.trim(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: scheme.primary,
                                    ),
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                size: 14,
                                color: scheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                      if (ancestors.isEmpty)
                        Icon(
                          Icons.chevron_right,
                          size: 14,
                          color: scheme.onSurfaceVariant,
                        ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 160),
                        child: Text(
                          displayCurrent,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              TextButton.icon(
                key: changeParentButtonKey,
                onPressed: onChangeParent,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                icon: const Icon(Icons.drive_file_move_outline, size: 15),
                label: const Text('親を変更', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          if (currentNoteId != null && currentNoteId!.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Wrap(
              key: subpagesKey,
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                ...children.map(
                  (NoteSummary child) => ActionChip(
                    avatar:
                        const Icon(Icons.subdirectory_arrow_right, size: 14),
                    label: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 160),
                      child: Text(
                        child.title.trim().isEmpty
                            ? '無題のメモ'
                            : child.title.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    onPressed: () => onOpenNote(child),
                  ),
                ),
                ActionChip(
                  key: addSubpageButtonKey,
                  avatar: const Icon(Icons.add, size: 15),
                  label: const Text('サブページを追加'),
                  onPressed: onAddSubpage,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

Future<String?> showParentNotePickerSheet(
  BuildContext context, {
  required String currentNoteId,
  required String? currentParentId,
  required List<NoteSummary> allNotes,
}) {
  final List<NoteSummary> candidates = allNotes
      .where(
        (NoteSummary candidate) => NoteHierarchyService.canSetParent(
          noteId: currentNoteId,
          newParentNoteId: candidate.id,
          allNotes: allNotes,
        ),
      )
      .toList(growable: false);

  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext sheetContext) {
      return SafeArea(
        child: SizedBox(
          key: const Key('note_editor_parent_picker_sheet'),
          height: 360,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  '親ページを選択',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.layers_clear_outlined),
                title: const Text('トップレベル（親なし）'),
                trailing: currentParentId == null || currentParentId.isEmpty
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(''),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: candidates.length,
                  itemBuilder: (BuildContext context, int index) {
                    final NoteSummary item = candidates[index];
                    final String title =
                        item.title.trim().isEmpty ? '無題のメモ' : item.title.trim();
                    final bool selected = item.id == currentParentId;
                    return ListTile(
                      leading: const Icon(Icons.description_outlined),
                      title: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: selected ? const Icon(Icons.check) : null,
                      onTap: () => Navigator.of(sheetContext).pop(item.id),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
