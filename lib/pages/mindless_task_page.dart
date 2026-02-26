import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class MindlessTaskPage extends StatefulWidget {
  final SupabaseClient? supabaseClient;

  const MindlessTaskPage({super.key, this.supabaseClient});

  @override
  State<MindlessTaskPage> createState() => _MindlessTaskPageState();
}

class _MindlessTaskPageState extends State<MindlessTaskPage> {
  SupabaseClient get _supabase =>
      widget.supabaseClient ?? Supabase.instance.client;
  DateTime _selectedDate = DateTime.now();

  // データ構造: { 6: [Task1, Task2], 7: [Task3] } のように時間ごとのリスト
  Map<int, List<Map<String, dynamic>>> _tasksByHour = {};
  bool _isLoading = true;
  Timer? _timeboxTimer;
  bool _isTimeboxRunning = false;
  int _selectedMinutes = 50;
  Duration _timeboxTotal = Duration.zero;
  Duration _timeboxRemaining = Duration.zero;
  String _timeboxMode = '動く';
  String _timeboxGoal = '';
  int _completedTimeboxCount = 0;

  static const List<int> _timeboxPresets = [15, 30, 50, 90];

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  @override
  void dispose() {
    _timeboxTimer?.cancel();
    super.dispose();
  }

  // 日付が変わったら再ロード
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _isLoading = true;
      });
      _loadTasks();
    }
  }

  Future<void> _loadTasks() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

      final data = await _supabase
          .from('mindless_tasks')
          .select()
          .eq('user_id', userId)
          .eq('task_date', dateStr)
          .order('id', ascending: true);

      final Map<int, List<Map<String, dynamic>>> newTasksByHour = {};
      for (var item in data) {
        final hour = item['hour_slot'] as int;
        if (!newTasksByHour.containsKey(hour)) {
          newTasksByHour[hour] = [];
        }
        newTasksByHour[hour]!.add(item);
      }

      if (mounted) {
        setState(() {
          _tasksByHour = newTasksByHour;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatRemaining(Duration duration) {
    final mm = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  double _timeboxProgress() {
    if (_timeboxTotal.inSeconds <= 0) return 0;
    final value =
        1 - (_timeboxRemaining.inSeconds / _timeboxTotal.inSeconds.toDouble());
    return value.clamp(0, 1);
  }

  Future<void> _startTimeboxFlow(String mode) async {
    final controller = TextEditingController();
    final goal = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$modeモードを開始'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'この時間でやることを1行で書く',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('開始'),
          ),
        ],
      ),
    );

    if (goal == null || goal.isEmpty) return;
    _startTimebox(mode: mode, goal: goal, minutes: _selectedMinutes);
  }

  void _startTimebox({
    required String mode,
    required String goal,
    required int minutes,
  }) {
    _timeboxTimer?.cancel();
    final total = Duration(minutes: minutes);
    setState(() {
      _isTimeboxRunning = true;
      _timeboxMode = mode;
      _timeboxGoal = goal;
      _timeboxTotal = total;
      _timeboxRemaining = total;
    });

    _timeboxTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_timeboxRemaining.inSeconds <= 1) {
        timer.cancel();
        setState(() {
          _isTimeboxRunning = false;
          _timeboxRemaining = Duration.zero;
          _completedTimeboxCount += 1;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '時間終了: $_timeboxMode「$_timeboxGoal」',
            ),
          ),
        );
        return;
      }
      setState(() {
        _timeboxRemaining = Duration(seconds: _timeboxRemaining.inSeconds - 1);
      });
    });
  }

  void _extendTimebox(int minutes) {
    if (!_isTimeboxRunning) return;
    setState(() {
      final extend = Duration(minutes: minutes);
      _timeboxTotal += extend;
      _timeboxRemaining += extend;
    });
  }

  void _stopTimebox() {
    _timeboxTimer?.cancel();
    setState(() {
      _isTimeboxRunning = false;
      _timeboxRemaining = Duration.zero;
    });
  }

  Future<void> _addTask(int hour) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$hour時のタスクを追加'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '例: お湯を沸かす'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('追加'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase.from('mindless_tasks').insert({
        'user_id': userId,
        'task_date': DateFormat('yyyy-MM-dd').format(_selectedDate),
        'hour_slot': hour,
        'content': result,
        'is_completed': false,
      });
      _loadTasks();
    }
  }

  Future<void> _toggleTask(int id, bool currentVal) async {
    // 楽観的UI更新（待たずに切り替え）
    setState(() {
      // ローカルデータを無理やり書き換えるのは複雑なので、今回はロードし直す方式で
    });
    await _supabase
        .from('mindless_tasks')
        .update({'is_completed': !currentVal}).eq('id', id);
    _loadTasks();
  }

  Future<void> _deleteTask(int id) async {
    await _supabase.from('mindless_tasks').delete().eq('id', id);
    _loadTasks();
  }

  Widget _buildTimeboxPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        border: Border(
          top: BorderSide(color: Colors.amber.shade200),
          bottom: BorderSide(color: Colors.amber.shade200),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.hourglass_bottom, color: Colors.orange.shade800),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '先に時間制限を決める（1つの手間）',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '完了 $_completedTimeboxCount 回',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '「動く」も「考える」も先に終了時刻を決めると、脱線から戻りやすくなります。',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _timeboxPresets.map((minutes) {
              return ChoiceChip(
                label: Text('$minutes分'),
                selected: _selectedMinutes == minutes,
                onSelected: (_) {
                  setState(() => _selectedMinutes = minutes);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed:
                      _isTimeboxRunning ? null : () => _startTimeboxFlow('動く'),
                  icon: const Icon(Icons.directions_run),
                  label: const Text('動くを開始'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed:
                      _isTimeboxRunning ? null : () => _startTimeboxFlow('考える'),
                  icon: const Icon(Icons.psychology),
                  label: const Text('考えるを開始'),
                ),
              ),
            ],
          ),
          if (_isTimeboxRunning || _timeboxRemaining.inSeconds > 0) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_timeboxMode: $_timeboxGoal',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatRemaining(_timeboxRemaining),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(value: _timeboxProgress()),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isTimeboxRunning
                              ? () => _extendTimebox(5)
                              : null,
                          icon: const Icon(Icons.add_alarm),
                          label: const Text('5分延長'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isTimeboxRunning ? _stopTimebox : null,
                          icon: const Icon(Icons.stop_circle_outlined),
                          label: const Text('終了'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('思考停止脱出ログ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _selectDate(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // コンセプトヘッダー
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey.shade200,
            width: double.infinity,
            child: Column(
              children: [
                Text(
                  DateFormat('yyyy/MM/dd (E)', 'ja').format(_selectedDate),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '「脱線したら、時間制限を合図に元の目的へ戻る」',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          _buildTimeboxPanel(),

          // タイムライン
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: 24, // 0時〜23時
                    itemBuilder: (context, hour) {
                      final tasks = _tasksByHour[hour] ?? [];
                      // 現在時刻のハイライト
                      final isCurrentHour =
                          _selectedDate.day == DateTime.now().day &&
                              _selectedDate.month == DateTime.now().month &&
                              _selectedDate.year == DateTime.now().year &&
                              hour == DateTime.now().hour;

                      return Container(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.grey.shade300),
                            left: isCurrentHour
                                ? const BorderSide(color: Colors.blue, width: 4)
                                : BorderSide.none,
                          ),
                          color: isCurrentHour
                              ? Colors.blue.withValues(alpha: 0.05)
                              : null,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 時間ラベル
                            Container(
                              width: 60,
                              padding: const EdgeInsets.all(12),
                              alignment: Alignment.topCenter,
                              child: Text(
                                '$hour:00',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      isCurrentHour ? Colors.blue : Colors.grey,
                                ),
                              ),
                            ),

                            // タスクリストエリア
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (tasks.isEmpty)
                                    InkWell(
                                      onTap: () => _addTask(hour),
                                      child: Container(
                                        height: 40,
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          '＋ タスクを追加',
                                          style: TextStyle(
                                            color: Colors.grey.shade400,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    )
                                  else
                                    ...tasks.map((task) {
                                      final isDone =
                                          task['is_completed'] as bool;
                                      return InkWell(
                                        onLongPress: () =>
                                            _deleteTask(task['id']),
                                        onTap: () =>
                                            _toggleTask(task['id'], isDone),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                            horizontal: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            border: Border(
                                              bottom: BorderSide(
                                                color: Colors.grey.shade100,
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                isDone
                                                    ? Icons.check_circle
                                                    : Icons.circle_outlined,
                                                color: isDone
                                                    ? Colors.green
                                                    : Colors.grey,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  task['content'],
                                                  style: TextStyle(
                                                    decoration: isDone
                                                        ? TextDecoration
                                                            .lineThrough
                                                        : null,
                                                    color: isDone
                                                        ? Colors.grey
                                                        : Colors.black,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }),
                                  // タスクがある場合も追加ボタンを下部に表示
                                  if (tasks.isNotEmpty)
                                    InkWell(
                                      onTap: () => _addTask(hour),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 4,
                                        ),
                                        alignment: Alignment.centerLeft,
                                        child: Icon(
                                          Icons.add,
                                          size: 16,
                                          color: Colors.grey.shade400,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
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
