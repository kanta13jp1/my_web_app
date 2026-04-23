import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/note_comments_panel.dart';

class NoteCommentsPage extends StatefulWidget {
  const NoteCommentsPage({
    super.key,
    this.initialNoteId,
  });

  final int? initialNoteId;

  @override
  State<NoteCommentsPage> createState() => _NoteCommentsPageState();
}

class _NoteCommentsPageState extends State<NoteCommentsPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  late final TextEditingController _noteIdController;

  int? _loadedNoteId;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadedNoteId = widget.initialNoteId;
    _noteIdController = TextEditingController(
      text: widget.initialNoteId?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _noteIdController.dispose();
    super.dispose();
  }

  void _openComments() {
    final noteId = int.tryParse(_noteIdController.text.trim());
    if (noteId == null || noteId <= 0) {
      setState(() {
        _errorMessage = 'ノートIDを数字で入力してください。';
      });
      return;
    }

    setState(() {
      _loadedNoteId = noteId;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ノートコメント'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'コメントしたいノートIDを指定すると、Notion風のコメントパネルをそのまま開けます。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _noteIdController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'ノートID',
                      hintText: '例: 1',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _openComments(),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _openComments,
                  icon: const Icon(Icons.comment_outlined),
                  label: const Text('開く'),
                ),
              ],
            ),
            if (_errorMessage != null) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Expanded(
              child: _loadedNoteId == null
                  ? DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color:
                              theme.colorScheme.outline.withValues(alpha: 0.22),
                        ),
                        color: theme.colorScheme.surfaceContainerLowest,
                      ),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'ノートIDを入れると、コメント一覧・投稿・削除を同じパネルで扱えます。',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),
                    )
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color:
                              theme.colorScheme.outline.withValues(alpha: 0.18),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: NoteCommentsPanel(
                          noteId: _loadedNoteId!,
                          currentUserId: _supabase.auth.currentUser?.id,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
