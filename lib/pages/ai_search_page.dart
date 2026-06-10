import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// AI 自然言語ノート検索ページ
/// OpenAI 設定時: AI ランキング検索
/// OpenAI 未設定時: ILIKE ベースの全文検索にフォールバック
class AiSearchPage extends StatefulWidget {
  const AiSearchPage({super.key});

  @override
  State<AiSearchPage> createState() => _AiSearchPageState();
}

class _AiSearchPageState extends State<AiSearchPage> {
  final _supabase = Supabase.instance.client;
  final _controller = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _results = [];
  String _searchMode = ''; // 'ai', 'text', 'text_fallback'

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    if (_supabase.auth.currentUser == null) {
      setState(() => _errorMessage = 'この機能はログインが必要です');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _results = [];
      _searchMode = '';
    });

    try {
      // ai-search EF は ai-hub:search.query に統合済み (Windowsアプリ版#92)
      final response = await _supabase.functions.invoke(
        'ai-hub',
        body: {
          'action': 'search.query',
          'query': trimmed,
          'limit': 20,
          'mode': 'auto',
          'includeRelated': true,
          'relatedLimit': 3,
        },
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        final results = data['results'];
        setState(() {
          _results = results is List
              ? List<Map<String, dynamic>>.from(
                  results.map((e) => Map<String, dynamic>.from(e as Map)),
                )
              : [];
          _searchMode = (data['searchMode'] as String? ?? '');
        });
      } else if (data is List) {
        setState(() {
          _results = List<Map<String, dynamic>>.from(
            data.map((e) => Map<String, dynamic>.from(e as Map)),
          );
        });
      } else {
        setState(() => _results = []);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '検索に失敗しました: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _noteTitle(Map<String, dynamic> note) {
    final title = (note['title'] as String? ?? '').trim();
    return title.isEmpty ? '無題のメモ' : title;
  }

  String _noteExcerpt(Map<String, dynamic> note) {
    final content = (note['content'] as String? ?? '').trim();
    if (content.length <= 120) return content;
    return '${content.substring(0, 120)}...';
  }

  List<String> _noteTags(Map<String, dynamic> note) {
    final tags = note['tags'];
    if (tags is List) {
      return tags.map((e) => e.toString()).toList();
    }
    return [];
  }

  List<Map<String, dynamic>> _relatedNotes(Map<String, dynamic> note) {
    final related = note['related_notes'];
    if (related is List) {
      return related
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
    }
    return const <Map<String, dynamic>>[];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('ノート検索'),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        foregroundColor: isDark ? Colors.white : const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: Column(
        children: [
          // 検索バー
          Container(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: '自然言語で検索（例: 先月の振り返りメモ）',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _controller.clear();
                              setState(() {
                                _results = [];
                                _errorMessage = null;
                                _searchMode = '';
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF1F5F9),
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: _search,
                  onChanged: (_) => setState(() {}),
                ),
                if (_searchMode.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        _searchMode == 'ai'
                            ? Icons.auto_awesome
                            : Icons.text_fields,
                        size: 13,
                        color: _searchMode == 'ai'
                            ? const Color(0xFF6366F1)
                            : const Color(0xFF9E9E9E),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _searchMode == 'ai'
                            ? 'AI 検索'
                            : _searchMode == 'text_fallback'
                                ? 'テキスト検索（AIフォールバック）'
                                : 'テキスト検索',
                        style: TextStyle(
                          fontSize: 11,
                          color: _searchMode == 'ai'
                              ? const Color(0xFF6366F1)
                              : const Color(0xFF9E9E9E),
                          height: 1.5,
                        ),
                      ),
                      if (_results.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          '${_results.length}件',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          // コンテンツ
          Expanded(child: _buildBody(isDark)),
        ],
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('検索中...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: Color(0xFFE57373),
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFEF5350), height: 1.5),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _search(_controller.text),
                icon: const Icon(Icons.refresh),
                label: const Text('再試行'),
              ),
            ],
          ),
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.manage_search,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              _controller.text.isEmpty ? 'キーワードを入力して検索' : '該当するノートが見つかりませんでした',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final note = _results[index];
        return _buildNoteCard(note, isDark);
      },
    );
  }

  Widget _buildNoteCard(Map<String, dynamic> note, bool isDark) {
    final title = _noteTitle(note);
    final excerpt = _noteExcerpt(note);
    final tags = _noteTags(note);
    final relatedNotes = _relatedNotes(note);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Card(
      color: cardColor,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // タイトル
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
                height: 1.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (excerpt.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                excerpt,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: tags.map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withAlpha(20),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      tag,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6366F1),
                        height: 1.5,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            if (relatedNotes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Related notes',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              ...relatedNotes.take(3).map((related) {
                final relatedTitle = (related['title'] as String? ?? '').trim();
                final label =
                    relatedTitle.isEmpty ? 'Untitled note' : relatedTitle;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.link,
                        size: 14,
                        color: Color(0xFF6366F1),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}
