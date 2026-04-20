import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 読書リストページ
/// reading-list Edge Function と連携して読書記録を管理
class ReadingListPage extends StatefulWidget {
  const ReadingListPage({super.key});

  @override
  State<ReadingListPage> createState() => _ReadingListPageState();
}

class _ReadingListPageState extends State<ReadingListPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  List<dynamic> _books = [];

  @override
  void initState() {
    super.initState();
    _fetchBooks();
  }

  Future<void> _fetchBooks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'reading-list',
        body: {'action': 'list'},
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['books'] is List) {
        setState(() => _books = data['books'] as List);
      } else if (data is List) {
        setState(() => _books = data);
      } else {
        setState(() => _books = []);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = '読書リストの取得に失敗しました: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('読書リスト'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchBooks,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_errorMessage != null) ...[
              Text(
                _errorMessage!,
                style: const TextStyle(
                  color: Color(0xFFE53935),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _books.isEmpty
                      ? const Center(child: Text('読書リストは空です'))
                      : ListView.builder(
                          itemCount: _books.length,
                          itemBuilder: (context, index) {
                            final item = _books[index];
                            final title = item is Map
                                ? (item['title'] ?? 'タイトルなし')
                                : item.toString();
                            final author =
                                item is Map ? (item['author'] ?? '') : '';
                            final status =
                                item is Map ? (item['status'] ?? '') : '';
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                leading: const Icon(Icons.menu_book),
                                title: Text(title.toString()),
                                subtitle: author.toString().isNotEmpty
                                    ? Text(author.toString())
                                    : null,
                                trailing: status.toString().isNotEmpty
                                    ? Chip(label: Text(status.toString()))
                                    : null,
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddBookDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddBookDialog(BuildContext context) {
    final titleController = TextEditingController();
    final authorController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('本を追加'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'タイトル'),
            ),
            TextField(
              controller: authorController,
              decoration: const InputDecoration(labelText: '著者'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _supabase.functions.invoke(
                  'reading-list',
                  body: {
                    'action': 'add',
                    'title': titleController.text.trim(),
                    'author': authorController.text.trim(),
                  },
                );
                await _fetchBooks();
              } catch (e) {
                if (mounted) {
                  setState(() => _errorMessage = '本の追加に失敗しました: $e');
                }
              }
            },
            child: const Text('追加'),
          ),
        ],
      ),
    );
  }
}
