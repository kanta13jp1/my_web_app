import 'package:flutter/material.dart';

import '../../services/note_wiki_link_service.dart';

/// Displays outgoing `[[Page]]` links (resolved or creatable) and incoming
/// backlinks referencing the current note.
class NoteBacklinksPanel extends StatelessWidget {
  const NoteBacklinksPanel({
    super.key,
    required this.outgoingLinks,
    required this.allNotes,
    required this.currentNoteId,
    required this.backlinks,
    required this.onOpenNote,
    required this.onCreateLinkedNote,
  });

  static const Key panelKey = Key('note_editor_backlinks_panel');

  final List<WikiLinkRef> outgoingLinks;
  final List<NoteSummary> allNotes;
  final String? currentNoteId;
  final List<NoteBacklink> backlinks;
  final ValueChanged<NoteSummary> onOpenNote;
  final ValueChanged<String> onCreateLinkedNote;

  @override
  Widget build(BuildContext context) {
    if (outgoingLinks.isEmpty && backlinks.isEmpty) {
      return const SizedBox.shrink();
    }

    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Card(
      key: panelKey,
      margin: const EdgeInsets.only(top: 10),
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: Icon(Icons.hub_outlined, color: colorScheme.primary, size: 20),
        title: Text(
          'ページリンク (${outgoingLinks.length}) ・ バックリンク (${backlinks.length})',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: <Widget>[
          if (outgoingLinks.isNotEmpty) ...<Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'リンク先ページ',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: outgoingLinks.map((WikiLinkRef link) {
                final NoteSummary? resolved = NoteWikiLinkService.resolveLink(
                  link.targetTitle,
                  allNotes,
                  excludeNoteId: currentNoteId,
                );
                if (resolved != null) {
                  return ActionChip(
                    avatar: const Icon(Icons.link, size: 16),
                    label: Text(link.displayLabel),
                    onPressed: () => onOpenNote(resolved),
                  );
                }
                return ActionChip(
                  avatar: const Icon(Icons.add, size: 16),
                  label: Text('${link.displayLabel} (新規作成)'),
                  onPressed: () => onCreateLinkedNote(link.targetTitle),
                );
              }).toList(growable: false),
            ),
          ],
          if (outgoingLinks.isNotEmpty && backlinks.isNotEmpty)
            const SizedBox(height: 12),
          if (backlinks.isNotEmpty) ...<Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'バックリンク（このノートを参照中）',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 4),
            for (final NoteBacklink backlink in backlinks)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.subdirectory_arrow_right, size: 18),
                title: Text(
                  backlink.sourceTitle,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: backlink.snippet.isEmpty
                    ? null
                    : Text(
                        backlink.snippet,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                onTap: () => onOpenNote(
                  NoteSummary(
                    id: backlink.sourceNoteId,
                    title: backlink.sourceTitle,
                    content: '',
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
