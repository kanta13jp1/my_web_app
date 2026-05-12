import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 行動・発言の振り返りログ
/// すべての行動と発言を記録し、AIが考察を提供する。
class BehaviorLogPage extends StatefulWidget {
  const BehaviorLogPage({super.key});

  @override
  State<BehaviorLogPage> createState() => _BehaviorLogPageState();
}

class _BehaviorLogPageState extends State<BehaviorLogPage> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  List<Map<String, dynamic>> _logs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final data = await _supabase
          .from('behavior_log')
          .select()
          .eq('user_id', userId)
          .order('occurred_at', ascending: false)
          .limit(50);
      if (mounted) {
        setState(() {
          _logs = List<Map<String, dynamic>>.from(data as List);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('BehaviorLog load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addEntry() async {
    final contentCtrl = TextEditingController();
    final contextCtrl = TextEditingController();
    String kind = 'action';
    int regretLevel = 0;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('行動・発言を記録'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'action',
                      icon: Icon(Icons.directions_run),
                      label: Text('行動'),
                    ),
                    ButtonSegment(
                      value: 'utterance',
                      icon: Icon(Icons.chat_bubble_outline),
                      label: Text('発言'),
                    ),
                  ],
                  selected: {kind},
                  onSelectionChanged: (v) => setD(() => kind = v.first),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contentCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: kind == 'action' ? '何をした？' : '何を言った？',
                    hintText: kind == 'action'
                        ? '例: 会議中にスマホをいじった'
                        : '例: つい嫌味を言ってしまった',
                    prefixIcon: const Icon(Icons.edit),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: contextCtrl,
                  decoration: const InputDecoration(
                    labelText: '状況・相手 (任意)',
                    hintText: '例: チームミーティング中、上司に対して',
                    prefixIcon: Icon(Icons.people),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '後悔レベル',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    6,
                    (i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: ChoiceChip(
                        label: Text(
                          i == 0
                              ? '😌'
                              : i <= 2
                                  ? '😐'
                                  : i <= 4
                                      ? '😟'
                                      : '😰',
                        ),
                        selected: regretLevel == i,
                        onSelected: (_) => setD(() => regretLevel = i),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    regretLevel == 0
                        ? '問題なし'
                        : regretLevel <= 2
                            ? '少し気になる'
                            : regretLevel <= 4
                                ? '後悔している'
                                : '深く反省',
                    style: TextStyle(
                      fontSize: 12,
                      color: _regretColor(regretLevel),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('記録'),
            ),
          ],
        ),
      ),
    );
    if (result != true) return;
    final content = contentCtrl.text.trim();
    if (content.isEmpty) return;
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _supabase.from('behavior_log').insert({
        'user_id': userId,
        'kind': kind,
        'content': content,
        'context':
            contextCtrl.text.trim().isEmpty ? null : contextCtrl.text.trim(),
        'regret_level': regretLevel,
      });
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラー: $e'),
            backgroundColor: const Color(0xFFE53935),
          ),
        );
      }
    }
  }

  Future<void> _analyzeEntry(Map<String, dynamic> entry) async {
    if (_supabase.auth.currentUser == null) {
      setState(() => _loading = false);
      return;
    }
    if (entry['ai_analysis'] != null) return;
    final entryId = entry['id']?.toString();
    if (entryId == null) return;

    try {
      final response = await _supabase.functions.invoke(
        'ai-assistant',
        body: {
          'action': 'behavior_analysis',
          'content': jsonEncode({
            'kind': entry['kind'],
            'content': entry['content'],
            'context': entry['context'],
            'regret_level': entry['regret_level'],
          }),
        },
      );
      final data = response.data as Map<String, dynamic>?;
      final resultMap = data?['result'] as Map<String, dynamic>?;
      final analysis = resultMap?['analysis']?.toString() ?? 'AI分析を取得できませんでした';

      await _supabase.from('behavior_log').update({
        'ai_analysis': analysis,
      }).eq('id', entryId);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AI分析エラー: $e'),
            backgroundColor: const Color(0xFFE53935),
          ),
        );
      }
    }
  }

  Color _regretColor(int level) {
    if (level == 0) return const Color(0xFF4CAF50);
    if (level <= 2) return const Color(0xFFFF6B35);
    if (level <= 4) return const Color(0xFFC62828);
    return const Color(0xFFB71C1C);
  }

  @override
  Widget build(BuildContext context) {
    final todayLogs = _logs.where((l) {
      final dt = DateTime.tryParse(l['occurred_at']?.toString() ?? '');
      if (dt == null) return false;
      final now = DateTime.now();
      return dt.year == now.year && dt.month == now.month && dt.day == now.day;
    }).toList();
    final highRegret =
        _logs.where((l) => (l['regret_level'] as int? ?? 0) >= 3).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('行動・発言の振り返り'),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addEntry,
        icon: const Icon(Icons.add),
        label: const Text('記録する'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // サマリーカード
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF283593),
                        Color(0xFF3949AB),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        '🪞 自分を映す鏡',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'すべての行動と発言は、深く考えた結果であるべきだ',
                        style: TextStyle(
                          color: Color(0xFF9FA8DA),
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStat('今日', '${todayLogs.length}件'),
                          _buildStat('総記録', '${_logs.length}件'),
                          _buildStat(
                            '要反省',
                            '$highRegret件',
                            color: highRegret > 0
                                ? const Color(0xFFE57373)
                                : const Color(0xFF81C784),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (_logs.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(
                            Icons.psychology,
                            size: 48,
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '行動や発言を記録して\n振り返りを始めましょう',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ..._logs.map(_buildLogCard),
              ],
            ),
    );
  }

  Widget _buildStat(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color ?? Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            height: 1.5,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF9FA8DA),
            fontSize: 11,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildLogCard(Map<String, dynamic> entry) {
    final kind = entry['kind']?.toString() ?? 'action';
    final content = entry['content']?.toString() ?? '';
    final ctx = entry['context']?.toString();
    final regret = entry['regret_level'] as int? ?? 0;
    final analysis = entry['ai_analysis']?.toString();
    final dt = DateTime.tryParse(entry['occurred_at']?.toString() ?? '');
    final dateStr =
        dt != null ? DateFormat('MM/dd HH:mm').format(dt.toLocal()) : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: regret >= 3
              ? const Color(0xFFEF9A9A)
              : Theme.of(context).colorScheme.surfaceContainerHigh,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  kind == 'action'
                      ? Icons.directions_run
                      : Icons.chat_bubble_outline,
                  size: 18,
                  color: kind == 'action'
                      ? const Color(0xFF3D5AFE)
                      : const Color(0xFF3D5AFE),
                ),
                const SizedBox(width: 6),
                Text(
                  kind == 'action' ? '行動' : '発言',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: kind == 'action'
                        ? const Color(0xFF3D5AFE)
                        : const Color(0xFF3D5AFE),
                    height: 1.5,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _regretColor(regret).withAlpha(20),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    regret == 0
                        ? '😌 OK'
                        : regret <= 2
                            ? '😐 微妙'
                            : '😟 後悔$regret',
                    style: TextStyle(
                      fontSize: 10,
                      color: _regretColor(regret),
                      fontWeight: FontWeight.w700,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.outlineVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              content,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
              ),
            ),
            if (ctx != null && ctx.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '📍 $ctx',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
            if (analysis != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF1A1A2E)
                      : const Color(0xFFE8EAF6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🤖 AI考察',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      analysis,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: () => _analyzeEntry(entry),
                icon: const Icon(Icons.psychology, size: 16),
                label: const Text('AIに考察してもらう'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF3D5AFE),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
