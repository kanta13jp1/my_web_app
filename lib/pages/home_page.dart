import 'package:flutter/material.dart';
import '../main.dart';
import '../models/note.dart';
import 'auth_page.dart';
import 'note_editor_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Note> _notes = [];
  List<Note> _filteredNotes = [];
  bool _isLoading = true;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadNotes();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _filterNotes(_searchController.text);
  }

  void _filterNotes(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredNotes = List.from(_notes);
      } else {
        _filteredNotes = _notes.where((note) {
          final titleLower = note.title.toLowerCase();
          final contentLower = note.content.toLowerCase();
          final queryLower = query.toLowerCase();
          return titleLower.contains(queryLower) || 
                 contentLower.contains(queryLower);
        }).toList();
      }
    });
  }

  Future<void> _loadNotes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await supabase
          .from('notes')
          .select()
          .eq('user_id', supabase.auth.currentUser!.id)
          .order('updated_at', ascending: false);

      setState(() {
        _notes = (response as List).map((note) => Note.fromJson(note)).toList();
        _filteredNotes = List.from(_notes);
        _isLoading = false;
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $error')),
        );
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteNote(String noteId) async {
    try {
      await supabase.from('notes').delete().eq('id', noteId);
      _loadNotes();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('メモを削除しました')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $error')),
        );
      }
    }
  }

  Future<void> _signOut() async {
    await supabase.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthPage()),
      );
    }
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _filteredNotes = List.from(_notes);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 2,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'メモを検索...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white70),
                ),
                style: const TextStyle(color: Colors.white, fontSize: 18),
                cursorColor: Colors.white,
              )
            : const Text('マイメモ'),
        actions: [
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
              },
              tooltip: 'クリア',
            ),
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
            tooltip: _isSearching ? '検索を閉じる' : '検索',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNotes,
            tooltip: '更新',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: 'ログアウト',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 検索結果の件数表示
                if (_isSearching && _searchController.text.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    color: Colors.blue.withOpacity(0.1),
                    child: Text(
                      '${_filteredNotes.length}件のメモが見つかりました',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                // メモ一覧
                Expanded(
                  child: _filteredNotes.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _isSearching && _searchController.text.isNotEmpty
                                    ? Icons.search_off
                                    : Icons.note_add_outlined,
                                size: 80,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _isSearching && _searchController.text.isNotEmpty
                                    ? '検索結果が見つかりません'
                                    : 'メモがありません',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _isSearching && _searchController.text.isNotEmpty
                                    ? '別のキーワードで検索してみてください'
                                    : '右下の + ボタンから新しいメモを作成',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadNotes,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(8),
                            itemCount: _filteredNotes.length,
                            itemBuilder: (context, index) {
                              final note = _filteredNotes[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(
                                  vertical: 4,
                                  horizontal: 8,
                                ),
                                child: ListTile(
                                  title: _buildHighlightedText(
                                    note.title.isEmpty ? '(タイトルなし)' : note.title,
                                    _searchController.text,
                                    isTitle: true,
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (note.content.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        _buildHighlightedText(
                                          note.content,
                                          _searchController.text,
                                          maxLines: 2,
                                        ),
                                      ],
                                      const SizedBox(height: 4),
                                      Text(
                                        '更新: ${_formatDate(note.updatedAt)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _showDeleteDialog(note),
                                  ),
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => NoteEditorPage(note: note),
                                      ),
                                    );
                                    _loadNotes();
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NoteEditorPage()),
          );
          _loadNotes();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  // 検索キーワードをハイライト表示するウィジェット
  Widget _buildHighlightedText(
    String text,
    String query, {
    bool isTitle = false,
    int? maxLines,
  }) {
    if (query.isEmpty) {
      return Text(
        text,
        style: TextStyle(
          fontWeight: isTitle ? FontWeight.bold : FontWeight.normal,
        ),
        maxLines: maxLines,
        overflow: maxLines != null ? TextOverflow.ellipsis : null,
      );
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;

    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        // 残りのテキストを追加
        if (start < text.length) {
          spans.add(TextSpan(text: text.substring(start)));
        }
        break;
      }

      // マッチ前のテキストを追加
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }

      // マッチしたテキストをハイライト
      spans.add(
        TextSpan(
          text: text.substring(index, index + query.length),
          style: const TextStyle(
            backgroundColor: Colors.yellow,
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

      start = index + query.length;
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(
          color: Colors.black87,
          fontWeight: isTitle ? FontWeight.bold : FontWeight.normal,
          fontSize: isTitle ? 16 : 14,
        ),
        children: spans,
      ),
      maxLines: maxLines,
      overflow: maxLines != null ? TextOverflow.ellipsis : TextOverflow.visible,
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) {
      return 'たった今';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}分前';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}時間前';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}日前';
    } else {
      return '${date.year}/${date.month}/${date.day}';
    }
  }

  void _showDeleteDialog(Note note) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('メモを削除'),
        content: const Text('このメモを削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteNote(note.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }
}