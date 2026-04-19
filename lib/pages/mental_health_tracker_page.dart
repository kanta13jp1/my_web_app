import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// AIメンタルヘルスケアページ
/// 気分・ストレス・睡眠・感情を記録しAIが統合分析。
/// Calm / Headspace / Woebot 対抗。
class MentalHealthTrackerPage extends StatefulWidget {
  const MentalHealthTrackerPage({super.key});

  @override
  State<MentalHealthTrackerPage> createState() =>
      _MentalHealthTrackerPageState();
}

class _MentalHealthTrackerPageState extends State<MentalHealthTrackerPage> {
  final _supabase = Supabase.instance.client;

  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _records = [];

  int _moodScore = 3;
  int _stressScore = 3;
  int _sleepHours = 7;
  final _noteCtrl = TextEditingController();
  bool _saving = false;

  static const _moodLabels = ['最悪', '悪い', '普通', '良い', '最高'];
  static const _moodIcons = ['😞', '😔', '😐', '🙂', '😄'];
  static const _stressLabels = ['なし', '少し', '普通', '多め', '限界'];

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
      if (userId == null) return;
      final data = await _supabase
          .from('mental_health_records')
          .select()
          .eq('user_id', userId)
          .order('recorded_at', ascending: false)
          .limit(30);
      setState(() => _records = (data as List).cast<Map<String, dynamic>>());
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    setState(() => _saving = true);
    try {
      await _supabase.from('mental_health_records').insert({
        'user_id': userId,
        'mood_score': _moodScore,
        'stress_score': _stressScore,
        'sleep_hours': _sleepHours,
        'note': _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        'recorded_at': DateTime.now().toIso8601String(),
      });
      _noteCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('記録を保存しました')),
        );
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失敗: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AIメンタルヘルスケア'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: '更新',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRecordCard(),
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
                Icon(Icons.favorite, color: Color(0xFFFF6B35)),
                SizedBox(width: 8),
                Text(
                  '今日の状態を記録',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    height: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '気分: ${_moodIcons[_moodScore - 1]} ${_moodLabels[_moodScore - 1]}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
            Slider(
              value: _moodScore.toDouble(),
              min: 1,
              max: 5,
              divisions: 4,
              onChanged: (v) => setState(() => _moodScore = v.round()),
            ),
            const SizedBox(height: 8),
            Text(
              'ストレス: ${_stressLabels[_stressScore - 1]}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
            Slider(
              value: _stressScore.toDouble(),
              min: 1,
              max: 5,
              divisions: 4,
              activeColor: const Color(0xFFFF6B35),
              onChanged: (v) => setState(() => _stressScore = v.round()),
            ),
            const SizedBox(height: 8),
            Text(
              '睡眠時間: $_sleepHours時間',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
            Slider(
              value: _sleepHours.toDouble(),
              min: 1,
              max: 12,
              divisions: 11,
              activeColor: const Color(0xFF3D5AFE),
              onChanged: (v) => setState(() => _sleepHours = v.round()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: 'メモ (任意)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.edit_note),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save),
                label: const Text('記録を保存'),
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
          child: Column(
            children: [
              const Icon(
                Icons.info_outline,
                color: Color(0xFF3D5AFE),
                size: 40,
              ),
              const SizedBox(height: 8),
              const Text('mental_health_records テーブルを作成すると履歴が表示されます'),
              const SizedBox(height: 4),
              Text(
                _error!,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFFB0B0B0),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (_records.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('記録がありません。今日の状態を記録してみましょう。')),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '過去の記録',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        ..._records.map(
          (r) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Text(
                _moodIcons[(r['mood_score'] as int? ?? 3) - 1],
                style: const TextStyle(
                  fontSize: 24,
                  height: 1.5,
                ),
              ),
              title: Text(
                '気分: ${_moodLabels[(r['mood_score'] as int? ?? 3) - 1]}  '
                'ストレス: ${_stressLabels[(r['stress_score'] as int? ?? 3) - 1]}',
              ),
              subtitle: Text(
                '睡眠: ${r['sleep_hours'] ?? '-'}時間'
                '${r['note'] != null ? '  ${r['note']}' : ''}',
              ),
              trailing: Text(
                (r['recorded_at'] as String? ?? '').substring(0, 10),
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFFB0B0B0),
                  height: 1.5,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
