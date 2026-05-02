import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MentalHealthTrackerPage extends StatefulWidget {
  const MentalHealthTrackerPage({super.key});

  @override
  State<MentalHealthTrackerPage> createState() =>
      _MentalHealthTrackerPageState();
}

class _MentalHealthTrackerPageState extends State<MentalHealthTrackerPage> {
  final _supabase = Supabase.instance.client;
  final _noteCtrl = TextEditingController();

  bool _loading = false;
  bool _saving = false;
  String? _error;
  String? _latestSummary;
  int _createdTaskCount = 0;
  List<Map<String, dynamic>> _records = [];

  int _moodScore = 3;
  int _stressScore = 3;
  int _sleepHours = 7;

  static const _moodLabels = ['最悪', '悪い', '普通', '良い', '最高'];
  static const _stressLabels = ['なし', '少し', '普通', '多い', '限界'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        setState(() => _records = []);
        return;
      }
      final data = await _supabase
          .from('mental_health_records')
          .select()
          .eq('user_id', userId)
          .order('recorded_at', ascending: false)
          .limit(30);
      setState(() {
        _records = (data as List)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveAndAnalyze() async {
    if (_noteCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('日記メモを入力してください')),
      );
      return;
    }
    setState(() {
      _saving = true;
      _latestSummary = null;
      _createdTaskCount = 0;
    });
    try {
      final response = await _supabase.functions.invoke(
        'lifestyle-hub',
        body: {
          'action': 'journal.analyze',
          'note': _noteCtrl.text.trim(),
          'mood_score': _moodScore,
          'stress_score': _stressScore,
          'sleep_hours': _sleepHours,
          'create_tomorrow_tasks': true,
        },
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'AI分析に失敗しました');
      }
      final insight = Map<String, dynamic>.from(data['insight'] as Map);
      final createdTasks = (data['created_tasks'] as List?) ?? const [];
      _noteCtrl.clear();
      if (!mounted) return;
      setState(() {
        _latestSummary = insight['summary'] as String?;
        _createdTaskCount = createdTasks.length;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('AI分析を保存し、翌日のTODOを${createdTasks.length}件作成しました'),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存に失敗しました: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<String> _stringList(Object? value) {
    if (value is List) {
      return value.map((item) => item.toString()).where((item) {
        return item.trim().isNotEmpty;
      }).toList();
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI日記フィードバック'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: '更新',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildRecordCard(),
            if (_latestSummary != null) ...[
              const SizedBox(height: 12),
              _buildLatestResult(),
            ],
            const SizedBox(height: 20),
            _buildHistorySection(),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.psychology_alt, color: Color(0xFFFF6B35)),
                SizedBox(width: 8),
                Text(
                  '今日の思考と行動を記録',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '日記を保存するとAIが感情・支出・健康・仕事のトリガーを分析し、明日のTODOへ小さな行動を追加します。',
            ),
            const SizedBox(height: 16),
            _buildSlider(
              label: '気分',
              value: _moodScore,
              labels: _moodLabels,
              activeColor: const Color(0xFF3D5AFE),
              onChanged: (value) => setState(() => _moodScore = value),
            ),
            _buildSlider(
              label: 'ストレス',
              value: _stressScore,
              labels: _stressLabels,
              activeColor: const Color(0xFFFF6B35),
              onChanged: (value) => setState(() => _stressScore = value),
            ),
            Text(
              '睡眠: $_sleepHours時間',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Slider(
              value: _sleepHours.toDouble(),
              min: 1,
              max: 12,
              divisions: 11,
              onChanged: (value) => setState(() => _sleepHours = value.round()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: '日記メモ',
                hintText: '今日起きたこと、感情が動いた瞬間、支出や健康の気づきなど',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.edit_note),
              ),
              maxLines: 5,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _saveAndAnalyze,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: const Text('AI分析して保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required int value,
    required List<String> labels,
    required Color activeColor,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ${labels[value - 1]}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        Slider(
          value: value.toDouble(),
          min: 1,
          max: 5,
          divisions: 4,
          activeColor: activeColor,
          onChanged: (next) => onChanged(next.round()),
        ),
      ],
    );
  }

  Widget _buildLatestResult() {
    return Card(
      color: const Color(0xFFEFF6FF),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF0F766E)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AI分析が完了しました',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(_latestSummary!),
                  const SizedBox(height: 6),
                  Text('翌日のTODOに$_createdTaskCount件追加しました'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySection() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('履歴を取得できませんでした: $_error'),
        ),
      );
    }
    if (_records.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('まだ記録がありません。今日の状態を保存してみましょう。')),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '過去のAI日記分析',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ..._records.map(_buildRecordTile),
      ],
    );
  }

  Widget _buildRecordTile(Map<String, dynamic> record) {
    final tags = [
      ..._stringList(record['emotion_tags']),
      ..._stringList(record['trigger_tags']),
    ];
    final actions = _stringList(record['next_actions']);
    final date = (record['recorded_at'] as String? ?? '').take(10);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    date.isEmpty ? '記録日未設定' : date,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Chip(
                  label: Text('リスク ${record['risk_level'] ?? 'low'}'),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              record['ai_summary'] as String? ??
                  record['note'] as String? ??
                  '分析待ちの記録です',
            ),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: tags.map((tag) => Chip(label: Text(tag))).toList(),
              ),
            ],
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                '明日の提案',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              ...actions.map(
                (action) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('・'),
                      Expanded(child: Text(action)),
                    ],
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

extension on String {
  String take(int length) {
    if (length <= 0) return '';
    return this.length <= length ? this : substring(0, length);
  }
}
