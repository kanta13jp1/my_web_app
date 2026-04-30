import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MemorySearchHubPage extends StatefulWidget {
  const MemorySearchHubPage({super.key});

  @override
  State<MemorySearchHubPage> createState() => _MemorySearchHubPageState();
}

class _MemorySearchHubPageState extends State<MemorySearchHubPage> {
  final _queryController = TextEditingController();
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _results = [];

  Future<void> _search() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _results = [];
    });
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'memory-search-hub',
        body: {'action': 'search', 'query': query, 'limit': 20},
      );
      final data = res.data as Map<String, dynamic>?;
      final hits =
          (data?['results'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      setState(() => _results = hits);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('メモリー検索ハブ'),
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _queryController,
                    decoration: const InputDecoration(
                      hintText: '検索キーワードを入力 (BM25 + ベクター検索)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _loading ? null : _search,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('検索'),
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          Expanded(
            child: _results.isEmpty && !_loading
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.memory, size: 48, color: Color(0xFF6366F1)),
                        SizedBox(height: 12),
                        Text('キーワードを入力してメモリーを検索'),
                        SizedBox(height: 4),
                        Text(
                          'BM25 + ベクター検索 + Haiku リランキング',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _results.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final item = _results[i];
                      final rawScore = item['score'] ?? item['bm25_score'];
                      final score = rawScore is num ? rawScore : 0.0;
                      final metadata = item['metadata'];
                      final source = metadata is Map
                          ? metadata['source'] ?? item['source'] ?? ''
                          : item['source'] ?? '';
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              const Color(0xFF6366F1).withAlpha(30),
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                              color: Color(0xFF6366F1),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        title: Text(
                          item['content'] as String? ??
                              item['text'] as String? ??
                              '(内容なし)',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          'スコア: ${score.toStringAsFixed(3)}  |  $source',
                          style: const TextStyle(fontSize: 11),
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
