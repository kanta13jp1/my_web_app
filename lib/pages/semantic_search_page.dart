import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// セマンティック検索ページ
/// semantic-search Edge Function と連携して意味ベースの検索を提供
class SemanticSearchPage extends StatefulWidget {
  const SemanticSearchPage({super.key});

  @override
  State<SemanticSearchPage> createState() => _SemanticSearchPageState();
}

class _SemanticSearchPageState extends State<SemanticSearchPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  List<dynamic> _results = [];
  final _queryController = TextEditingController();

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) return;
    if (_supabase.auth.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _results = [];
    });
    try {
      final response = await _supabase.functions.invoke(
        'enterprise-hub',
        body: {'action': 'search.semantic', 'query': query, 'limit': 20},
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['results'] is List) {
        setState(() => _results = data['results'] as List);
      } else if (data is List) {
        setState(() => _results = data);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = '検索に失敗しました: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text('セマンティック検索'),
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _queryController,
                    decoration: InputDecoration(
                      hintText: '意味で検索（例: 先週のタスク一覧）',
                      prefixIcon: const Icon(Icons.psychology),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isLoading ? null : _search,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3D5AFE),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('検索'),
                ),
              ],
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
                    : _results.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.manage_search,
                                  size: 48,
                                  color: Color(0xFFB0B0B0),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'キーワードを入力して検索してください',
                                  style: TextStyle(
                                    color: Color(0xFFB0B0B0),
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: _results.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final item = _results[i] as Map<String, dynamic>;
                              final score = item['similarity'] ??
                                  item['score'] ??
                                  item['relevance'];
                              return Card(
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        const Color(0xFF3D5AFE).withAlpha(30),
                                    child: Text(
                                      '${i + 1}',
                                      style: const TextStyle(
                                        color: Color(0xFF3D5AFE),
                                        fontWeight: FontWeight.bold,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    item['title']?.toString() ?? '(無題)',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      height: 1.5,
                                    ),
                                  ),
                                  subtitle: Text(
                                    item['content']?.toString() ??
                                        item['summary']?.toString() ??
                                        '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: score != null
                                      ? Text(
                                          '${(double.tryParse(score.toString()) ?? 0 * 100).toStringAsFixed(0)}%',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF3D5AFE),
                                            height: 1.5,
                                          ),
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
