import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 「我が闘争」システム
/// 日々の暮らしの奮闘をAIがコラム形式で出力する。
/// ユーザーの習慣達成状況・タスク・禁欲ガード状況を元に、
/// その日の「闘い」を文学的に描写する。
class MyStrugglePage extends StatefulWidget {
  const MyStrugglePage({super.key});

  @override
  State<MyStrugglePage> createState() => _MyStrugglePageState();
}

class _MyStrugglePageState extends State<MyStrugglePage> {
  final _supabase = Supabase.instance.client;
  bool _loading = false;
  bool _loadingHistory = true;
  String? _column;
  String? _error;
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _loadingHistory = false);
      return;
    }
    try {
      final data = await _supabase
          .from('my_struggle_columns')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(30);
      if (mounted) {
        setState(() {
          _history = List<Map<String, dynamic>>.from(data as List);
          _loadingHistory = false;
        });
      }
    } catch (e) {
      debugPrint('MyStrugglePage history load error: $e');
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  Future<Map<String, dynamic>> _gatherContext() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return {};

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final results = await Future.wait([
      // 習慣
      _supabase
          .from('daily_habits')
          .select('title, streak, best_streak')
          .eq('user_id', userId)
          .eq('is_active', true),
      // 今日の習慣ログ
      _supabase
          .from('daily_habit_logs')
          .select('habit_id')
          .eq('user_id', userId)
          .eq('completed_date', today),
      // デイリータスク
      _supabase
          .from('daily_todos')
          .select('title, is_completed')
          .eq('user_id', userId)
          .eq('task_date', today),
    ]);

    final habits = List<Map<String, dynamic>>.from(results[0] as List);
    final habitLogs = List<Map<String, dynamic>>.from(results[1] as List);
    final todos = List<Map<String, dynamic>>.from(results[2] as List);

    return {
      'date': today,
      'habits_total': habits.length,
      'habits_completed_today': habitLogs.length,
      'habits': habits
          .map(
            (h) => '${h['title']} (streak: ${h['streak']}日)',
          )
          .toList(),
      'todos_total': todos.length,
      'todos_completed': todos.where((t) => t['is_completed'] == true).length,
      'todos': todos
          .map(
            (t) =>
                '${t['title']} (${t['is_completed'] == true ? "完了" : "未完了"})',
          )
          .toList(),
    };
  }

  Future<void> _generate() async {
    if (_supabase.auth.currentUser == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _column = null;
    });

    try {
      final context = await _gatherContext();
      final contextJson = const JsonEncoder.withIndent('  ').convert(context);

      final response = await _supabase.functions.invoke(
        'ai-assistant',
        body: {
          'action': 'my_struggle_column',
          'content': contextJson,
        },
      );

      if (response.status != 200) {
        throw Exception('API error: ${response.status}');
      }

      final data = response.data as Map<String, dynamic>?;
      if (data == null || data['success'] != true) {
        throw Exception(data?['error']?.toString() ?? 'Unknown error');
      }

      final result = data['result'] as Map<String, dynamic>? ?? {};
      final column = result['column']?.toString() ?? '';
      final title = result['title']?.toString() ?? '我が闘争';

      // 保存
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null && column.isNotEmpty) {
        await _supabase.from('my_struggle_columns').insert({
          'user_id': userId,
          'title': title,
          'column_text': column,
          'context_data': context,
        });
      }

      if (mounted) {
        setState(() {
          _column = '# $title\n\n$column';
          _loading = false;
        });
        await _loadHistory();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我が闘争'),
        elevation: 0,
        actions: [
          if (_column != null)
            IconButton(
              icon: const Icon(Icons.copy),
              tooltip: 'コピー',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _column ?? ''));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('コピーしました')),
                );
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ヘッダー
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.onSurface,
                  Theme.of(context).colorScheme.onSurfaceVariant,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Text(
                  '📜',
                  style: TextStyle(
                    fontSize: 40,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '我が闘争',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '日々の暮らしの中にある、静かな闘いの記録',
                  style: TextStyle(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _generate,
                    icon: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.auto_fix_high),
                    label: Text(_loading ? '執筆中...' : '今日の闘争を記す'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFF8F00),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // エラー表示
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF3A1010)
                    : const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF5A2020)
                      : const Color(0xFFEF9A9A),
                ),
              ),
              child: Text(
                _error!,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFFC62828),
                  height: 1.5,
                ),
              ),
            ),

          // 今日のコラム
          if (_column != null) ...[
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0xFFFFE082)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SelectableText(
                  _column!,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.8,
                    fontFamily: 'serif',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // 履歴
          if (!_loadingHistory && _history.isNotEmpty) ...[
            Text(
              '過去の闘争記録',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            ..._history.map(_buildHistoryCard),
          ],
          if (_loadingHistory)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            ),
          if (!_loadingHistory && _history.isEmpty && _column == null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.history_edu,
                      size: 48,
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'まだ闘争の記録がありません。\n「今日の闘争を記す」で最初の一篇を。',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> entry) {
    final title = entry['title']?.toString() ?? '我が闘争';
    final text = entry['column_text']?.toString() ?? '';
    final createdAt = DateTime.tryParse(
      entry['created_at']?.toString() ?? '',
    );
    final dateStr = createdAt != null
        ? DateFormat('yyyy/MM/dd HH:mm').format(createdAt.toLocal())
        : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
        ),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            height: 1.5,
          ),
        ),
        subtitle: Text(
          dateStr,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.outlineVariant,
            height: 1.5,
          ),
        ),
        leading: const Text(
          '📜',
          style: TextStyle(
            fontSize: 20,
            height: 1.5,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SelectableText(
              text,
              style: const TextStyle(
                fontSize: 13,
                height: 1.7,
                fontFamily: 'serif',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
