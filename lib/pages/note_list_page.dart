import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'note_editor_page.dart';

class NoteListPage extends StatefulWidget {
  const NoteListPage({super.key});

  @override
  State<NoteListPage> createState() => _NoteListPageState();
}

class _NoteListPageState extends State<NoteListPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _notes = [];

  @override
  void initState() {
    super.initState();
    _fetchNotes();
  }

  Future<void> _fetchNotes() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final data = await _supabase
          .from('notes')
          .select('id, title, content, created_at, is_pinned')
          .eq('user_id', userId)
          .eq('is_archived', false) // アーカイブ済みは除外
          .order('is_pinned', ascending: false) // ピン留め優先
          .order('created_at', ascending: false); // 新しい順

      if (mounted) {
        setState(() {
          _notes = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('エラー: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ナレッジベース (メモ一覧)'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.note_alt_outlined,
                          size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('まだメモがありません',
                          style: TextStyle(fontSize: 18, color: Colors.grey)),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('新しいメモを作成'),
                        onPressed: () => _navigateToEditor(context),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _notes.length,
                  itemBuilder: (context, index) {
                    final note = _notes[index];
                    final created = DateTime.parse(note['created_at']);
                    final dateStr =
                        DateFormat('yyyy/MM/dd HH:mm').format(created);
                    final isPinned = note['is_pinned'] as bool? ?? false;

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: Icon(
                          isPinned ? Icons.push_pin : Icons.description,
                          color: isPinned ? Colors.orange : Colors.blue,
                        ),
                        title: Text(
                          (note['title'] as String?)?.isNotEmpty == true
                              ? note['title']
                              : '無題のメモ',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              note['content'] ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Text(dateStr,
                                style: TextStyle(
                                    color: Colors.grey[400], fontSize: 10)),
                          ],
                        ),
                        onTap: () => _navigateToEditor(context, note['id']),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToEditor(context),
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _navigateToEditor(BuildContext context, [String? noteId]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NoteEditorPage(noteId: noteId),
      ),
    );
    // 戻ってきたらリストを更新
    _fetchNotes();
  }
}
