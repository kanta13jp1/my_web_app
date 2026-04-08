import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// AIサマリーページ
/// ai-summarizer Edge Function と連携してコンテンツを要約
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
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions.invoke('ai-summarizer');
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
    setState(() {
      _isSummarizing = true;
      _summary = null;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions
          .invoke('ai-summarizer', body: {'text': text, 'action': 'summarize'});
      final data = response.data;
      if (data is Map<String, dynamic>) {
        setState(() => _summary = data['summary']?.toString() ?? '要約を生成できませんでした');
        await _fetchSummaries();
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = '要約に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isSummarizing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI サマリー'),
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
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _textCtrl,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: '要約したいテキストを入力...',
                border: OutlineInputBorder(),
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
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(_isSummarizing ? '要約中...' : 'AI要約する'),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
            if (_summary != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.indigo[900] : Colors.indigo[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? Colors.indigo[700]! : Colors.indigo[200]!,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '要約結果',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: Colors.indigo),
                    ),
                    const SizedBox(height: 4),
                    Text(_summary!),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text('要約履歴', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _summaries.isEmpty
                      ? const Center(child: Text('要約履歴がありません'))
                      : ListView.builder(
                          itemCount: _summaries.length,
                          itemBuilder: (context, index) {
                            final item = _summaries[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: const Icon(Icons.summarize),
                                title: Text(
                                  item['summary']?.toString() ?? '-',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  item['created_at']?.toString() ?? '',
                                  style: Theme.of(context).textTheme.bodySmall,
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
