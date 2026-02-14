import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class MindlessTaskPage extends StatefulWidget {
  const MindlessTaskPage({super.key});

  @override
  State<MindlessTaskPage> createState() => _MindlessTaskPageState();
}

class _MindlessTaskPageState extends State<MindlessTaskPage> {
  final _supabase = Supabase.instance.client;
  DateTime _selectedDate = DateTime.now();

  // データ構造: { 6: [Task1, Task2], 7: [Task3] } のように時間ごとのリスト
  Map<int, List<Map<String, dynamic>>> _tasksByHour = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
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
      if (userId == null) return;

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
              child: const Text('キャンセル')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('思考停止タスクロガー'),
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
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  '「やる気は出ない。とにかく思考停止して手を動かす」',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),

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
                              ? Colors.blue.withOpacity(0.05)
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
                                              fontSize: 12),
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
                                              vertical: 8, horizontal: 4),
                                          decoration: BoxDecoration(
                                            border: Border(
                                                bottom: BorderSide(
                                                    color:
                                                        Colors.grey.shade100)),
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
                                            vertical: 4),
                                        alignment: Alignment.centerLeft,
                                        child: Icon(Icons.add,
                                            size: 16,
                                            color: Colors.grey.shade400),
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
