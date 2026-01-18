import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:confetti/confetti.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../services/gamification_service.dart';

class MorningBriefingPage extends StatefulWidget {
  const MorningBriefingPage({super.key});

  @override
  State<MorningBriefingPage> createState() => _MorningBriefingPageState();
}

class _MorningBriefingPageState extends State<MorningBriefingPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _todoController = TextEditingController();
  List<Map<String, dynamic>> _todos = [];
  List<Map<String, dynamic>> _subtasks = [];
  StreamSubscription? _todosSubscription;
  StreamSubscription? _subtasksSubscription;
  late TabController _tabController;
  bool _isLoading = true;
  DateTime? _selectedDate;
  Map<String, dynamic>? _weatherData;
  late ConfettiController _confettiController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  String _selectedRecurrence = 'none'; // 新規タスク用の繰り返し設定
  String _selectedCategory = 'work'; // 新規タスク用のカテゴリ
  String _filterCategory = 'all'; // リスト表示用のフィルタ
  int? _selectedDuration; // 新規タスク用の見積もり時間（分）
  String _sortOrder = 'manual'; // 並び替え順 ('manual', 'estimated_asc')
  String? _geminiApiKey; // 日報生成用APIキー

  final Map<String, String> _categoryLabels = {
    'work': '仕事',
    'private': 'プライベート',
    'health': '健康',
    'study': '学習',
    'other': 'その他',
  };

  final Map<String, IconData> _categoryIcons = {
    'work': Icons.work,
    'private': Icons.home,
    'health': Icons.favorite,
    'study': Icons.school,
    'other': Icons.category,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 1));
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
        .listen((data) {
      // クライアントサイドでソート (DBカラム不足時のクラッシュ回避のため)
      data.sort((a, b) {
        final aOrder = a['order_index'] as num? ?? 0;
        final bOrder = b['order_index'] as num? ?? 0;
        return aOrder.compareTo(bOrder);
      });

      if (mounted) {
        setState(() {
          _todos = data;
          _isLoading = false;
        });
      }
    }, onError: (error) {
      debugPrint('Stream error: $error');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    });

    _subtasksSubscription = Supabase.instance.client
        .from('daily_subtasks')
        .stream(primaryKey: ['id']).listen((data) {
      if (mounted) {
        setState(() {
          _subtasks = data;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _tabController.dispose();
    _confettiController.dispose();
    _todosSubscription?.cancel();
    _subtasksSubscription?.cancel();
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

  Future<void> _createNextRecurringTask(Map<String, dynamic> sourceTask) async {
    final recurrence = sourceTask['recurrence'] as String;
    final taskTitle = sourceTask['task'] as String;
    final isImportant = sourceTask['is_important'] as bool? ?? false;
    final category = sourceTask['category'] as String? ?? 'work';
    final estimatedMinutes = sourceTask['estimated_minutes'] as int?;

    // 次の期限を計算（完了した今日を基準にする）
    DateTime baseDate = DateTime.now();
    DateTime nextDate = baseDate;

    if (recurrence == 'daily') {
      nextDate = baseDate.add(const Duration(days: 1));
    } else if (recurrence == 'weekly') {
      nextDate = baseDate.add(const Duration(days: 7));
    } else if (recurrence == 'monthly') {
      nextDate = DateTime(baseDate.year, baseDate.month + 1, baseDate.day);
    }

    // order_indexの最大値取得
    int maxOrder = 0;
    if (_todos.isNotEmpty) {
      for (var t in _todos) {
        final o = t['order_index'] as int? ?? 0;
        if (o > maxOrder) maxOrder = o;
      }
    }

    try {
      await Supabase.instance.client.from('daily_todos').insert({
        'task': taskTitle,
        'is_completed': false,
        'is_important': isImportant,
        'due_date': nextDate.toIso8601String(),
        'recurrence': recurrence, // 繰り返し設定を引き継ぐ
        'category': category, // カテゴリを引き継ぐ
        'estimated_minutes': estimatedMinutes, // 見積もり時間を引き継ぐ
        'order_index': maxOrder + 1,
      });
    } catch (e) {
      debugPrint('Error creating recurring task: $e');
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
        'is_important': false,
        'due_date': _selectedDate?.toIso8601String(),
        'recurrence': _selectedRecurrence,
        'category': _selectedCategory,
        'estimated_minutes': _selectedDuration,
        'order_index': maxOrder + 1,
      });
      _todoController.clear();
      setState(() {
        _selectedDate = null;
        _selectedRecurrence = 'none';
        _selectedCategory = 'work';
        _selectedDuration = null;
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

  Future<void> _toggleTodo(String id, bool currentValue, String taskTitle,
      int? estimatedMinutes) async {
    int? actualMinutes;
    String? reflection;

    // タスクを完了にする場合のみ、実績時間を入力
    if (!currentValue) {
      final timeController =
          TextEditingController(text: estimatedMinutes?.toString() ?? '');
      final reflectionController = TextEditingController();
      final shouldComplete = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('作業時間の記録'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('このタスクにかかった実際の時間は？'),
              const SizedBox(height: 16),
              TextField(
                controller: timeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '実績時間 (分)',
                  border: OutlineInputBorder(),
                  suffixText: '分',
                ),
                autofocus: true,
                onSubmitted: (_) => Navigator.pop(context, true),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reflectionController,
                decoration: const InputDecoration(
                  labelText: '振り返り・メモ',
                  hintText: '感想や次回の改善点など...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('完了'),
            ),
          ],
        ),
      );

      if (shouldComplete != true) return; // キャンセルされた場合は処理中断

      if (timeController.text.isNotEmpty) {
        actualMinutes = int.tryParse(timeController.text);
      }
      if (reflectionController.text.isNotEmpty) {
        reflection = reflectionController.text;
      }
    }

    try {
      final updates = <String, dynamic>{
        'is_completed': !currentValue,
      };

      if (!currentValue) {
        updates['actual_minutes'] = actualMinutes;
        updates['reflection'] = reflection;
      } else {
        updates['actual_minutes'] = null; // 未完了に戻す場合は実績時間をクリア
        updates['reflection'] = null;
      }

      await Supabase.instance.client
          .from('daily_todos')
          .update(updates)
          .eq('id', id);

      if (!currentValue && mounted) {
        _confettiController.play();

        // 繰り返しタスクの場合、次のタスクを作成
        final todoIndex = _todos.indexWhere((t) => t['id'] == id);
        if (todoIndex != -1) {
          final todo = _todos[todoIndex];
          final recurrence = todo['recurrence'] as String? ?? 'none';
          if (recurrence != 'none') {
            await _createNextRecurringTask(todo);
          }
        }

        try {
          // 効果音を再生 (assets/sounds/success.mp3 を用意してください)
          await _audioPlayer.play(AssetSource('sounds/success.mp3'));
        } catch (e) {
          debugPrint('SE Play Error: $e');
        }
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
      } else if (currentValue && mounted) {
        // タスク完了取り消し時にポイント減算
        context.read<GamificationService>().awardPoints(
              -10,
              reason: 'タスク完了取り消し: $taskTitle',
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラーが発生しました: $e')),
        );
      }
    }
  }

  Future<void> _deleteTodo(String id) async {
    await Supabase.instance.client.from('daily_todos').delete().eq('id', id);
  }

  Future<void> _addSubtask(String todoId, String title) async {
    await Supabase.instance.client.from('daily_subtasks').insert({
      'todo_id': todoId,
      'title': title,
      'is_completed': false,
    });
  }

  Future<void> _toggleSubtask(String id, bool currentVal) async {
    await Supabase.instance.client
        .from('daily_subtasks')
        .update({'is_completed': !currentVal}).eq('id', id);
  }

  Future<void> _deleteSubtask(String id) async {
    await Supabase.instance.client.from('daily_subtasks').delete().eq('id', id);
  }

  Future<void> _editTodo(
      String id, String currentTask, DateTime? currentDueDate, String? currentRecurrence, String? currentCategory, int? currentDuration) async {
    final editController = TextEditingController(text: currentTask);
    DateTime? editDate = currentDueDate;
    String editRecurrence = currentRecurrence ?? 'none';
    String editCategory = currentCategory ?? 'work';
    int? editDuration = currentDuration;

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
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: editRecurrence,
                  decoration: const InputDecoration(
                    labelText: '繰り返し',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'none', child: Text('繰り返しなし')),
                    DropdownMenuItem(value: 'daily', child: Text('毎日')),
                    DropdownMenuItem(value: 'weekly', child: Text('毎週')),
                    DropdownMenuItem(value: 'monthly', child: Text('毎月')),
                  ],
                  onChanged: (val) {
                    setState(() => editRecurrence = val!);
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: editCategory,
                  decoration: const InputDecoration(
                    labelText: 'カテゴリ',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: _categoryLabels.entries.map((e) {
                    return DropdownMenuItem(
                      value: e.key,
                      child: Row(children: [
                        Icon(_categoryIcons[e.key], size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(e.value),
                      ]),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() => editCategory = val!);
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int?>(
                  value: editDuration,
                  decoration: const InputDecoration(
                    labelText: '見積もり時間',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('設定なし')),
                    DropdownMenuItem(value: 15, child: Text('15分')),
                    DropdownMenuItem(value: 30, child: Text('30分')),
                    DropdownMenuItem(value: 45, child: Text('45分')),
                    DropdownMenuItem(value: 60, child: Text('1時間')),
                    DropdownMenuItem(value: 90, child: Text('1.5時間')),
                    DropdownMenuItem(value: 120, child: Text('2時間')),
                  ],
                  onChanged: (val) => setState(() => editDuration = val),
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
                        'recurrence': editRecurrence,
                        'category': editCategory,
                        'estimated_minutes': editDuration,
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

  Future<void> _showTaskDetails(Map<String, dynamic> todo) async {
    final todoId = todo['id'] as String;
    final task = todo['task'] as String;
    final dueDateStr = todo['due_date'] as String?;
    final createdAtStr = todo['created_at'] as String?;
    final isCompleted = todo['is_completed'] as bool;
    final isImportant = todo['is_important'] as bool? ?? false;
    final recurrence = todo['recurrence'] as String? ?? 'none';
    final category = todo['category'] as String? ?? 'work';
    final estimatedMinutes = todo['estimated_minutes'] as int?;
    final actualMinutes = todo['actual_minutes'] as int?;
    final reflection = todo['reflection'] as String?;

    String formattedDate(String? dateStr) {
      if (dateStr == null) return 'なし';
      final date = DateTime.parse(dateStr).toLocal();
      return '${date.year}/${date.month}/${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }

    String recurrenceText = 'なし';
    if (recurrence == 'daily') recurrenceText = '毎日';
    if (recurrence == 'weekly') recurrenceText = '毎週';
    if (recurrence == 'monthly') recurrenceText = '毎月';
    final categoryText = _categoryLabels[category] ?? category;

    final subtaskController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('タスク詳細 & サブタスク'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('内容: $task',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('状態: ${isCompleted ? "完了" : "未完了"}'),
                  Text('重要: ${isImportant ? "はい" : "いいえ"}'),
                  Text('期限: ${formattedDate(dueDateStr)}'),
                  Text('繰り返し: $recurrenceText'),
                  Text('カテゴリ: $categoryText'),
                  Text('見積もり: ${estimatedMinutes != null ? "$estimatedMinutes分" : "なし"}'),
                  Text('実績: ${actualMinutes != null ? "$actualMinutes分" : "なし"}'),
                  if (reflection != null && reflection.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('振り返り:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(reflection),
                  ],
                  Text('作成: ${formattedDate(createdAtStr)}'),
                  const Divider(height: 24),
                  const Text('サブタスク',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: subtaskController,
                          decoration: const InputDecoration(
                            hintText: 'サブタスクを追加...',
                            isDense: true,
                            contentPadding: EdgeInsets.all(8),
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (val) {
                            if (val.trim().isNotEmpty) {
                              _addSubtask(todoId, val.trim());
                              subtaskController.clear();
                            }
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: Colors.blue),
                        onPressed: () {
                          if (subtaskController.text.trim().isNotEmpty) {
                            _addSubtask(todoId, subtaskController.text.trim());
                            subtaskController.clear();
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // ダイアログ内でもリアルタイム更新するためにStreamBuilderを使用
                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: Supabase.instance.client
                        .from('daily_subtasks')
                        .stream(primaryKey: ['id'])
                        .eq('todo_id', todoId)
                        .order('created_at'),
                    builder: (context, snapshot) {
                      final subtasks = snapshot.data ?? [];
                      if (subtasks.isEmpty) {
                        return const Text('サブタスクはありません',
                            style: TextStyle(color: Colors.grey));
                      }
                      return Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: subtasks.length,
                          itemBuilder: (context, index) {
                            final st = subtasks[index];
                            final stId = st['id'] as String;
                            final stTitle = st['title'] as String;
                            final stCompleted = st['is_completed'] as bool;
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Checkbox(
                                value: stCompleted,
                                onChanged: (val) =>
                                    _toggleSubtask(stId, stCompleted),
                              ),
                              title: Text(
                                stTitle,
                                style: TextStyle(
                                  decoration: stCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: stCompleted ? Colors.grey : null,
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.close, size: 16),
                                onPressed: () => _deleteSubtask(stId),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('閉じる'),
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

  Future<void> _exportHistoryToCsv() async {
    final historyTodos =
        _todos.where((t) => t['is_completed'] == true).toList();

    if (historyTodos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('エクスポートする履歴がありません')),
      );
      return;
    }

    final buffer = StringBuffer();
    // Header
    buffer.writeln('Task,Category,Created At,Due Date,Important,Recurrence,Estimated Minutes,Actual Minutes,Reflection');

    // Rows
    for (final todo in historyTodos) {
      final task = _escapeCsv(todo['task'] as String);
      final category = _categoryLabels[todo['category']] ?? todo['category'] ?? '';
      final createdAt = todo['created_at'] as String? ?? '';
      final dueDate = todo['due_date'] as String? ?? '';
      final isImportant = (todo['is_important'] as bool? ?? false) ? 'Yes' : 'No';
      final recurrence = todo['recurrence'] as String? ?? 'none';
      final estimated = todo['estimated_minutes']?.toString() ?? '';
      final actual = todo['actual_minutes']?.toString() ?? '';
      final reflection = _escapeCsv(todo['reflection'] as String? ?? '');

      buffer.writeln('$task,$category,$createdAt,$dueDate,$isImportant,$recurrence,$estimated,$actual,$reflection');
    }

    final csvData = buffer.toString();
    final uri = Uri.parse('data:text/csv;charset=utf-8,${Uri.encodeComponent(csvData)}');
    if (!await launchUrl(uri)) {
      debugPrint('Could not launch CSV export url');
    }
  }

  String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  Future<void> _generateDailyReport() async {
    final historyTodos =
        _todos.where((t) => t['is_completed'] == true).toList();

    if (historyTodos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('日報を生成するための完了タスクがありません')),
      );
      return;
    }

    if (_geminiApiKey == null) {
      await _showApiKeyDialog();
      if (_geminiApiKey == null) return;
    }

    setState(() => _isLoading = true);

    try {
      final model = GenerativeModel(model: 'gemini-pro', apiKey: _geminiApiKey!);
      final prompt = _buildDailyReportPrompt(historyTodos);
      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);

      if (mounted && response.text != null) {
        _showReportDialog(response.text!);
      }
    } catch (e) {
      debugPrint('Gemini Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('日報生成エラー: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showApiKeyDialog() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gemini APIキーの設定'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('日報を自動生成するにはGemini APIキーが必要です。'),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'API Key',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() => _geminiApiKey = controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text('設定'),
          ),
        ],
      ),
    );
  }

  String _buildDailyReportPrompt(List<Map<String, dynamic>> tasks) {
    final buffer = StringBuffer();
    buffer.writeln('あなたは優秀なビジネスパーソンです。以下の本日のタスク実績データを元に、簡潔で分かりやすい日報を作成してください。');
    buffer.writeln('構成は「本日の業務内容」「成果・振り返り」「明日の予定・課題」としてください。');
    buffer.writeln('特に「振り返り」の内容を重視し、ポジティブかつ建設的なトーンでまとめてください。');
    buffer.writeln('\n--- タスク実績データ ---');

    for (final task in tasks) {
      final title = task['task'];
      final category = _categoryLabels[task['category']] ?? task['category'];
      final estimated = task['estimated_minutes'] != null ? '${task['estimated_minutes']}分' : '設定なし';
      final actual = task['actual_minutes'] != null ? '${task['actual_minutes']}分' : '不明';
      final reflection = task['reflection'] ?? 'なし';

      buffer.writeln('- タスク名: $title');
      buffer.writeln('  カテゴリ: $category');
      buffer.writeln('  見積もり: $estimated, 実績: $actual');
      buffer.writeln('  振り返りメモ: $reflection');
      buffer.writeln('');
    }

    return buffer.toString();
  }

  void _showReportDialog(String report) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('生成された日報'),
        content: SingleChildScrollView(
          child: SelectableText(report),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: report));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('クリップボードにコピーしました')),
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text('コピー'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // フィルタリング
    var filteredTodos = _filterCategory == 'all'
        ? List<Map<String, dynamic>>.from(_todos)
        : _todos.where((t) => (t['category'] ?? 'work') == _filterCategory).toList();

    // ソート適用
    if (_sortOrder == 'estimated_asc') {
      filteredTodos.sort((a, b) {
        // null (設定なし) は後ろにするために大きな値を設定
        final aEst = a['estimated_minutes'] as int? ?? 999999;
        final bEst = b['estimated_minutes'] as int? ?? 999999;
        return aEst.compareTo(bEst);
      });
    }

    final totalTasks = filteredTodos.length;
    final completedTasks =
        filteredTodos.where((t) => t['is_completed'] == true).length;
    final progress = totalTasks > 0 ? completedTasks / totalTasks : 0.0;
    
    // タスクの振り分け
    final activeTodos = filteredTodos.where((t) => t['is_completed'] == false).toList();
    final historyTodos = filteredTodos.where((t) => t['is_completed'] == true).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('モーニング・ブリーフィング'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'ミッション'), Tab(text: '履歴')],
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.orange,
        ),
        backgroundColor: Colors.indigo.shade900,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          Column(
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
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      const Text('フィルタ:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('すべて'),
                        selected: _filterCategory == 'all',
                        onSelected: (val) => setState(() => _filterCategory = 'all'),
                      ),
                      ..._categoryLabels.entries.map((e) {
                        return Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: FilterChip(
                            avatar: Icon(_categoryIcons[e.key], size: 16),
                            label: Text(e.value),
                            selected: _filterCategory == e.key,
                            onSelected: (val) => setState(() => _filterCategory = e.key),
                          ),
                        );
                      }),
                      const SizedBox(width: 16),
                      const Text('並び替え:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      PopupMenuButton<String>(
                        initialValue: _sortOrder,
                        tooltip: '並び替え順を変更',
                        icon: Icon(
                          Icons.sort,
                          color: _sortOrder != 'manual' ? Colors.orange : Colors.grey,
                        ),
                        onSelected: (val) => setState(() => _sortOrder = val),
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'manual', child: Text('手動 (ドラッグ)')),
                          const PopupMenuItem(value: 'estimated_asc', child: Text('見積もり時間 (短い順)')),
                        ],
                      ),
                    ],
                  ),
                ),
                if (filteredTodos.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '今日の進捗',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${(progress * 100).toInt()}% ($completedTasks/$totalTasks)',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white,
                        color: progress == 1.0 ? Colors.orange : Colors.green,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
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
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.repeat,
                    color: _selectedRecurrence != 'none' ? Colors.orange : Colors.grey,
                  ),
                  tooltip: '繰り返し設定',
                  onSelected: (value) {
                    setState(() {
                      _selectedRecurrence = value;
                    });
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'none', child: Text('繰り返しなし')),
                    const PopupMenuItem(value: 'daily', child: Text('毎日')),
                    const PopupMenuItem(value: 'weekly', child: Text('毎週')),
                    const PopupMenuItem(value: 'monthly', child: Text('毎月')),
                  ],
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: Icon(
                    _categoryIcons[_selectedCategory],
                    color: Colors.grey,
                  ),
                  tooltip: 'カテゴリ選択',
                  onSelected: (value) {
                    setState(() {
                      _selectedCategory = value;
                    });
                  },
                  itemBuilder: (context) => _categoryLabels.entries.map((e) {
                    return PopupMenuItem(
                      value: e.key,
                      child: Row(children: [
                        Icon(_categoryIcons[e.key], color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(e.value),
                      ]),
                    );
                  }).toList(),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<int>(
                  icon: Icon(
                    Icons.access_time,
                    color: _selectedDuration != null ? Colors.orange : Colors.grey,
                  ),
                  tooltip: '見積もり時間',
                  onSelected: (value) {
                    setState(() {
                      _selectedDuration = value;
                    });
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 15, child: Text('15分')),
                    const PopupMenuItem(value: 30, child: Text('30分')),
                    const PopupMenuItem(value: 45, child: Text('45分')),
                    const PopupMenuItem(value: 60, child: Text('1時間')),
                    const PopupMenuItem(value: 90, child: Text('1.5時間')),
                    const PopupMenuItem(value: 120, child: Text('2時間')),
                  ],
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
            child: TabBarView(
              controller: _tabController,
              children: [
                // --- Tab 1: Active Tasks (Reorderable) ---
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : activeTodos.isEmpty
                        ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.wb_sunny_outlined, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('タスクはありません'),
                          ],
                        ),
                      ) : (_filterCategory != 'all' || _sortOrder != 'manual')
                        // フィルタ適用中または手動ソート以外は並び替え無効 (ListViewを使用)
                        ? ListView.builder(
                            itemCount: activeTodos.length,
                            itemBuilder: (context, index) => _buildTodoItem(activeTodos[index], index, false),
                          )
                    : ReorderableListView.builder(
                        onReorder: _onReorder,
                        itemCount: activeTodos.length,
                        itemBuilder: (context, index) => _buildTodoItem(activeTodos[index], index, true),
                      ),
                
                // --- Tab 2: History (Completed) ---
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : historyTodos.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.history, size: 64, color: Colors.grey),
                                SizedBox(height: 16),
                                Text('完了したタスクはありません'),
                              ],
                            ),
                          ) : Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: _exportHistoryToCsv,
                                          icon: const Icon(Icons.download),
                                          label: const Text('CSV'),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: FilledButton.icon(
                                          onPressed: _generateDailyReport,
                                          icon: const Icon(Icons.auto_awesome),
                                          label: const Text('日報生成 (AI)'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Expanded(
                                child: ListView.builder(
                            itemCount: historyTodos.length,
                            itemBuilder: (context, index) {
                              final todo = historyTodos[index];
                              final id = todo['id'] as String;
                              final task = todo['task'] as String;
                              final createdAtStr = todo['created_at'] as String?;
                              final category = todo['category'] as String? ?? 'work';
                              final actualMinutes = todo['actual_minutes'] as int?;
                              
                              String subtitleText = '';
                              if (createdAtStr != null) {
                                final createdAt = DateTime.parse(createdAtStr).toLocal();
                                subtitleText = '作成: ${timeago.format(createdAt)}';
                              }

                              if (actualMinutes != null) {
                                subtitleText += ' (実績: ${actualMinutes}分)';
                              }

                              return ListTile(
                                onTap: () => _showTaskDetails(todo), // 履歴でも詳細表示
                                leading: const Icon(Icons.check_circle, color: Colors.green),
                                title: Text(
                                  task,
                                  style: const TextStyle(
                                    decoration: TextDecoration.lineThrough,
                                    color: Colors.grey,
                                  ),
                                ),
                                subtitle: Row(
                                  children: [
                                    Icon(_categoryIcons[category], size: 12, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(subtitleText),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.undo),
                                      tooltip: '未完了に戻す',
                                      onPressed: () => _toggleTodo(id, true, task, null),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () => _deleteTodo(id),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                              ),
                            ],
                          ),
              ],
            ),
          ),
        ],
      ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                Colors.green,
                Colors.blue,
                Colors.pink,
                Colors.orange,
                Colors.purple
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodoItem(Map<String, dynamic> todo, int index, bool isReorderable) {
    final isCompleted = todo['is_completed'] as bool;
    final id = todo['id'] as String;
    final task = todo['task'] as String;
    final dueDateStr = todo['due_date'] as String?;
    final createdAtStr = todo['created_at'] as String?;
    final isImportant = todo['is_important'] as bool? ?? false;
    final recurrence = todo['recurrence'] as String? ?? 'none';
    final category = todo['category'] as String? ?? 'work';
    final estimatedMinutes = todo['estimated_minutes'] as int?;
    final actualMinutes = todo['actual_minutes'] as int?;

    // サブタスクの進捗計算
    final mySubtasks = _subtasks.where((s) => s['todo_id'] == id).toList();
    final subTotal = mySubtasks.length;
    final subDone = mySubtasks.where((s) => s['is_completed'] == true).length;

    DateTime? dueDate;
    bool isOverdue = false;
    bool isDueToday = false;

    if (dueDateStr != null) {
      dueDate = DateTime.parse(dueDateStr).toLocal();
      final now = DateTime.now();
      if (!isCompleted) {
        if (now.isAfter(dueDate.add(const Duration(days: 1)))) {
          isOverdue = true;
        } else if (dueDate.year == now.year &&
            dueDate.month == now.month &&
            dueDate.day == now.day) {
          isDueToday = true;
        }
      }
    }

    // サブタイトル（期限 + 経過時間）の生成
    String subtitleText = '';
    if (dueDate != null) {
      subtitleText = '期限: ${dueDate.year}/${dueDate.month}/${dueDate.day}';
      if (isDueToday) {
        subtitleText += ' (今日)';
      }
    }

    if (createdAtStr != null) {
      final createdAt = DateTime.parse(createdAtStr).toLocal();
      final elapsed = timeago.format(createdAt);
      if (subtitleText.isNotEmpty) {
        subtitleText += ' • ';
      }
      subtitleText += '作成: $elapsed';
    }

    if (recurrence != 'none') {
      subtitleText += ' (↻)';
    }

    if (subTotal > 0) {
      subtitleText += ' [Sub: $subDone/$subTotal]';
    }

    if (isCompleted && actualMinutes != null) {
      subtitleText += ' ✅${actualMinutes}分';
      if (estimatedMinutes != null) subtitleText += '/予${estimatedMinutes}分';
    } else if (estimatedMinutes != null) {
      subtitleText += ' ⏱$estimatedMinutes分';
    }

    final content = ListTile(
      onTap: () => _editTodo(id, task, dueDate, recurrence, category, estimatedMinutes),
      onLongPress: () => _showTaskDetails(todo),
      leading: Checkbox(
        value: isCompleted,
        onChanged: (val) => _toggleTodo(id, isCompleted, task, estimatedMinutes),
      ),
      title: Text(
        task,
        style: TextStyle(
          decoration: isCompleted ? TextDecoration.lineThrough : null,
          color: isCompleted
              ? Colors.grey
              : (isOverdue
                  ? Colors.red
                  : (isDueToday ? Colors.orange.shade800 : null)),
          fontWeight: (isOverdue || isDueToday) ? FontWeight.bold : null,
        ),
      ),
      subtitle: Row(
        children: [
          Icon(_categoryIcons[category], size: 12, color: Colors.grey),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              subtitleText,
              style: TextStyle(
                color: isCompleted
                    ? Colors.grey
                    : (isOverdue
                        ? Colors.red
                        : (isDueToday ? Colors.orange.shade800 : Colors.grey)),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (recurrence != 'none')
            const Padding(
              padding: EdgeInsets.only(right: 8.0),
              child: Icon(Icons.repeat, size: 16, color: Colors.grey),
            ),
          IconButton(
            icon: Icon(
              isImportant ? Icons.star : Icons.star_border,
              color: isImportant ? Colors.orange : Colors.grey,
            ),
            onPressed: () => _toggleImportant(id, isImportant),
          ),
          // ドラッグハンドル (並び替え可能な場合のみ表示)
          if (isReorderable)
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(Icons.drag_handle, color: Colors.grey),
              ),
            ),
        ],
      ),
    );

    return Dismissible(
      key: Key(id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('タスクの削除'),
            content: const Text('このタスクを削除してもよろしいですか？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
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
      child: content,
    );
  }
}