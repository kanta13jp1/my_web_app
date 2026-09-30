import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// AI 自然言語ノート検索ページ
/// OpenAI 設定時: AI ランキング検索
/// OpenAI 未設定時: ILIKE ベースの全文検索にフォールバック
class AiSearchPage extends StatefulWidget {
  const AiSearchPage({super.key, this.search});

  /// Optional data source for embedding and controlled UI tests.
  final Future<Object?> Function(String query)? search;

  @override
  State<AiSearchPage> createState() => _AiSearchPageState();
}

class _AiSearchPageState extends State<AiSearchPage> {
  final _controller = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _results = [];
  String _searchMode = ''; // 'ai', 'text', 'text_fallback'
  int _requestId = 0;
  String? _pendingQuery;
  String? _resultQuery;
  String? _failedQuery;

  @override
  void dispose() {
    _requestId++;
    _controller.dispose();
    super.dispose();
  }

  Future<Object?> _request(String query) async {
    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) {
      throw StateError('この機能はログインが必要です');
    }
    final response = await client.functions.invoke(
      'ai-hub',
      body: {
        'action': 'search.query',
        'query': query,
        'limit': 20,
        'mode': 'auto',
      },
    );
    return response.data;
  }

  void _clear() {
    _requestId++;
    _controller.clear();
    setState(() {
      _isLoading = false;
      _pendingQuery = null;
      _resultQuery = null;
      _failedQuery = null;
      _results = [];
      _searchMode = '';
      _errorMessage = null;
    });
  }

  Future<void> _search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty || (_isLoading && _pendingQuery == trimmed)) return;
    final requestId = ++_requestId;
    setState(() {
      _isLoading = true;
      _pendingQuery = trimmed;
      _errorMessage = null;
      _failedQuery = null;
    });
    try {
      final data = await (widget.search ?? _request)(trimmed)
          .timeout(const Duration(seconds: 30));
      if (!mounted || requestId != _requestId) return;
      final Object? rawResults;
      final String searchMode;
      if (data is Map<String, dynamic> && data['results'] is List) {
        rawResults = data['results'];
        searchMode = data['searchMode']?.toString() ?? '';
      } else if (data is List) {
        rawResults = data;
        searchMode = '';
      } else {
        throw const FormatException('Invalid search response');
      }
      final results = (rawResults as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      setState(() {
        _results = results;
        _searchMode = searchMode;
        _resultQuery = trimmed;
      });
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _failedQuery = trimmed;
        _errorMessage = error is StateError
            ? error.message.toString()
            : error is TimeoutException
                ? '検索に時間がかかっています。もう一度お試しください。'
                : '検索できませんでした。通信状態を確認して再試行してください。';
      });
    } finally {
      if (mounted && requestId == _requestId) {
        setState(() {
          _isLoading = false;
          _pendingQuery = null;
        });
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
                    labelText: 'ノートの検索語',
                    hintText: '自然言語で検索（例: 先月の振り返りメモ）',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            tooltip: '検索をクリア',
                            onPressed: _clear,
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
                  onChanged: (value) {
                    if (value.trim().isEmpty) {
                      _clear();
                    } else {
                      setState(() {});
                    }
                  },
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _controller.text.trim().isEmpty ||
                          (_isLoading &&
                              _pendingQuery == _controller.text.trim())
                      ? null
                      : () => _search(_controller.text),
                  icon: const Icon(Icons.search),
                  label: const Text('検索'),
                ),
                if (_isLoading) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(),
                  Text('「$_pendingQuery」を検索中…'),
                ],
                if (_resultQuery != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    (_isLoading || _controller.text.trim() != _resultQuery)
                        ? '前の結果:「$_resultQuery」（${_results.length}件）'
                        : '「$_resultQuery」の結果（${_results.length}件）',
                  ),
                ],
                if (_errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _search(_failedQuery!),
                    icon: const Icon(Icons.refresh),
                    label: const Text('再試行'),
                  ),
                ],
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
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
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
              _resultQuery == null
                  ? (_isLoading ? '最初の検索結果を待っています' : '検索語を入力して検索してください')
                  : '「$_resultQuery」に該当するノートはありません',
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
          ],
        ),
      ),
    );
  }
}
