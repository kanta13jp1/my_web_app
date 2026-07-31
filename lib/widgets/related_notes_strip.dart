import 'package:flutter/material.dart';

import '../services/note_semantic_search_service.dart';

class RelatedNotesStrip extends StatelessWidget {
  const RelatedNotesStrip({
    super.key,
    required this.notes,
    required this.isLoading,
    required this.onNoteTap,
    this.hasError = false,
    this.onRetry,
    this.compact = false,
  });

  final List<NoteSearchResult> notes;
  final bool isLoading;
  final bool hasError;
  final ValueChanged<NoteSearchResult> onNoteTap;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const Key('related_notes_strip'),
      height: compact ? 76 : 148,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
          : const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: compact
          ? Row(
              children: [
                Icon(
                  Icons.auto_awesome_outlined,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text('関連メモ', style: theme.textTheme.labelLarge),
                if (isLoading) ...[
                  const SizedBox(width: 8),
                  const SizedBox(
                    key: Key('related_notes_loading'),
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
                const SizedBox(width: 12),
                Expanded(child: _buildContent(context)),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_outlined,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text('関連するメモ', style: theme.textTheme.titleSmall),
                    if (isLoading) ...[
                      const SizedBox(width: 10),
                      const SizedBox(
                        key: Key('related_notes_loading'),
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(child: _buildContent(context)),
              ],
            ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);
    if (hasError && notes.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          key: const Key('related_notes_retry'),
          onPressed: onRetry,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('関連メモを再読み込み'),
        ),
      );
    }
    if (isLoading && notes.isEmpty) {
      return const SizedBox.shrink();
    }
    if (notes.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(
          '関連するメモはまだありません',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView.separated(
      key: const Key('related_notes_list'),
      scrollDirection: Axis.horizontal,
      itemCount: notes.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (context, index) {
        final note = notes[index];
        return SizedBox(
          width: compact ? 180 : 224,
          child: Material(
            color: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: InkWell(
              key: Key('related_note_${note.id}'),
              borderRadius: BorderRadius.circular(6),
              onTap: () => onNoteTap(note),
              child: Padding(
                padding: compact
                    ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6)
                    : const EdgeInsets.all(10),
                child: compact
                    ? Row(
                        children: [
                          Expanded(
                            child: Text(
                              note.title.trim().isEmpty ? '無題のメモ' : note.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelMedium,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right, size: 16),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            note.title.trim().isEmpty ? '無題のメモ' : note.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            note.content.trim().isEmpty ? '本文なし' : note.content,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}
