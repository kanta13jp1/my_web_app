import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ノートコメントページ
/// ノートへのコメント一覧の閲覧・追加・削除
class NoteCommentsPage extends StatefulWidget {
  const NoteCommentsPage({super.key});

  @override
  State<NoteCommentsPage> createState() => _NoteCommentsPageState();
}

class _NoteCommentsPageState extends State<NoteCommentsPage> {
  final _supabase = Supabase.instance.client;
  final _noteIdController = TextEditingController();
  final _commentController = TextEditingController();
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _comments = [];
  int? _loadedNoteId;

  @override
  void dispose() {
    _noteIdController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final noteId = int.tryParse(_noteIdController.text.trim());
    if (noteId == null) {
      setState(() => _errorMessage = 'ノートIDを入力してください');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _supabase.functions.invoke(
        'note-comments',
        queryParameters: {'note_id': noteId.toString()},
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final list = data['comments'] as List<dynamic>? ?? [];
        setState(() {
          _comments = list.cast<Map<String, dynamic>>();
          _loadedNoteId = noteId;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'コメント取得に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addComment() async {
    final noteId = _loadedNoteId;
    final content = _commentController.text.trim();
    if (noteId == null || content.isEmpty) return;

    setState(() => _isSubmitting = true);
    try {
      await _supabase.functions.invoke(
        'note-comments',
        body: {'note_id': noteId, 'content': content},
      );
      _commentController.clear();
      await _load();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'コメント追加に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _deleteComment(String id) async {
    try {
      await _supabase.functions.invoke(
        'note-comments',
        body: {'id': id},
        method: HttpMethod.delete,
      );
      await _load();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'コメント削除に失敗しました: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ノートコメント'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          if (_loadedNoteId != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: '更新',
              onPressed: _load,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _noteIdController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'ノートID',
                      border: OutlineInputBorder(),
                      hintText: '例: 1',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isLoading ? null : _load,
                  child: const Text('取得'),
                ),
              ],
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_loadedNoteId != null) ...[
              Expanded(
                child: _comments.isEmpty
                    ? const Center(
                        child: Text(
                          'コメントがありません',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _comments.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final c = _comments[index];
                          final currentUserId = _supabase.auth.currentUser?.id;
                          final isOwner = currentUserId != null &&
                              c['user_id'] == currentUserId;
                          return ListTile(
                            title: Text(c['content']?.toString() ?? ''),
                            subtitle: Text(
                              c['created_at']?.toString().substring(0, 16) ??
                                  '',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: isOwner
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                    ),
                                    tooltip: 'コメントを削除',
                                    onPressed: () {
                                      final id = c['id'];
                                      if (id is String && id.isNotEmpty) {
                                        _deleteComment(id);
                                      }
                                    },
                                  )
                                : null,
                          );
                        },
                      ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: const InputDecoration(
                        labelText: 'コメントを追加',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _addComment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('送信'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
