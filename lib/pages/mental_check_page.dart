import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class MentalCheckPage extends StatefulWidget {
  const MentalCheckPage({super.key});

  @override
  State<MentalCheckPage> createState() => _MentalCheckPageState();
}

class _MentalCheckPageState extends State<MentalCheckPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _logs = [];

  int _stressLevel = 3;
  int _moodLevel = 3;
  int _focusLevel = 3;
  final _noteController = TextEditingController();
  bool _saving = false;

  static const _levelLabels = ['とても低い', '低い', '普通', '高い', 'とても高い'];

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _fetchLogs() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final data = await _supabase
          .from('notes')
          .select()
          .eq('user_id', userId)
          .ilike('title', '[MentalCheck]%')
          .order('created_at', ascending: false)
          .limit(30);

      if (mounted) {
        setState(() {
          _logs = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveCheck() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _saving = true);
    try {
      final note = _noteController.text.trim();
      final content = '【ストレス】${_levelLabels[_stressLevel - 1]}'
          '\n【気分】${_levelLabels[_moodLevel - 1]}'
          '\n【集中力】${_levelLabels[_focusLevel - 1]}'
          '${note.isNotEmpty ? '\n\n$note' : ''}';

      await _supabase.from('notes').insert({
        'user_id': userId,
        'title':
            '[MentalCheck] ${DateFormat('MM/dd HH:mm').format(DateTime.now())}',
        'content': content,
        'is_archived': false,
        'is_pinned': false,
      });

      _noteController.clear();
      if (mounted) {
        setState(() {
          _stressLevel = 3;
          _moodLevel = 3;
          _focusLevel = 3;
          _saving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('メンタルチェックを記録しました')),
        );
        _fetchLogs();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('保存エラー: $e')));
      }
    }
  }

  Color _stressColor(int level) {
    if (level <= 2) return Colors.green;
    if (level == 3) return Colors.orange;
    return Colors.red;
  }

  Color _moodColor(int level) {
    if (level >= 4) return Colors.green;
    if (level == 3) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('メンタルチェック'),
        backgroundColor: Color(0xFF00796B),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '今の状態をチェックイン',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSlider(
                      label: 'ストレスレベル',
                      value: _stressLevel,
                      color: _stressColor(_stressLevel),
                      onChanged: (v) => setState(() => _stressLevel = v),
                    ),
                    const SizedBox(height: 12),
                    _buildSlider(
                      label: '気分',
                      value: _moodLevel,
                      color: _moodColor(_moodLevel),
                      onChanged: (v) => setState(() => _moodLevel = v),
                    ),
                    const SizedBox(height: 12),
                    _buildSlider(
                      label: '集中力',
                      value: _focusLevel,
                      color: Colors.blue,
                      onChanged: (v) => setState(() => _focusLevel = v),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _noteController,
                      decoration: InputDecoration(
                        hintText: 'メモ（任意）: 今気になっていること、体の調子など',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Color(0xFF6B7280)
                              : Color(0xFF9CA3AF),
                        ),
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      maxLines: 2,
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _saving ? null : _saveCheck,
                        style: FilledButton.styleFrom(
                          backgroundColor: Color(0xFF009688),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('記録する'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '記録履歴',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_logs.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'まだ記録がありません',
                    style: TextStyle(color: Color(0xFF9CA3AF)),
                  ),
                ),
              )
            else
              ...(_logs.map((log) {
                final created = DateTime.tryParse(
                  log['created_at']?.toString() ?? '',
                );
                final dateStr = created != null
                    ? DateFormat('MM/dd HH:mm').format(created)
                    : '';
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading:
                        const Icon(Icons.psychology, color: Color(0xFF009688)),
                    title: Text(
                      log['content']?.toString().split('\n').first ?? '',
                      style: const TextStyle(fontSize: 13),
                    ),
                    subtitle: Text(
                      log['content']?.toString() ?? '',
                      style: const TextStyle(fontSize: 11),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(
                      dateStr,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF9CA3AF)),
                    ),
                  ),
                );
              })),
          ],
        ),
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required int value,
    required Color color,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _levelLabels[value - 1],
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        Slider(
          value: value.toDouble(),
          min: 1,
          max: 5,
          divisions: 4,
          activeColor: color,
          label: _levelLabels[value - 1],
          onChanged: (v) => onChanged(v.round()),
        ),
      ],
    );
  }
}
