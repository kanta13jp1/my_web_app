import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 音声メモ・文字起こしページ
/// voice-memo-transcriber Edge Function と連携して音声メモを管理
/// Google Keep・LINE・Discord競合
class VoiceMemoTranscriberPage extends StatefulWidget {
  const VoiceMemoTranscriberPage({super.key});

  @override
  State<VoiceMemoTranscriberPage> createState() =>
      _VoiceMemoTranscriberPageState();
}

class _VoiceMemoTranscriberPageState extends State<VoiceMemoTranscriberPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _memos = [];
  final _titleCtrl = TextEditingController();
  final _transcriptCtrl = TextEditingController();
  final _summaryCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _fetchMemos();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _transcriptCtrl.dispose();
    _summaryCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchMemos() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isSearching = false;
    });
    try {
      final response = await _supabase.functions
          .invoke('media-hub', body: {'action': 'transcribe.list'});
      final data = response.data;
      if (data is Map<String, dynamic> && data['memos'] is List) {
        setState(
          () => _memos = (data['memos'] as List).cast<Map<String, dynamic>>(),
        );
      } else {
        setState(() => _memos = []);
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = '音声メモの取得に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _searchMemos(String q) async {
    if (q.trim().isEmpty) {
      _fetchMemos();
      return;
    }
    setState(() {
      _isLoading = true;
      _isSearching = true;
    });
    try {
      final response = await _supabase.functions.invoke(
        'media-hub',
        body: {'action': 'transcribe.list'},
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['memos'] is List) {
        setState(
          () => _memos = (data['memos'] as List).cast<Map<String, dynamic>>(),
        );
      } else {
        setState(() => _memos = []);
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = '検索に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addMemo() async {
    _titleCtrl.clear();
    _transcriptCtrl.clear();
    _summaryCtrl.clear();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('音声メモを追加'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'タイトル'),
                autofocus: true,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _transcriptCtrl,
                decoration: const InputDecoration(
                  labelText: '文字起こし内容',
                  hintText: '音声の内容をここに入力...',
                ),
                maxLines: 6,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _summaryCtrl,
                decoration: const InputDecoration(labelText: 'AI要約 (任意)'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (confirmed != true || _titleCtrl.text.trim().isEmpty) return;
    try {
      await _supabase.functions.invoke(
        'media-hub',
        body: {
          'action': 'transcribe.create',
          'title': _titleCtrl.text.trim(),
          'transcript': _transcriptCtrl.text.trim(),
          'summary': _summaryCtrl.text.trim(),
          'duration_sec': 0,
          'source': 'manual',
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('音声メモを保存しました')),
        );
      }
      await _fetchMemos();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存に失敗しました: $e')),
        );
      }
    }
  }

  Future<void> _convertToNote(Map<String, dynamic> memo) async {
    final title = memo['title']?.toString() ?? '無題の音声メモ';
    final transcript = memo['transcript']?.toString() ?? '';
    final summary = memo['summary']?.toString() ?? '';
    final content = summary.isNotEmpty
        ? '## 要約\n$summary\n\n## 文字起こし\n$transcript'
        : transcript;
    try {
      await _supabase.functions.invoke(
        'tools-hub',
        body: {
          'action': 'note.add',
          'title': title,
          'content': content,
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ノートに変換しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('変換に失敗しました: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text('音声メモ・文字起こし'),
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '更新',
            onPressed: _fetchMemos,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'メモを追加',
            onPressed: _addMemo,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addMemo,
        backgroundColor: const Color(0xFFFF6B35),
        tooltip: '音声メモを追加',
        child: const Icon(Icons.mic, color: Colors.white),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: '音声メモを検索...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          _fetchMemos();
                        },
                      )
                    : null,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHigh,
              ),
              onSubmitted: _searchMemos,
              onChanged: (v) => setState(() {}),
            ),
          ),
          if (_isSearching)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    '「${_searchCtrl.text}」の検索結果: ${_memos.length}件',
                    style: const TextStyle(
                        color: const Color(0xFF9CA3AF), fontSize: 12),
                  ),
                  const Spacer(),
                  TextButton(onPressed: _fetchMemos, child: const Text('クリア')),
                ],
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.red),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: _fetchMemos,
                              child: const Text('再試行'),
                            ),
                          ],
                        ),
                      )
                    : _memos.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.mic_none,
                                  size: 64,
                                  color: const Color(0xFF9CA3AF),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  '音声メモがありません',
                                  style:
                                      TextStyle(color: const Color(0xFF9CA3AF)),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: _addMemo,
                                  icon: const Icon(Icons.add),
                                  label: const Text('最初のメモを追加'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF7C3AED),
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _fetchMemos,
                            child: ListView.builder(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              itemCount: _memos.length,
                              itemBuilder: (context, index) =>
                                  _buildMemoCard(_memos[index]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemoCard(Map<String, dynamic> memo) {
    final title = memo['title']?.toString() ?? '無題';
    final transcript = memo['transcript']?.toString() ?? '';
    final summary = memo['summary']?.toString() ?? '';
    final createdAt = memo['createdAt']?.toString() ?? '';
    final durationSec = (memo['duration_sec'] as num?)?.toInt() ?? 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: CircleAvatar(
            backgroundColor: const Color(0xFF7C3AED).withValues(alpha: 0.12),
            child: const Icon(Icons.mic, color: Color(0xFF7C3AED), size: 20),
          ),
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Row(
            children: [
              if (durationSec > 0) ...[
                const Icon(Icons.timer_outlined,
                    size: 12, color: const Color(0xFF9CA3AF)),
                const SizedBox(width: 2),
                Text(
                  '${durationSec ~/ 60}:${(durationSec % 60).toString().padLeft(2, '0')}',
                  style: const TextStyle(
                      fontSize: 12, color: const Color(0xFF9CA3AF)),
                ),
                const SizedBox(width: 8),
              ],
              if (createdAt.isNotEmpty)
                Text(
                  createdAt.length > 10
                      ? createdAt.substring(0, 10)
                      : createdAt,
                  style: const TextStyle(
                      fontSize: 12, color: const Color(0xFF9CA3AF)),
                ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (summary.isNotEmpty) ...[
                    const Text(
                      'AI要約',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child:
                          Text(summary, style: const TextStyle(fontSize: 13)),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (transcript.isNotEmpty) ...[
                    const Text(
                      '文字起こし',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color:
                            Theme.of(context).colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        transcript.length > 300
                            ? '${transcript.substring(0, 300)}...'
                            : transcript,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => _convertToNote(memo),
                        icon: const Icon(Icons.note_add_outlined, size: 16),
                        label: const Text('ノートに変換'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF7C3AED),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
