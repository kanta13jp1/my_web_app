import 'package:flutter/material.dart';

import '../services/note_tag_service.dart';

class NoteTagsField extends StatefulWidget {
  const NoteTagsField({
    super.key,
    required this.tags,
    required this.onChanged,
    this.enabled = true,
  });

  final List<String> tags;
  final ValueChanged<List<String>> onChanged;
  final bool enabled;

  @override
  State<NoteTagsField> createState() => _NoteTagsFieldState();
}

class _NoteTagsFieldState extends State<NoteTagsField> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addTag([String? rawValue]) {
    if (!widget.enabled) return;
    final value = rawValue ?? _controller.text;
    final nextTags = NoteTagService.normalize(<String>[...widget.tags, value]);
    _controller.clear();
    if (!NoteTagService.equals(nextTags, widget.tags)) {
      widget.onChanged(nextTags);
    }
  }

  void _removeTag(String tag) {
    if (!widget.enabled) return;
    widget.onChanged(
      widget.tags
          .where((candidate) => candidate != tag)
          .toList(growable: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      label: 'タグ編集',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.sell_outlined,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text('タグ', style: theme.textTheme.labelLarge),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            key: const Key('note_tags_wrap'),
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final tag in widget.tags)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 240),
                  child: InputChip(
                    key: ValueKey<String>('note_tag_chip_$tag'),
                    label: Text(
                      tag,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    deleteIcon: const Icon(
                      Icons.close,
                      key: Key('note_tag_delete_icon'),
                    ),
                    onDeleted: widget.enabled ? () => _removeTag(tag) : null,
                  ),
                ),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 160, maxWidth: 260),
                child: TextField(
                  key: const Key('note_tags_input'),
                  controller: _controller,
                  enabled: widget.enabled,
                  textInputAction: TextInputAction.done,
                  onSubmitted: _addTag,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'タグを追加',
                    suffixIcon: IconButton(
                      key: const Key('note_tags_add_button'),
                      tooltip: 'タグを追加',
                      onPressed: widget.enabled ? _addTag : null,
                      icon: const Icon(Icons.add),
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
