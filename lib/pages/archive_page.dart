import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../models/note.dart';
import '../models/category.dart';
import 'note_editor_page.dart';

class ArchivePage extends StatefulWidget {
  const ArchivePage({super.key});

  @override
  State<ArchivePage> createState() => _ArchivePageState();
}

class _ArchivePageState extends State<ArchivePage> {
  List<Note> _archivedNotes = [];
  List<Category> _categories = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  List<Note> _filteredNotes = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadArchivedNotes();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _applyFilters();
  }

  void _applyFilters() {
    setState(() {
      if (_searchController.text.isEmpty) {
        _filteredNotes = List.from(_archivedNotes);
      } else {
        final query = _searchController.text.toLowerCase();
        _filteredNotes = _archivedNotes.where((note) {
          final titleLower = note.title.toLowerCase();
          final contentLower = note.content.toLowerCase();
          return titleLower.contains(query) || contentLower.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _loadCategories() async {
    try {
      final response = await supabase
          .from('categories')
          .select()
          .eq('user_id', supabase.auth.currentUser!.id)
          .order('name', ascending: true);

      if (!mounted) return;

      setState(() {
        _categories = (response as List)
            .map((category) => Category.fromJson(category))
            .toList();
      });
    } catch (error) {
      // カテゴリがなくても動作可能
    }
  }

  Future<void> _loadArchivedNotes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await supabase
          .from('notes')
          .select()
          .eq('user_id', supabase.auth.currentUser!.id)
          .eq('is_archived', true)
          .order('archived_at', ascending: false);

      if (!mounted) return;

      setState(() {
        _archivedNotes =
            (response as List).map((note) => Note.fromJson(note)).toList();
        _applyFilters();
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラー: $error')),
      );
    }
  }

  Future<void> _restoreNote(Note note) async {
    try {
      await supabase.from('notes').update({
        'is_archived': false,
        'archived_at': null,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', note.id);

      if (!mounted) return;

      _loadArchivedNotes();

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('メモを復元しました'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラー: $error')),
      );
    }
  }

  Future<void> _permanentlyDeleteNote(Note note) async {
    try {
      await supabase.from('notes').delete().eq('id', note.id);

      if (!mounted) return;

      _loadArchivedNotes();

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('メモを完全に削除しました'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラー: $error')),
      );
    }
  }

  void _showRestoreDialog(Note note) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('メモを復元'),
        content:
            Text('「${note.title.isEmpty ? '(タイトルなし)' : note.title}」を復元しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _restoreNote(note);
            },
            child: const Text('復元'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(Note note) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('完全に削除'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                '「${note.title.isEmpty ? '(タイトルなし)' : note.title}」を完全に削除しますか？',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'この操作は取り消せません',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _permanentlyDeleteNote(note);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('完全に削除'),
          ),
        ],
      ),
    );
  }

  Category? _getCategoryById(String? categoryId) {
    if (categoryId == null) return null;
    try {
      return _categories.firstWhere((c) => c.id == categoryId);
    } catch (e) {
      return null;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays < 1) {
      return '今日 ${DateFormat('HH:mm').format(date)}';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}日前';
    } else {
      return DateFormat('yyyy/MM/dd').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('アーカイブ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadArchivedNotes,
            tooltip: '更新',
          ),
        ],
      ),
      body: Column(
        children: [
          // 検索バー
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'アーカイブを検索...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ),

          // 統計情報
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.archive, color: Colors.grey, size: 20),
                const SizedBox(width: 8),
                Text(
                  '${_filteredNotes.length}件のアーカイブ',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // アーカイブ一覧
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredNotes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.archive_outlined,
                              size: 80,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isNotEmpty
                                  ? '該当するアーカイブが見つかりません'
                                  : 'アーカイブされたメモはありません',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'メモを長押ししてアーカイブできます',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadArchivedNotes,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: _filteredNotes.length,
                          itemBuilder: (context, index) {
                            final note = _filteredNotes[index];
                            final category = _getCategoryById(note.categoryId);

                            Color? categoryColor;
                            if (category != null) {
                              categoryColor = Color(
                                int.parse(
                                  category.color.substring(1),
                                  radix: 16,
                                ) +
                                    0xFF000000,
                              );
                            }

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                vertical: 4,
                                horizontal: 8,
                              ),
                              color: Colors.grey[50],
                              child: ListTile(
                                leading: category != null
                                    ? Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: categoryColor!
                                              .withValues(alpha: 0.2),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: categoryColor,
                                            width: 2,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            category.icon,
                                            style:
                                                const TextStyle(fontSize: 20),
                                          ),
                                        ),
                                      )
                                    : const Icon(
                                        Icons.archive,
                                        color: Colors.grey,
                                        size: 32,
                                      ),
                                title: Row(
                                  children: [
                                    const Icon(
                                      Icons.archive,
                                      color: Colors.grey,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        note.title.isEmpty
                                            ? '(タイトルなし)'
                                            : note.title,
                                        style: TextStyle(
                                          color: Colors.grey[700],
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (note.content.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        note.content,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style:
                                            TextStyle(color: Colors.grey[600]),
                                      ),
                                    ],
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        if (category != null) ...[
                                          Text(
                                            category.icon,
                                            style:
                                                const TextStyle(fontSize: 12),
                                          ),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            // ← 追加
                                            child: Text(
                                              category.name,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: categoryColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              overflow:
                                                  TextOverflow.ellipsis, // ← 追加
                                              maxLines: 1, // ← 追加
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '•',
                                            style: TextStyle(
                                                color: Colors.grey[600],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                        Icon(
                                          Icons.archive,
                                          size: 12,
                                          color: Colors.grey[600],
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          // ← 追加
                                          child: Text(
                                            'アーカイブ: ${note.archivedAt != null ? _formatDate(note.archivedAt!) : '不明'}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                            overflow:
                                                TextOverflow.ellipsis, // ← 追加
                                            maxLines: 1, // ← 追加
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.unarchive,
                                          color: Colors.blue,),
                                      onPressed: () => _showRestoreDialog(note),
                                      tooltip: '復元',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_forever,
                                          color: Colors.red),
                                      onPressed: () => _showDeleteDialog(note),
                                      tooltip: '完全に削除',
                                    ),
                                  ],
                                ),
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          NoteEditorPage(note: note),
                                    ),
                                  );
                                  _loadArchivedNotes();
                                },
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
