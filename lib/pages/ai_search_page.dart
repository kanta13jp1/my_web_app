import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AiSearchPage extends StatefulWidget {
  const AiSearchPage({super.key});

  @override
  State<AiSearchPage> createState() => _AiSearchPageState();
}

class _AiSearchPageState extends State<AiSearchPage> {
  final _supabase = Supabase.instance.client;
  final _queryController = TextEditingController();
  bool _isLoading = false;
  List<Map<String, dynamic>> _results = [];
  String? _explanation;
  String? _errorMessage;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _results = [];
      _explanation = null;
    });

    try {
      final response = await _supabase.functions.invoke(
        'ai-search',
        body: {'query': query, 'limit': 20},
      );
      final data = response.data as Map<String, dynamic>?;
      if (data == null || data['success'] != true) {
        throw Exception(data?['error'] ?? '検索に失敗しました');
      }
      final rawResults = data['results'] as List<dynamic>? ?? [];
      setState(() {
        _results = rawResults.cast<Map<String, dynamic>>();
        _explanation = data['explanation'] as String?;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI セマンティック検索'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _queryController,
                    decoration: const InputDecoration(
                      hintText: '自然言語でメモを検索...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isLoading ? null : _search,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('検索'),
                ),
              ],
            ),
            if (_explanation != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'AI: $_explanation',
                  style: const TextStyle(
                      fontSize: 12, color: Colors.deepPurple),
                ),
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_errorMessage!,
                    style: const TextStyle(color: Colors.red)),
              ),
            ],
            const SizedBox(height: 16),
            if (_results.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${_results.length} 件の結果',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            Expanded(
              child: _results.isEmpty && !_isLoading
                  ? const Center(
                      child: Text('キーワードを入力して検索してください',
                          style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final note = _results[index];
                        final tags =
                            (note['tags'] as List<dynamic>?)?.cast<String>() ??
                                [];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const Icon(Icons.note,
                                color: Colors.deepPurple),
                            title: Text(
                              note['title'] as String? ?? '(タイトルなし)',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if ((note['content'] as String?) != null)
                                  Text(
                                    (note['content'] as String)
                                        .substring(
                                            0,
                                            (note['content'] as String)
                                                .length
                                                .clamp(0, 100))
                                        .replaceAll('\n', ' '),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                if (tags.isNotEmpty)
                                  Wrap(
                                    spacing: 4,
                                    children: tags
                                        .map((tag) => Chip(
                                              label: Text(tag,
                                                  style: const TextStyle(
                                                      fontSize: 10)),
                                              padding: EdgeInsets.zero,
                                              materialTapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                            ))
                                        .toList(),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
