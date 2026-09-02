import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 文章・要約アシスタント内の、履歴付きAI要約ページ。
/// `ai-hub` の summarize.text / secretary.history と連携する。
class AiSummarizerPage extends StatefulWidget {
  const AiSummarizerPage({super.key});

  @override
  State<AiSummarizerPage> createState() => _AiSummarizerPageState();
}

class _AiSummarizerPageState extends State<AiSummarizerPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _summaries = [];
  final _textCtrl = TextEditingController();
  String? _summary;
  bool _isSummarizing = false;

  @override
  void initState() {
    super.initState();
    _fetchSummaries();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchSummaries() async {
    if (_supabase.auth.currentUser == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions
          .invoke('ai-hub', body: {'action': 'secretary.history'});
      final data = response.data;
      if (data is Map<String, dynamic> && data['summaries'] is List) {
        setState(
          () => _summaries =
              (data['summaries'] as List).cast<Map<String, dynamic>>(),
        );
      } else {
        setState(() => _summaries = []);
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = '要約履歴の取得に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _summarize() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    if (_supabase.auth.currentUser == null) {
      if (mounted) setState(() => _errorMessage = 'この機能はログインが必要です');
      return;
    }
    setState(() {
      _isSummarizing = true;
      _summary = null;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions
          .invoke('ai-hub', body: {'action': 'summarize.text', 'text': text});
      final data = response.data;
      if (data is Map<String, dynamic>) {
        setState(
          () => _summary = data['summary']?.toString() ?? '要約を生成できませんでした',
        );
        await _fetchSummaries();
      }
    } catch (e) {
      if (!mounted) return;
      if (mounted) setState(() => _errorMessage = '要約に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isSummarizing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text('AI サマリー'),
        backgroundColor: const Color(0xFF1A1A1A),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetchSummaries,
            tooltip: '更新',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'テキストを入力してAIが自動要約します',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFB0B0B0),
                  ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _textCtrl,
              maxLines: 5,
              style: const TextStyle(
                color: Colors.white,
                height: 1.5,
              ),
              decoration: InputDecoration(
                hintText: '要約したいテキストを入力...',
                hintStyle: const TextStyle(
                  color: Color(0xFF707070),
                  height: 1.5,
                ),
                filled: true,
                fillColor: const Color(0xFF2A2A2A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF3D5AFE)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSummarizing ? null : _summarize,
                icon: _isSummarizing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(_isSummarizing ? '要約中...' : 'AI要約する'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B35),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: const TextStyle(
                  color: Color(0xFFE53935),
                  height: 1.5,
                ),
              ),
            ],
            if (_summary != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF3D5AFE).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF3D5AFE).withValues(alpha: 0.4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3D5AFE).withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '要約結果',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: const Color(0xFF7986CB)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _summary!,
                      style: const TextStyle(
                        color: Colors.white,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              '要約履歴',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _summaries.isEmpty
                      ? const Center(
                          child: Text(
                            '要約履歴がありません',
                            style: TextStyle(
                              color: Color(0xFF707070),
                              height: 1.5,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _summaries.length,
                          itemBuilder: (context, index) {
                            final item = _summaries[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E1E1E),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ListTile(
                                leading: const Icon(
                                  Icons.summarize,
                                  color: Color(0xFF3D5AFE),
                                ),
                                title: Text(
                                  item['summary']?.toString() ?? '-',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    height: 1.5,
                                  ),
                                ),
                                subtitle: Text(
                                  item['created_at']?.toString() ?? '',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: const Color(0xFF707070),
                                      ),
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
