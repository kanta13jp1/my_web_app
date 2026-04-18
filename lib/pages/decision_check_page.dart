import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class DecisionCheckPage extends StatefulWidget {
  const DecisionCheckPage({super.key});

  @override
  State<DecisionCheckPage> createState() => _DecisionCheckPageState();
}

class _DecisionCheckPageState extends State<DecisionCheckPage> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  List<Map<String, dynamic>> _checks = [];

  static const Map<String, String> _verdictLabels = {
    'logical': '✅ 論理的',
    'needs_revision': '⚠️ 要修正',
    'illogical': '❌ 非論理的',
    'delusional': '🚨 妄想的',
  };

  static const Map<String, Color> _verdictColors = {
    'logical': Color(0xFF10B981),
    'needs_revision': Color(0xFFF59E0B),
    'illogical': Color(0xFFEF4444),
    'delusional': Color(0xFF7C3AED),
  };

  static const Map<String, String> _categoryLabels = {
    'habit': '🔄 習慣',
    'finance': '💰 お金',
    'relationship': '💞 人間関係',
    'career': '💼 キャリア',
    'health': '💪 健康',
    'purchase': '🛒 購入',
    'commitment': '🤝 コミット',
    'lifestyle': '🏠 ライフスタイル',
    'other': '📌 その他',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      final data = await _supabase
          .from('decision_checks')
          .select()
          .eq('user_id', userId)
          .neq('status', 'abandoned')
          .order('created_at', ascending: false)
          .limit(30);
      if (mounted) {
        setState(() {
          _checks = List<Map<String, dynamic>>.from(data as List);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showNewCheckDialog() async {
    final decisionCtrl = TextEditingController();
    final whatDiffCtrl = TextEditingController();
    final planCtrl = TextEditingController();
    final fallbackCtrl = TextEditingController();
    String category = 'habit';
    int pastAttempts = 0;
    bool hasPlan = false;
    bool hasFallback = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('意思決定チェック'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: decisionCtrl,
                    decoration: const InputDecoration(
                      labelText: '何を決めようとしていますか?',
                      hintText: '例: 明日から毎日30分運動する',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: const InputDecoration(
                      labelText: 'カテゴリ',
                      border: OutlineInputBorder(),
                    ),
                    items: _categoryLabels.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setS(() => category = v!),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '過去に同じ決意をした回数: $pastAttempts 回',
                    style: const TextStyle(fontSize: 13),
                  ),
                  Slider(
                    value: pastAttempts.toDouble(),
                    min: 0,
                    max: 20,
                    divisions: 20,
                    label: '$pastAttempts',
                    onChanged: (v) => setS(() => pastAttempts = v.toInt()),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: whatDiffCtrl,
                    decoration: const InputDecoration(
                      labelText: '今回、過去と何が違いますか? (任意)',
                      hintText: '例: 仕組みを変えた、環境が変わった',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Checkbox(
                        value: hasPlan,
                        onChanged: (v) => setS(() => hasPlan = v ?? false),
                      ),
                      const Text('具体的な実行計画がある'),
                    ],
                  ),
                  if (hasPlan)
                    TextField(
                      controller: planCtrl,
                      decoration: const InputDecoration(
                        labelText: '実行計画',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Checkbox(
                        value: hasFallback,
                        onChanged: (v) => setS(() => hasFallback = v ?? false),
                      ),
                      const Text('失敗時のフォールバックがある'),
                    ],
                  ),
                  if (hasFallback)
                    TextField(
                      controller: fallbackCtrl,
                      decoration: const InputDecoration(
                        labelText: 'フォールバック計画',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () async {
                final text = decisionCtrl.text.trim();
                if (text.isEmpty) return;
                final userId = _supabase.auth.currentUser?.id;
                if (userId == null) return;

                final verdict = _evaluateDecision(
                  pastAttempts: pastAttempts,
                  whatIsDifferent: whatDiffCtrl.text.trim(),
                  hasConcretePlan: hasPlan,
                  hasFallback: hasFallback,
                );

                await _supabase.from('decision_checks').insert({
                  'user_id': userId,
                  'decision_statement': text,
                  'category': category,
                  'past_attempts': pastAttempts,
                  'what_is_different': whatDiffCtrl.text.trim().isEmpty
                      ? null
                      : whatDiffCtrl.text.trim(),
                  'has_concrete_plan': hasPlan,
                  'execution_plan': planCtrl.text.trim().isEmpty
                      ? null
                      : planCtrl.text.trim(),
                  'has_fallback': hasFallback,
                  'fallback_plan': fallbackCtrl.text.trim().isEmpty
                      ? null
                      : fallbackCtrl.text.trim(),
                  'verdict': verdict,
                  'status': 'checked',
                });
                if (ctx.mounted) Navigator.pop(ctx);
                await _load();
              },
              child: const Text('チェックする'),
            ),
          ],
        ),
      ),
    );
  }

  String _evaluateDecision({
    required int pastAttempts,
    required String whatIsDifferent,
    required bool hasConcretePlan,
    required bool hasFallback,
  }) {
    int score = 0;
    if (pastAttempts == 0) score += 3;
    if (pastAttempts <= 2) score += 2;
    if (whatIsDifferent.isNotEmpty) score += 2;
    if (hasConcretePlan) score += 2;
    if (hasFallback) score += 1;

    if (score >= 7) return 'logical';
    if (score >= 4) return 'needs_revision';
    if (pastAttempts >= 10 && whatIsDifferent.isEmpty && !hasConcretePlan) {
      return 'delusional';
    }
    return 'illogical';
  }

  Future<void> _updateStatus(String id, String status) async {
    await _supabase
        .from('decision_checks')
        .update({'status': status}).eq('id', id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Color(0xFF0F172A) : Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('論理的意思決定ガード'),
        backgroundColor: isDark ? Color(0xFF1E293B) : Colors.white,
        foregroundColor: isDark ? Colors.white : Color(0xFF1E293B),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showNewCheckDialog,
        backgroundColor: Color(0xFF6366F1),
        label: const Text('決意をチェック', style: TextStyle(color: Colors.white)),
        icon: const Icon(Icons.psychology, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _checks.isEmpty
              ? _buildEmpty(isDark)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: _checks.length,
                  itemBuilder: (ctx, i) => _buildCheckCard(_checks[i], isDark),
                ),
    );
  }

  Widget _buildCheckCard(Map<String, dynamic> check, bool isDark) {
    final verdict = check['verdict'] as String?;
    final statement = check['decision_statement'] as String? ?? '';
    final category = check['category'] as String? ?? 'other';
    final pastAttempts = check['past_attempts'] as int? ?? 0;
    final hasPlan = check['has_concrete_plan'] as bool? ?? false;
    final hasFallback = check['has_fallback'] as bool? ?? false;
    final createdAt = check['created_at'] as String?;
    final cardColor = isDark ? Color(0xFF1E293B) : Colors.white;
    final verdictColor = verdict != null
        ? (_verdictColors[verdict] ?? Colors.grey)
        : Colors.grey;

    return Card(
      color: cardColor,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: verdictColor.withAlpha(60)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (verdict != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: verdictColor.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _verdictLabels[verdict] ?? verdict,
                      style: TextStyle(
                        fontSize: 12,
                        color: verdictColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(width: 6),
                Text(
                  _categoryLabels[category] ?? category,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  onSelected: (v) => _updateStatus(check['id'] as String, v),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'executing',
                      child: Text('実行中に変更'),
                    ),
                    const PopupMenuItem(
                      value: 'succeeded',
                      child: Text('成功に変更'),
                    ),
                    const PopupMenuItem(
                      value: 'failed',
                      child: Text('失敗に変更'),
                    ),
                    const PopupMenuItem(
                      value: 'abandoned',
                      child: Text('削除'),
                    ),
                  ],
                  child: Icon(
                    Icons.more_vert,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              statement,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _infoChip(
                  '過去の試行: $pastAttempts 回',
                  pastAttempts == 0
                      ? Colors.green
                      : pastAttempts < 5
                          ? Colors.orange
                          : Colors.red,
                ),
                const SizedBox(width: 6),
                _infoChip(
                  '計画: ${hasPlan ? "あり" : "なし"}',
                  hasPlan ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 6),
                _infoChip(
                  'フォールバック: ${hasFallback ? "あり" : "なし"}',
                  hasFallback ? Colors.green : Colors.orange,
                ),
              ],
            ),
            if (createdAt != null) ...[
              const SizedBox(height: 6),
              Text(
                DateFormat('yyyy/MM/dd').format(
                  DateTime.tryParse(createdAt)?.toLocal() ?? DateTime.now(),
                ),
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.psychology_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          const SizedBox(height: 16),
          Text(
            '論理的に決断しよう',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '衝動的な決意の前に\nまずチェックしてみましょう',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
