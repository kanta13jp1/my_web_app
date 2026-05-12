import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ナレッジベースページ
/// knowledge-base Edge Function と連携してナレッジ記事を検索・表示
class KnowledgeBasePage extends StatefulWidget {
  const KnowledgeBasePage({super.key});

  @override
  State<KnowledgeBasePage> createState() => _KnowledgeBasePageState();
}

class _KnowledgeBasePageState extends State<KnowledgeBasePage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  List<dynamic> _articles = [];
  final _queryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _load({String query = ''}) async {
    if (_supabase.auth.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'enterprise-hub',
        body: {'action': 'wiki.list'},
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['pages'] is List) {
        setState(() => _articles = data['pages'] as List);
      } else if (data is Map<String, dynamic> && data['articles'] is List) {
        setState(() => _articles = data['articles'] as List);
      } else if (data is List) {
        setState(() => _articles = data);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'データ取得に失敗しました: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ナレッジベース'),
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _load(query: _queryController.text),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _queryController,
              decoration: InputDecoration(
                hintText: 'キーワードで検索...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onSubmitted: (q) => _load(query: q),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Color(0xFFE53935),
                            height: 1.5,
                          ),
                        ),
                      )
                    : _articles.isEmpty
                        ? const Center(child: Text('記事が見つかりません'))
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: _articles.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final article =
                                  _articles[i] as Map<String, dynamic>;
                              return Card(
                                child: ListTile(
                                  leading: const Icon(
                                    Icons.article,
                                    color: Color(0xFF6366F1),
                                  ),
                                  title: Text(
                                    article['title']?.toString() ?? '(無題)',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      height: 1.5,
                                    ),
                                  ),
                                  subtitle: Text(
                                    article['summary']?.toString() ??
                                        article['content']?.toString() ??
                                        '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: article['category'] != null
                                      ? Chip(
                                          label: Text(
                                            article['category'].toString(),
                                            style: const TextStyle(
                                              fontSize: 11,
                                              height: 1.5,
                                            ),
                                          ),
                                          padding: EdgeInsets.zero,
                                        )
                                      : null,
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
