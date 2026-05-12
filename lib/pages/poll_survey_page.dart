import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// アンケート・投票ページ
/// poll-survey Edge Function と連携してアンケートを作成・回答
class PollSurveyPage extends StatefulWidget {
  const PollSurveyPage({super.key});

  @override
  State<PollSurveyPage> createState() => _PollSurveyPageState();
}

class _PollSurveyPageState extends State<PollSurveyPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _polls = [];

  final _questionController = TextEditingController();
  final _optionsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchPolls();
  }

  @override
  void dispose() {
    _questionController.dispose();
    _optionsController.dispose();
    super.dispose();
  }

  Future<void> _fetchPolls() async {
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
        'tools-hub',
        body: {'action': 'poll.list'},
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final items = data['polls'];
        setState(() {
          _polls = items is List
              ? items.map<Map<String, dynamic>>((dynamic p) {
                  final row = p as Map<String, dynamic>;
                  final meta = (row['metadata'] as Map<String, dynamic>?) ?? {};
                  return {
                    'id': row['id'],
                    'question': meta['question'] ?? row['question'] ?? '',
                    'options': meta['options'] ?? row['options'] ?? <dynamic>[],
                    'votes': meta['votes'] ?? row['votes'] ?? <String, int>{},
                  };
                }).toList()
              : [];
        });
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'アンケートの取得に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createPoll() async {
    final question = _questionController.text.trim();
    final optionsText = _optionsController.text.trim();
    if (question.isEmpty || optionsText.isEmpty) return;

    final options = optionsText
        .split(',')
        .map((o) => o.trim())
        .where((o) => o.isNotEmpty)
        .toList();
    if (options.length < 2) {
      setState(() => _errorMessage = '選択肢をカンマ区切りで2つ以上入力してください');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _supabase.functions.invoke(
        'tools-hub',
        body: {
          'action': 'poll.create',
          'question': question,
          'options': options,
        },
      );
      _questionController.clear();
      _optionsController.clear();
      await _fetchPolls();
    } catch (e) {
      if (!mounted) return;
      if (mounted) setState(() => _errorMessage = 'アンケートの作成に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _vote(String pollId, String option) async {
    try {
      await _supabase.functions.invoke(
        'tools-hub',
        body: {'action': 'poll.vote', 'poll_id': pollId, 'option': option},
      );
      await _fetchPolls();
    } catch (e) {
      if (!mounted) return;
      if (mounted) setState(() => _errorMessage = '投票に失敗しました: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('アンケート・投票'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetchPolls,
          ),
        ],
      ),
      body: Column(
        children: [
          // 作成フォーム
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF303030) : const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    isDark ? const Color(0xFF616161) : const Color(0xFFEEEEEE),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '新規アンケート作成',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _questionController,
                  decoration: const InputDecoration(
                    labelText: '質問文',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _optionsController,
                  decoration: const InputDecoration(
                    labelText: '選択肢 (カンマ区切り: 賛成,反対,中立)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.poll, size: 18),
                    label: const Text('アンケートを作成'),
                    onPressed: _isLoading ? null : _createPoll,
                  ),
                ),
              ],
            ),
          ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _errorMessage!,
                style: const TextStyle(
                  color: Color(0xFFE53935),
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),
          // リスト
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _polls.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.poll_outlined,
                              size: 48,
                              color: isDark
                                  ? const Color(0xFF757575)
                                  : const Color(0xFFBDBDBD),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'アンケートがありません',
                              style: TextStyle(
                                color: isDark
                                    ? const Color(0xFF9E9E9E)
                                    : const Color(0xFF757575),
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _polls.length,
                        itemBuilder: (context, i) {
                          final poll = _polls[i];
                          final options = poll['options'];
                          final optionList = options is List
                              ? options.cast<String>()
                              : <String>[];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    poll['question']?.toString() ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: optionList
                                        .map(
                                          (opt) => OutlinedButton(
                                            onPressed: () => _vote(
                                              poll['id']?.toString() ?? '',
                                              opt,
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor:
                                                  const Color(0xFF6366F1),
                                              side: const BorderSide(
                                                color: Color(0xFF6366F1),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 6,
                                              ),
                                            ),
                                            child: Text(opt),
                                          ),
                                        )
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
    );
  }
}
