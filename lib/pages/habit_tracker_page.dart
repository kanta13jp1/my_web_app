import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HabitTrackerPage extends StatefulWidget {
  const HabitTrackerPage({super.key});

  @override
  State<HabitTrackerPage> createState() => _HabitTrackerPageState();
}

class _HabitTrackerPageState extends State<HabitTrackerPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _habits = [];

  final _habitController = TextEditingController();
  String _selectedFrequency = 'daily';

  @override
  void initState() {
    super.initState();
    _fetchHabits();
  }

  @override
  void dispose() {
    _habitController.dispose();
    super.dispose();
  }

  Future<void> _fetchHabits() async {
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
        body: {'action': 'habit.list'},
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final items = data['habits'];
        setState(() {
          _habits = items is List ? items.cast<Map<String, dynamic>>() : [];
        });
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = '習慣の取得に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createHabit() async {
    final name = _habitController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await _supabase.functions.invoke(
        'tools-hub',
        body: {
          'action': 'habit.create',
          'name': name,
          'frequency': _selectedFrequency,
        },
      );
      _habitController.clear();
      await _fetchHabits();
    } catch (e) {
      if (!mounted) return;
      if (mounted) setState(() => _errorMessage = '習慣の作成に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkIn(String habitId) async {
    try {
      await _supabase.functions.invoke(
        'tools-hub',
        body: {'action': 'habit.checkin', 'habit_id': habitId},
      );
      await _fetchHabits();
    } catch (e) {
      if (!mounted) return;
      if (mounted) setState(() => _errorMessage = 'チェックインに失敗しました: $e');
    }
  }

  Color _streakColor(int streak) {
    if (streak >= 30) return Colors.orange;
    if (streak >= 7) return Colors.green;
    return Colors.blue;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('習慣トラッカー'),
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
      ),
      body: _isLoading && _habits.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_errorMessage != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Colors.red,
                          height: 1.5,
                        ),
                      ),
                    ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '新規習慣を追加',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _habitController,
                            decoration: const InputDecoration(
                              labelText: '習慣名 (例: 毎朝ランニング)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedFrequency,
                            decoration: const InputDecoration(
                              labelText: '頻度',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'daily',
                                child: Text('毎日'),
                              ),
                              DropdownMenuItem(
                                value: 'weekly',
                                child: Text('毎週'),
                              ),
                              DropdownMenuItem(
                                value: 'weekdays',
                                child: Text('平日のみ'),
                              ),
                            ],
                            onChanged: (v) => setState(
                              () => _selectedFrequency = v ?? 'daily',
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _createHabit,
                              icon: const Icon(Icons.add),
                              label: const Text('追加'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6366F1),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '習慣リスト',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_habits.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          '習慣がまだありません。\n最初の習慣を追加しましょう！',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey,
                            height: 1.5,
                          ),
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _habits.length,
                      itemBuilder: (context, index) {
                        final habit = _habits[index];
                        final meta = habit['metadata'] is Map
                            ? habit['metadata'] as Map
                            : const {};
                        final streak = (habit['streak'] as num?)?.toInt() ?? 0;
                        final doneToday = habit['done_today'] as bool? ?? false;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  _streakColor(streak).withAlpha(30),
                              child: Icon(
                                Icons.local_fire_department,
                                color: _streakColor(streak),
                                size: 20,
                              ),
                            ),
                            title: Text(meta['name']?.toString() ?? ''),
                            subtitle: Text('ストリーク: $streak 日'),
                            trailing: IconButton(
                              icon: Icon(
                                doneToday
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                color: doneToday ? Colors.green : Colors.grey,
                              ),
                              onPressed: doneToday
                                  ? null
                                  : () => _checkIn(
                                        habit['id']?.toString() ?? '',
                                      ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }
}
