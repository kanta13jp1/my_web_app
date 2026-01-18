import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/gamification_service.dart';

class MorningBriefingPage extends StatefulWidget {
  const MorningBriefingPage({super.key});

  @override
  State<MorningBriefingPage> createState() => _MorningBriefingPageState();
}

class _MorningBriefingPageState extends State<MorningBriefingPage> {
  final TextEditingController _todoController = TextEditingController();
  List<Map<String, dynamic>> _todos = [];
  StreamSubscription? _todosSubscription;
  bool _isLoading = true;
  DateTime? _selectedDate;
  Map<String, dynamic>? _weatherData;

  @override
  void initState() {
    super.initState();
    _setupStream();
    _fetchWeather();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkOverdueTasks();
    });
  }

  void _setupStream() {
    _todosSubscription = Supabase.instance.client
        .from('daily_todos')
        .stream(primaryKey: ['id'])
        .order('order_index', ascending: true)
        .listen((data) {
      if (mounted) {
        setState(() {
          _todos = data;
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _todosSubscription?.cancel();
    _todoController.dispose();
    super.dispose();
  }

  Future<void> _fetchWeather() async {
    try {
      // Open-Meteo API (Tokyo)
      final url = Uri.parse(
          'https://api.open-meteo.com/v1/forecast?latitude=35.6895&longitude=139.6917&current_weather=true&timezone=Asia%2FTokyo');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _weatherData = data['current_weather'];
          });
        }
      }
    } catch (e) {
      debugPrint('Weather fetch error: $e');
    }
  }

  IconData _getWeatherIcon(int code) {
    if (code == 0) return Icons.wb_sunny;
    if (code <= 3) return Icons.wb_cloudy;
    if (code <= 48) return Icons.foggy;
    if (code < 70) return Icons.grain; // Rain
    if (code < 80) return Icons.ac_unit; // Snow
    return Icons.thunderstorm;
  }

  Future<void> _checkOverdueTasks() async {
    final now = DateTime.now();
    // ローカル時間の今日の00:00を取得
    final todayStart = DateTime(now.year, now.month, now.day);
    // Supabaseのcreated_at(UTC)と比較するため、ローカルの0時をUTCに変換
    final todayStartUtc = todayStart.toUtc();

    try {
      final response = await Supabase.instance.client
          .from('daily_todos')
          .select()
          .eq('is_completed', false)
          .lt('created_at', todayStartUtc.toIso8601String());

      final overdueTasks = response as List<dynamic>;

      if (overdueTasks.isNotEmpty && mounted) {
        _showMigrationDialog(overdueTasks.length, overdueTasks);
      }
    } catch (e) {
      debugPrint('Error checking overdue tasks: $e');
    }
  }

  Future<void> _showMigrationDialog(int count, List<dynamic> tasks) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('未完了タスクの引き継ぎ'),
        content: Text('昨日以前の未完了タスクが $count 件あります。\n今日のタスクとして引き継ぎますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('そのままにする'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('引き継ぐ'),
          ),
        ],
      ),
    );

    if (result == true) {
      _migrateTasks(tasks);
    }
  }

  Future<void> _migrateTasks(List<dynamic> tasks) async {
    final ids = tasks.map((t) => t['id']).toList();
    final now = DateTime.now().toIso8601String();

    try {
      // 対象タスクのcreated_atを現在時刻に更新して、リストの上部に表示させる
      await Supabase.instance.client
          .from('daily_todos')
          .update({'created_at': now}).filter('id', 'in', ids);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${tasks.length}件のタスクを今日のタスクに移動しました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラーが発生しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _addTodo() async {
    final text = _todoController.text.trim();
    if (text.isEmpty) return;

    // 現在の最大order_indexを取得して、末尾に追加
    int maxOrder = 0;
    if (_todos.isNotEmpty) {
      for (var t in _todos) {
        final o = t['order_index'] as int? ?? 0;
        if (o > maxOrder) maxOrder = o;
      }
    }

    try {
      await Supabase.instance.client.from('daily_todos').insert({
        'task': text,
        'is_completed': false,
        'due_date': _selectedDate?.toIso8601String(),
        'order_index': maxOrder + 1,
      });
      _todoController.clear();
      setState(() {
        _selectedDate = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラーが発生しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleTodo(
      String id, bool currentValue, String taskTitle) async {
    try {
      await Supabase.instance.client
          .from('daily_todos')
          .update({'is_completed': !currentValue}).eq('id', id);

      if (!currentValue && mounted) {
        // タスク完了時にポイント付与
        context.read<GamificationService>().awardPoints(
              10,
              reason: 'タスク完了: $taskTitle',
            );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('タスク完了！ (10pt)'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      // エラーハンドリング
    }
  }

  Future<void> _toggleImportant(String id, bool currentValue) async {
    try {
      await Supabase.instance.client
          .from('daily_todos')
          .update({'is_important': !currentValue}).eq('id', id);
    } catch (e) {
      debugPrint('Error toggling importance: $e');
    }
  }

  Future<void> _deleteTodo(String id) async {
    await Supabase.instance.client.from('daily_todos').delete().eq('id', id);
  }

  Future<void> _editTodo(
      String id, String currentTask, DateTime? currentDueDate) async {
    final editController = TextEditingController(text: currentTask);
    DateTime? editDate = currentDueDate;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('タスクの編集'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: editController,
                  decoration: const InputDecoration(
                    labelText: 'タスク名',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('期限: '),
                    TextButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: editDate ?? DateTime.now(),
                          firstDate: DateTime.now()
                              .subtract(const Duration(days: 365)),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() {
                            editDate = picked;
                          });
                        }
                      },
                      icon: const Icon(Icons.calendar_today),
                      label: Text(editDate != null
                          ? '${editDate!.year}/${editDate!.month}/${editDate!.day}'
                          : '設定なし'),
                    ),
                    if (editDate != null)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            editDate = null;
                          });
                        },
                      ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                onPressed: () async {
                  final newTask = editController.text.trim();
                  if (newTask.isNotEmpty) {
                    try {
                      await Supabase.instance.client
                          .from('daily_todos')
                          .update({
                        'task': newTask,
                        'due_date': editDate?.toIso8601String(),
                      }).eq('id', id);
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      debugPrint('Error updating todo: $e');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('更新エラー: $e')),
                        );
                      }
                    }
                  }
                },
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final item = _todos.removeAt(oldIndex);
      _todos.insert(newIndex, item);
    });

    _updateOrderInDb();
  }

  Future<void> _updateOrderInDb() async {
    // 変更された順序をDBに保存
    // ※本来はバッチ更新が望ましいですが、簡易的にループで更新します
    for (int i = 0; i < _todos.length; i++) {
      final item = _todos[i];
      if (item['order_index'] != i) {
        await Supabase.instance.client
            .from('daily_todos')
            .update({'order_index': i}).eq('id', item['id']);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('モーニング・ブリーフィング'),
        backgroundColor: Colors.indigo.shade900,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // ヘッダーメッセージ
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.indigo.shade50,
            child: Column(
              children: [
                const Text(
                  '今日のミッション',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'CEO、本日の最優先事項を定義し、実行に移しましょう。',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                if (_weatherData != null) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                          _getWeatherIcon(
                              (_weatherData!['weathercode'] as num).toInt()),
                          color: Colors.orange),
                      const SizedBox(width: 8),
                      Text(
                        '${_weatherData!['temperature']}°C (Tokyo)',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // 入力エリア
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _todoController,
                    decoration: const InputDecoration(
                      hintText: 'タスクを追加...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onSubmitted: (_) => _addTodo(),
                  ),
                ),
                IconButton(
                  onPressed: () => _selectDate(context),
                  icon: Icon(
                    Icons.calendar_today,
                    color: _selectedDate != null ? Colors.orange : Colors.grey,
                  ),
                  tooltip: _selectedDate != null ? '期限を設定中' : '期限を設定',
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _addTodo,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          // リストエリア
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _todos.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.task_alt, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('タスクはありません'),
                          ],
                        ),
                      )
                    : ReorderableListView.builder(
                        onReorder: _onReorder,
                        itemCount: _todos.length,
                        itemBuilder: (context, index) {
                          final todo = _todos[index];
                          final isCompleted = todo['is_completed'] as bool;
                          final id = todo['id'] as String;
                          final task = todo['task'] as String;
                          final dueDateStr = todo['due_date'] as String?;
                          final isImportant =
                              todo['is_important'] as bool? ?? false;

                          DateTime? dueDate;
                          bool isOverdue = false;

                          if (dueDateStr != null) {
                            dueDate = DateTime.parse(dueDateStr).toLocal();
                            if (!isCompleted &&
                                DateTime.now().isAfter(
                                    dueDate.add(const Duration(days: 1)))) {
                              isOverdue = true;
                            }
                          }

                          return Dismissible(
                            key: Key(id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              color: Colors.red,
                              alignment: Alignment.centerRight,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              child:
                                  const Icon(Icons.delete, color: Colors.white),
                            ),
                            confirmDismiss: (direction) async {
                              return await showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('タスクの削除'),
                                  content: const Text('このタスクを削除してもよろしいですか？'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(false),
                                      child: const Text('キャンセル'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(true),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Colors.red,
                                      ),
                                      child: const Text('削除'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            onDismissed: (_) => _deleteTodo(id),
                            child: ListTile(
                              onTap: () => _editTodo(id, task, dueDate),
                              leading: Checkbox(
                                value: isCompleted,
                                onChanged: (val) =>
                                    _toggleTodo(id, isCompleted, task),
                              ),
                              title: Text(
                                task,
                                style: TextStyle(
                                  decoration: isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: isCompleted
                                      ? Colors.grey
                                      : (isOverdue ? Colors.red : null),
                                  fontWeight:
                                      isOverdue ? FontWeight.bold : null,
                                ),
                              ),
                              subtitle: dueDate != null
                                  ? Text(
                                      '期限: ${dueDate.year}/${dueDate.month}/${dueDate.day}',
                                      style: TextStyle(
                                        color: isOverdue
                                            ? Colors.red
                                            : Colors.grey,
                                      ),
                                    )
                                  : null,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      isImportant
                                          ? Icons.star
                                          : Icons.star_border,
                                      color: isImportant
                                          ? Colors.orange
                                          : Colors.grey,
                                    ),
                                    onPressed: () =>
                                        _toggleImportant(id, isImportant),
                                  ),
                                  // ドラッグハンドル
                                  ReorderableDragStartListener(
                                    index: index,
                                    child: const Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Icon(Icons.drag_handle,
                                          color: Colors.grey),
                                    ),
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