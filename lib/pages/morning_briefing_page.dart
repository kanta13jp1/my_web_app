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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/gamification_service.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

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
  Timer? _reconnectTimer;
  late TabController _tabController;
  bool _isLoading = true;
  DateTime? _selectedDate;
  // for Calendar View
  late final ValueNotifier<List<Map<String, dynamic>>> _selectedEvents;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  Map<String, dynamic>? _weatherData;
  late ConfettiController _confettiController;
  bool _isHeaderExpanded = true;
  final AudioPlayer _audioPlayer = AudioPlayer();
  String _selectedRecurrence = 'none'; // 新規タスク用の繰り返し設定
  String _selectedCategory = 'work'; // 新規タスク用のカテゴリ
  String _filterCategory = 'all'; // リスト表示用のフィルタ
  int? _selectedDuration; // 新規タスク用の見積もり時間（分）
  String _sortOrder = 'manual'; // 並び替え順 ('manual', 'estimated_asc')
  String _selectedDifficulty = 'normal'; // 新規タスク用の難易度
  String? _geminiApiKey; // 日報生成用APIキー
  String _selectedModel = 'gemini-1.5-flash'; // 日報生成用モデル
  String _customPromptInstructions = _defaultPromptInstructions;
  static const String _defaultPromptInstructions =
      'あなたは優秀なビジネスパーソンです。以下の本日のタスク実績データを元に、簡潔で分かりやすい日報を作成してください。\n'
      '構成は「本日の業務内容」「成果・振り返り」「明日の予定・課題」としてください。\n'
      '特に「振り返り」の内容を重視し、ポジティブかつ建設的なトーンでまとめてください。';

  List<Map<String, dynamic>> _selectableModels = [
    {
      'name': 'gemini-1.5-flash',
      'methods': ['generateContent'],
    },
    {
      'name': 'gemini-1.5-pro',
      'methods': ['generateContent'],
    },
    {
      'name': 'gemini-pro',
      'methods': ['generateContent'],
    },
    {
      'name': 'gemini-2.0-flash',
      'methods': ['generateContent'],
    },
    {
      'name': 'gemini-2.5-flash',
      'methods': ['generateContent'],
    },
    {
      'name': 'gemini-2.5-pro',
      'methods': ['generateContent'],
    },
  ];

  final Map<String, String> _categoryLabels = {
    'work': '仕事',
    'private': 'プライベート',
    'health': '健康',
    'study': '学習',
    'routine': '毎日の積み上げ', // ★ 追加
    'other': 'その他',
  };

  final Map<String, IconData> _categoryIcons = {
    'work': Icons.work,
    'private': Icons.home,
    'health': Icons.favorite,
    'study': Icons.school,
    'routine': Icons.trending_up, // ★ 追加
    'other': Icons.category,
  };

  final Map<String, Color> _categoryColors = {
    'work': Colors.blue,
    'private': Colors.green,
    'health': Colors.red,
    'study': Colors.orange,
    'routine': Colors.cyan, // ★ 追加
    'other': Colors.grey,
  };

  final Map<String, String> _difficultyLabels = {
    'easy': '簡単',
    'normal': '普通',
    'hard': '難しい',
  };

  final Map<String, Color> _difficultyColors = {
    'easy': Colors.green,
    'normal': Colors.blue,
    'hard': Colors.red,
  };

  final Map<String, int> _difficultyPoints = {
    'easy': 5,
    'normal': 10,
    'hard': 20,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _selectedDay = _focusedDay;
    _selectedEvents = ValueNotifier(_getEventsForDay(_selectedDay!));

    _confettiController =
        ConfettiController(duration: const Duration(seconds: 1));
    _setupStream();
    _fetchWeather();
    _loadSettings();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkOverdueTasks();
    });
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    return _todos.where((todo) {
      if (todo['due_date'] == null) {
        return false;
      }
      try {
        final dueDate = DateTime.parse(todo['due_date']).toLocal();
        return isSameDay(dueDate, day);
      } catch (e) {
        debugPrint('Invalid due_date format: ${todo['due_date']}');
        return false;
      }
    }).toList();
  }

  void _setupStream() {
    _todosSubscription?.cancel();
    _todosSubscription = Supabase.instance.client
        .from('daily_todos')
        .stream(primaryKey: ['id']).listen(
      (data) {
        // クライアントサイドでソート (DBカラム不足時のクラッシュ回避のため)
        data.sort((a, b) {
          final aOrder = a['order_index'] as num? ?? 0;
          final bOrder = b['order_index'] as num? ?? 0;
          return aOrder.compareTo(bOrder);
        });

        if (mounted) {
          setState(() {
            _todos = data;
            // カレンダーのイベントも更新
            if (_selectedDay != null) {
              _selectedEvents.value = _getEventsForDay(_selectedDay!);
            }
            _isLoading = false;
          });
        }
      },
      onError: (error) {
        debugPrint('Stream error: $error');
        if (mounted) {
          setState(() => _isLoading = false);
          _scheduleReconnect();
        }
      },
    );

    _subtasksSubscription?.cancel();
    _subtasksSubscription = Supabase.instance.client
        .from('daily_subtasks')
        .stream(primaryKey: ['id']).listen(
      (data) {
        if (mounted) {
          setState(() {
            _subtasks = data;
          });
        }
      },
      onError: (error) {
        debugPrint('Subtasks Stream error: $error');
        if (mounted) _scheduleReconnect();
      },
    );
  }

  void _scheduleReconnect() {
    if (_reconnectTimer?.isActive ?? false) return;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('接続エラー。5秒後に再接続を試みます...'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );
    }

    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        debugPrint('Reconnecting...');
        _setupStream();
      }
    });
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _audioPlayer.dispose();
    _tabController.dispose();
    _confettiController.dispose();
    _todosSubscription?.cancel();
    _subtasksSubscription?.cancel();
    _todoController.dispose();
    _selectedEvents.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _customPromptInstructions = prefs.getString('daily_report_prompt') ??
            _defaultPromptInstructions;

        // gemini-pro は 404 エラーになる可能性があるため、デフォルトを gemini-1.5-flash に変更
        String? savedModel = prefs.getString('gemini_model');
        if (savedModel == 'gemini-pro' || savedModel == null) {
          savedModel = 'gemini-1.5-flash';
        }
        _selectedModel = savedModel;
        _geminiApiKey = prefs.getString('gemini_api_key');
      });
    }
  }

  Future<void> _fetchWeather() async {
    try {
      // Open-Meteo API (Tokyo)
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=35.6895&longitude=139.6917&current_weather=true&timezone=Asia%2FTokyo',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _weatherData = data['current_weather'] as Map<String, dynamic>;
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

      final overdueTasks = List<Map<String, dynamic>>.from(response);

      if (overdueTasks.isNotEmpty && mounted) {
        _showMigrationDialog(overdueTasks.length, overdueTasks);
      }
    } catch (e) {
      debugPrint('Error checking overdue tasks: $e');
    }
  }

  Future<void> _showMigrationDialog(
    int count,
    List<Map<String, dynamic>> tasks,
  ) async {
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
      migrateTasks(tasks);
    }
  }

  Future<void> migrateTasks(List<Map<String, dynamic>> tasks) async {
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

  Future<void> selectDate(BuildContext context) async {
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

  Future<void> createNextRecurringTask(Map<String, dynamic> sourceTask) async {
    final recurrence = sourceTask['recurrence'] as String;
    final taskTitle = sourceTask['task'] as String;
    final isImportant = sourceTask['is_important'] as bool? ?? false;
    final category = sourceTask['category'] as String? ?? 'work';
    final estimatedMinutes = sourceTask['estimated_minutes'] as int?;
    final difficulty = sourceTask['difficulty'] as String? ?? 'normal';

    // 次の期限を計算（完了した今日を基準にする）
    final DateTime baseDate = DateTime.now();
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
        'difficulty': difficulty, // 難易度を引き継ぐ
        'order_index': maxOrder + 1,
      });
    } catch (e) {
      debugPrint('Error creating recurring task: $e');
    }
  }

  Future<void> addTodo() async {
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
        'difficulty': _selectedDifficulty,
        'order_index': maxOrder + 1,
      });
      _todoController.clear();
      setState(() {
        _selectedDate = null;
        _selectedRecurrence = 'none';
        _selectedCategory = 'work';
        _selectedDuration = null;
        _selectedDifficulty = 'normal';
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

  Future<void> toggleTodo(
    String id,
    bool currentValue,
    String taskTitle,
    int? estimatedMinutes,
    String difficulty,
  ) async {
    int? actualMinutes;
    String? reflection;
    final points = _difficultyPoints[difficulty] ?? 10;

    // タスクを完了にする場合、最重要タスクのチェックを行う
    if (!currentValue) {
      final currentTask =
          _todos.firstWhere((t) => t['id'] == id, orElse: () => {});
      if (currentTask.isNotEmpty) {
        final isCurrentImportant = currentTask['is_important'] == true;
        // 自分が重要タスクでない場合、他に未完了の重要タスクがあるかチェック
        if (!isCurrentImportant) {
          final hasIncompleteImportantTasks = _todos.any(
            (t) => t['is_important'] == true && t['is_completed'] == false,
          );

          if (hasIncompleteImportantTasks) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('最重要タスク（★）が残っています。先に片付けましょう！'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
            return;
          }
        }
      }
    }

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
        // 難易度に応じて紙吹雪の時間を調整
        if (difficulty == 'hard') {
          _confettiController.duration =
              const Duration(seconds: 3); // 難しいタスクは長めに
        } else {
          _confettiController.duration = const Duration(seconds: 1);
        }
        _confettiController.play();

        // 繰り返しタスクの場合、次のタスクを作成
        final todoIndex = _todos.indexWhere((t) => t['id'] == id);
        if (todoIndex != -1) {
          final todo = _todos[todoIndex];
          final recurrence = todo['recurrence'] as String? ?? 'none';
          if (recurrence != 'none') {
            await createNextRecurringTask(todo);
          }
        }

        try {
          // 難易度に応じて効果音を変更
          String soundPath = 'sounds/success.mp3'; // Normal
          if (difficulty == 'easy') {
            soundPath = 'sounds/success_easy.mp3';
          } else if (difficulty == 'hard') {
            soundPath = 'sounds/success_hard.mp3';
          }
          await _audioPlayer.play(AssetSource(soundPath));
        } catch (e) {
          debugPrint('SE Play Error: $e');
        }

        if (!mounted) return;

        // タスク完了時にポイント付与
        context.read<GamificationService>().awardPoints(
              points,
              reason: 'タスク完了: $taskTitle',
            );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('タスク完了！ (${points}pt)'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );
      } else if (currentValue && mounted) {
        // タスク完了取り消し時にポイント減算
        context.read<GamificationService>().awardPoints(
              -points,
              reason: 'タスク完了取り消し: $taskTitle',
            );
      }
    } catch (e) {
      // エラーハンドリング
    }
  }

  Future<void> toggleImportant(String id, bool currentValue) async {
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

  Future<void> deleteTodo(String id) async {
    await Supabase.instance.client.from('daily_todos').delete().eq('id', id);
  }

  Future<void> addSubtask(String todoId, String title) async {
    await Supabase.instance.client.from('daily_subtasks').insert({
      'todo_id': todoId,
      'title': title,
      'is_completed': false,
    });
  }

  Future<void> toggleSubtask(String id, bool currentVal) async {
    await Supabase.instance.client
        .from('daily_subtasks')
        .update({'is_completed': !currentVal}).eq('id', id);
  }

  Future<void> deleteSubtask(String id) async {
    await Supabase.instance.client.from('daily_subtasks').delete().eq('id', id);
  }

  Future<void> editTodo(
    String id,
    String currentTask,
    DateTime? currentDueDate,
    String? currentRecurrence,
    String? currentCategory,
    int? currentDuration,
    String? currentDifficulty,
  ) async {
    final editController = TextEditingController(text: currentTask);
    DateTime? editDate = currentDueDate;
    String editRecurrence = currentRecurrence ?? 'none';
    String editCategory = currentCategory ?? 'work';
    int? editDuration = currentDuration;
    String editDifficulty = currentDifficulty ?? 'normal';

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
                      label: Text(
                        editDate != null
                            ? '${editDate!.year}/${editDate!.month}/${editDate!.day}'
                            : '設定なし',
                      ),
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
                  initialValue: editRecurrence,
                  decoration: const InputDecoration(
                    labelText: '繰り返し',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                  initialValue: editCategory,
                  decoration: const InputDecoration(
                    labelText: 'カテゴリ',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: _categoryLabels.entries.map((e) {
                    return DropdownMenuItem(
                      value: e.key,
                      child: Row(
                        children: [
                          Icon(
                            _categoryIcons[e.key],
                            size: 16,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Text(e.value),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() => editCategory = val!);
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int?>(
                  initialValue: editDuration,
                  decoration: const InputDecoration(
                    labelText: '見積もり時間',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: editDifficulty,
                  decoration: const InputDecoration(
                    labelText: '難易度',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: _difficultyLabels.entries.map((e) {
                    return DropdownMenuItem(
                      value: e.key,
                      child: Text(
                        e.value,
                        style: TextStyle(color: _difficultyColors[e.key]),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => editDifficulty = val!),
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
                        'difficulty': editDifficulty,
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

  Future<void> showTaskDetails(Map<String, dynamic> todo) async {
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
    final difficulty = todo['difficulty'] as String? ?? 'normal';

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
    final difficultyText = _difficultyLabels[difficulty] ?? difficulty;

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
                  Text(
                    '内容: $task',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text('状態: ${isCompleted ? "完了" : "未完了"}'),
                  Text('重要: ${isImportant ? "はい" : "いいえ"}'),
                  Text('期限: ${formattedDate(dueDateStr)}'),
                  Text('繰り返し: $recurrenceText'),
                  Text('カテゴリ: $categoryText'),
                  Text('難易度: $difficultyText'),
                  Text(
                    '見積もり: ${estimatedMinutes != null ? "$estimatedMinutes分" : "なし"}',
                  ),
                  Text(
                    '実績: ${actualMinutes != null ? "$actualMinutes分" : "なし"}',
                  ),
                  if (reflection != null && reflection.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text(
                      '振り返り:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(reflection),
                  ],
                  Text('作成: ${formattedDate(createdAtStr)}'),
                  const Divider(height: 24),
                  const Text(
                    'サブタスク',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
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
                              addSubtask(todoId, val.trim());
                              subtaskController.clear();
                            }
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: Colors.blue),
                        onPressed: () {
                          if (subtaskController.text.trim().isNotEmpty) {
                            addSubtask(todoId, subtaskController.text.trim());
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
                        return const Text(
                          'サブタスクはありません',
                          style: TextStyle(color: Colors.grey),
                        );
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
                                    toggleSubtask(stId, stCompleted),
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
                                onPressed: () => deleteSubtask(stId),
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

  void onReorder(int oldIndex, int newIndex) {
    if (_sortOrder != 'manual') return; // 手動ソート時のみ実行

    // The `ReorderableListView` is built from a filtered and sorted list of active todos.
    // We must replicate that list here to correctly map the indices from the callback.
    final activeTodos =
        _todos.where((todo) => todo['is_completed'] == false).toList();

    // Apply the same sorting as in the build method to get the identical list that the user sees.
    activeTodos.sort((a, b) {
      final aImp = a['is_important'] as bool? ?? false;
      final bImp = b['is_important'] as bool? ?? false;
      if (aImp != bImp) {
        return aImp ? -1 : 1;
      }
      final aOrder = a['order_index'] as num? ?? 0;
      final bOrder = b['order_index'] as num? ?? 0;
      return aOrder.compareTo(bOrder);
    });

    setState(() {
      // This adjustment is needed because the item is still at `oldIndex`
      // in the list when `newIndex` is calculated by the framework.
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }

      // 1. Reorder the temporary `activeTodos` list to match the user's action.
      final movedItem = activeTodos.removeAt(oldIndex);
      activeTodos.insert(newIndex, movedItem);

      // 2. Now that `activeTodos` is correctly ordered, we update the `order_index`
      //    on the master `_todos` list. This ensures the order persists across rebuilds.
      //    Active tasks get the lowest indices, followed by completed tasks.
      final completedTodos =
          _todos.where((t) => t['is_completed'] == true).toList();

      int newOrderIndex = 0;
      for (final todo in activeTodos) {
        // Find the corresponding item in the master list and update its order.
        final masterTodo = _todos.firstWhere((t) => t['id'] == todo['id']);
        masterTodo['order_index'] = newOrderIndex++;
      }
      for (final todo in completedTodos) {
        final masterTodo = _todos.firstWhere((t) => t['id'] == todo['id']);
        masterTodo['order_index'] = newOrderIndex++;
      }

      // We don't need to re-order `_todos` here. The `build` method will sort it
      // using the updated `order_index`, which is the source of truth for ordering.
    });

    // The database update can be slow, so run it after the UI state has been updated.
    updateOrderInDb();
  }

  Future<void> updateOrderInDb() async {
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

  Future<void> exportHistoryToCsv() async {
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
    buffer.writeln(
      'Task,Category,Created At,Due Date,Important,Recurrence,Estimated Minutes,Actual Minutes,Reflection,Difficulty',
    );

    // Rows
    for (final todo in historyTodos) {
      final task = escapeCsv(todo['task'] as String);
      final category =
          _categoryLabels[todo['category']] ?? todo['category'] ?? '';
      final createdAt = todo['created_at'] as String? ?? '';
      final dueDate = todo['due_date'] as String? ?? '';
      final isImportant =
          (todo['is_important'] as bool? ?? false) ? 'Yes' : 'No';
      final recurrence = todo['recurrence'] as String? ?? 'none';
      final estimated = todo['estimated_minutes']?.toString() ?? '';
      final actual = todo['actual_minutes']?.toString() ?? '';
      final reflection = escapeCsv(todo['reflection'] as String? ?? '');
      final difficulty = _difficultyLabels[todo['difficulty']] ??
          todo['difficulty'] ??
          'normal';

      buffer.writeln(
        '$task,$category,$createdAt,$dueDate,$isImportant,$recurrence,$estimated,$actual,$reflection,$difficulty',
      );
    }

    final csvData = buffer.toString();
    final uri = Uri.parse(
      'data:text/csv;charset=utf-8,${Uri.encodeComponent(csvData)}',
    );
    if (!await launchUrl(uri)) {
      debugPrint('Could not launch CSV export url');
    }
  }

  String escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  Future<void> generateDailyReport() async {
    final historyTodos =
        _todos.where((t) => t['is_completed'] == true).toList();

    if (historyTodos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('日報を生成するための完了タスクがありません')),
      );
      return;
    }

    if (_geminiApiKey == null) {
      await showApiKeyDialog();
      if (_geminiApiKey == null) return;
    }

    setState(() => _isLoading = true);

    try {
      final model =
          GenerativeModel(model: _selectedModel, apiKey: _geminiApiKey!);
      final prompt = buildDailyReportPrompt(historyTodos);
      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);

      if (mounted && response.text != null) {
        showReportDialog(response.text!, historyTodos);
      }
    } catch (e) {
      debugPrint('Gemini Error: $e');
      if (mounted) {
        final errString = e.toString();
        // 429エラー (Too Many Requests) または Quota (利用枠超過) を検知
        if (errString.contains('429') ||
            errString.contains('Quota') ||
            errString.contains('Too Many Requests')) {
          String? modelInDialog = _selectedModel;
          showDialog<void>(
            context: context,
            builder: (BuildContext context) {
              return StatefulBuilder(
                builder: (context, setDialogState) {
                  return AlertDialog(
                    title: const Text('モデルの利用制限'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                            'モデル「$_selectedModel」は利用制限に達したか、利用できません。'),
                        const SizedBox(height: 20),
                        const Text('別のモデルを選択して再試行してください。'),
                        const SizedBox(height: 10),
                        // Dropdown to select a new model
                        DropdownButton<String>(
                          value: modelInDialog,
                          isExpanded: true,
                          items: _selectableModels
                              .map<DropdownMenuItem<String>>((model) {
                            return DropdownMenuItem<String>(
                              value: model['name'],
                              child: Text(model['name']),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setDialogState(() {
                                modelInDialog = newValue;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    actions: <Widget>[
                      TextButton(
                        child: const Text('キャンセル'),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                      FilledButton(
                        child: const Text('このモデルで再試行'),
                        onPressed: () {
                          if (modelInDialog == null) return;
                          Navigator.of(context).pop();
                          // Update the model on the main page and retry
                          setState(() {
                            _selectedModel = modelInDialog!;
                          });
                          // Save the new model selection to preferences
                          SharedPreferences.getInstance().then((prefs) {
                            prefs.setString('gemini_model', modelInDialog!);
                          });
                          generateDailyReport();
                        },
                      ),
                    ],
                  );
                },
              );
            },
          );
        } else {
          // その他のエラー
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('日報生成エラー: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> showApiKeyDialog() async {
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

  Future<List<Map<String, dynamic>>> fetchGeminiModels(String apiKey) async {
    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['models'] != null) {
          return (data['models'] as List)
              .where(
                (m) =>
                    (m['supportedGenerationMethods'] as List?)
                        ?.contains('generateContent') ??
                    false,
              )
              .map<Map<String, dynamic>>(
                (m) => {
                  'name': m['name'].toString().replaceFirst('models/', ''),
                  'methods': (m['supportedGenerationMethods'] as List<dynamic>)
                      .cast<String>()
                      .toList(),
                },
              )
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Failed to fetch models: $e');
    }
    return [];
  }

  Future<void> showPromptSettingsDialog() async {
    final controller = TextEditingController(text: _customPromptInstructions);
    final apiKeyController = TextEditingController(text: _geminiApiKey ?? '');
    String tempSelectedModel = _selectedModel;
    bool isFetchingModels = false;
    List<Map<String, dynamic>> currentSelectableModels =
        List.from(_selectableModels);

    // 現在選択中のモデルがリストにない場合に追加
    if (!currentSelectableModels.any((m) => m['name'] == tempSelectedModel)) {
      currentSelectableModels.add({
        'name': tempSelectedModel,
        'methods': ['generateContent'],
      });
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('日報設定'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Gemini APIの設定を行います。'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: apiKeyController,
                    decoration: const InputDecoration(
                      labelText: 'Gemini API Key',
                      border: OutlineInputBorder(),
                      hintText: 'APIキーを入力してください',
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 8),
                  if (isFetchingModels)
                    const LinearProgressIndicator()
                  else
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          if (apiKeyController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('APIキーを入力してください')),
                            );
                            return;
                          }
                          setDialogState(() => isFetchingModels = true);
                          final models =
                              await fetchGeminiModels(apiKeyController.text);
                          setDialogState(() {
                            isFetchingModels = false;
                            if (models.isNotEmpty) {
                              currentSelectableModels = models;
                              // 選択中のモデルが新しいリストにない場合、リストの先頭を選択
                              if (!currentSelectableModels
                                  .any((m) => m['name'] == tempSelectedModel)) {
                                tempSelectedModel = models.first['name'];
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${models.length}個のモデルを取得しました'),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('モデルの取得に失敗しました'),
                                ),
                              );
                            }
                          });
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('利用可能なモデル一覧を取得'),
                      ),
                    ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: tempSelectedModel,
                    decoration: const InputDecoration(
                      labelText: '使用モデル',
                      border: OutlineInputBorder(),
                    ),
                    items: currentSelectableModels.map((m) {
                      return DropdownMenuItem(
                        value: m['name'] as String,
                        child: Text(m['name'] as String),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => tempSelectedModel = val);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  // ★ START: Added display for current and available models
                  Container(
                    padding: const EdgeInsets.all(12),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '現在のモデル: ',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                            Expanded(
                              child: Text(
                                tempSelectedModel,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        Text(
                          '利用可能なモデル一覧 (サポートメソッド):',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currentSelectableModels.map((m) {
                            final name = m['name'] as String;
                            final methods =
                                (m['methods'] as List? ?? []).join(', ');
                            return '$name ($methods)';
                          }).join('\n'),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // ★ END: Added display
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'システム指示 (プロンプト)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  controller.text = _defaultPromptInstructions;
                  setDialogState(() => tempSelectedModel = 'gemini-1.5-flash');
                },
                child: const Text('デフォルトに戻す'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString(
                    'daily_report_prompt',
                    controller.text,
                  );
                  await prefs.setString('gemini_model', tempSelectedModel);
                  if (apiKeyController.text.isNotEmpty) {
                    await prefs.setString(
                      'gemini_api_key',
                      apiKeyController.text,
                    );
                  }
                  if (mounted) {
                    setState(() {
                      _customPromptInstructions = controller.text;
                      _selectedModel = tempSelectedModel;
                      if (apiKeyController.text.isNotEmpty) {
                        _geminiApiKey = apiKeyController.text;
                      }
                      // 取得したモデルリストを保存
                      _selectableModels = currentSelectableModels;
                    });
                  }
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );
  }

  String buildDailyReportPrompt(List<Map<String, dynamic>> tasks) {
    final buffer = StringBuffer();
    buffer.writeln(_customPromptInstructions);
    buffer.writeln('\n--- タスク実績データ ---');

    for (final task in tasks) {
      final title = task['task'];
      final category = _categoryLabels[task['category']] ?? task['category'];
      final estimated = task['estimated_minutes'] != null
          ? '${task['estimated_minutes']}分'
          : '設定なし';
      final actual =
          task['actual_minutes'] != null ? '${task['actual_minutes']}分' : '不明';
      final reflection = task['reflection'] ?? 'なし';
      final difficulty =
          _difficultyLabels[task['difficulty']] ?? task['difficulty'] ?? '普通';

      final mySubtasks =
          _subtasks.where((s) => s['todo_id'] == task['id']).toList();
      final subTotal = mySubtasks.length;
      final subDone = mySubtasks.where((s) => s['is_completed'] == true).length;
      final subtaskInfo = subTotal > 0 ? ', サブタスク: $subDone/$subTotal' : '';

      buffer.writeln('- タスク名: $title');
      buffer.writeln('  カテゴリ: $category');
      buffer.writeln(
        '  難易度: $difficulty, 見積もり: $estimated, 実績: $actual$subtaskInfo',
      );
      buffer.writeln('  振り返りメモ: $reflection');
      buffer.writeln('');
    }

    return buffer.toString();
  }

  void showReportDialog(String report, List<Map<String, dynamic>> tasks) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('本日の振り返り'),
        content: SizedBox(
          width: double.maxFinite,
          height: 500,
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                const TabBar(
                  labelColor: Colors.indigo,
                  unselectedLabelColor: Colors.grey,
                  tabs: [
                    Tab(text: '分析グラフ'),
                    Tab(text: 'AI日報'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      buildAnalyticsView(tasks),
                      // ↓↓↓ CHANGED: Use Markdown widget here ↓↓↓
                      Container(
                        padding: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Markdown(
                          data: report,
                          selectable: true, // Allow text selection
                          styleSheet: MarkdownStyleSheet(
                            h1: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo,
                            ),
                            h2: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo,
                            ),
                            h3: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            p: const TextStyle(fontSize: 14, height: 1.5),
                            listBullet: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                      // ↑↑↑ END CHANGE ↑↑↑
                    ],
                  ),
                ),
              ],
            ),
          ),
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

  Widget buildAnalyticsView(List<Map<String, dynamic>> tasks) {
    int totalMinutes = 0;
    int totalEstimated = 0;
    final Map<String, int> categoryCounts = {};

    for (final t in tasks) {
      totalMinutes += t['actual_minutes'] as int? ?? 0;
      totalEstimated += t['estimated_minutes'] as int? ?? 0;
      final String cat = t['category'] as String? ?? 'work';
      categoryCounts[cat] = (categoryCounts[cat] ?? 0) + 1;
    }

    final totalTasks = tasks.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              buildStatCard(
                '完了タスク',
                '$totalTasks件',
                Icons.check_circle,
                Colors.green,
              ),
              buildStatCard(
                '合計時間',
                '$totalMinutes分',
                Icons.timer,
                Colors.blue,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text('カテゴリ別内訳', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: categoryCounts.entries.map((e) {
                  final color = _categoryColors[e.key] ?? Colors.grey;
                  final percentage =
                      (e.value / totalTasks * 100).toStringAsFixed(1);
                  return PieChartSectionData(
                    color: color,
                    value: e.value.toDouble(),
                    title: '${_categoryLabels[e.key] ?? e.key}\n$percentage%',
                    radius: 80,
                    titleStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  );
                }).toList(),
                sectionsSpace: 2,
                centerSpaceRadius: 30,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: categoryCounts.keys.map((key) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    color: _categoryColors[key] ?? Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(_categoryLabels[key] ?? key),
                ],
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          const Text(
            '時間の予実対比 (分)',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: ((totalEstimated > totalMinutes
                                ? totalEstimated
                                : totalMinutes)
                            .toDouble() *
                        1.2) +
                    10, // 0の場合の表示崩れを防ぐためにバッファを追加
                barTouchData: BarTouchData(
                  enabled: false,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) => Colors.transparent,
                    tooltipPadding: EdgeInsets.zero,
                    tooltipMargin: 8,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        rod.toY.round().toString(),
                        const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        const style = TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        );
                        String text = '';
                        if (value.toInt() == 0) text = '見積もり';
                        if (value.toInt() == 1) text = '実績';
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          space: 4,
                          child: Text(text, style: style),
                        );
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: [
                  makeBarGroup(0, totalEstimated.toDouble(), Colors.orange),
                  makeBarGroup(1, totalMinutes.toDouble(), Colors.blue),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  BarChartGroupData makeBarGroup(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 30,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
      showingTooltipIndicators: [0],
    );
  }

  @override
  Widget build(BuildContext context) {
    // フィルタリング

    final filteredTodos = _filterCategory == 'all'
        ? List<Map<String, dynamic>>.from(_todos)
        : _todos
            .where((t) => (t['category'] ?? 'work') == _filterCategory)
            .toList();

    // ソート適用

    filteredTodos.sort((a, b) {
      // 1. 最重要タスク (is_important == true) を常に最優先

      final aImp = a['is_important'] as bool? ?? false;

      final bImp = b['is_important'] as bool? ?? false;

      if (aImp != bImp) {
        return aImp ? -1 : 1; // 重要(true)が先 (-1)
      }

      // 2. ユーザー選択のソート順

      if (_sortOrder == 'estimated_asc') {
        final aEst = a['estimated_minutes'] as int? ?? 999999;

        final bEst = b['estimated_minutes'] as int? ?? 999999;

        return aEst.compareTo(bEst);
      }

      // 3. デフォルト (手動順 / order_index順)

      final aOrder = a['order_index'] as num? ?? 0;

      final bOrder = b['order_index'] as num? ?? 0;

      return aOrder.compareTo(bOrder);
    });

    int totalPoints = 0;

    int completedPoints = 0;

    for (var todo in filteredTodos) {
      final difficulty = todo['difficulty'] as String? ?? 'normal';

      final points = _difficultyPoints[difficulty] ?? 10;

      totalPoints += points;

      if (todo['is_completed'] == true) {
        completedPoints += points;
      }
    }

    final progress = totalPoints > 0 ? completedPoints / totalPoints : 0.0;

    // タスクの振り分け

    final activeTodos =
        filteredTodos.where((t) => t['is_completed'] == false).toList();

    final historyTodos =
        filteredTodos.where((t) => t['is_completed'] == true).toList();

    int totalEstimatedMinutes = 0;

    for (var todo in activeTodos) {
      totalEstimatedMinutes += todo['estimated_minutes'] as int? ?? 0;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('モーニング・ブリーフィング'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: showPromptSettingsDialog,
            tooltip: '設定',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.list_alt), text: 'ミッション'),
            Tab(icon: Icon(Icons.history), text: '履歴'),
            Tab(icon: Icon(Icons.calendar_month), text: 'カレンダー'),
          ],
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
                color: Colors.indigo.shade50,
                child: ExpansionTile(
                  title: const Text(
                    '今日のミッション',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    _isHeaderExpanded ? 'タップして閉じる' : 'タップして開く',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  initiallyExpanded: _isHeaderExpanded,
                  onExpansionChanged: (bool expanded) {
                    setState(() {
                      _isHeaderExpanded = expanded;
                    });
                  },
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        children: [
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
                                    (_weatherData!['weathercode'] as num)
                                        .toInt(),
                                  ),
                                  color: Colors.orange,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${_weatherData!['temperature']}°C (Tokyo)',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 16),
                          // ★ START: AI Assistant Settings Display
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.1),
                                  spreadRadius: 1,
                                  blurRadius: 3,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'AIアシスタント設定',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit,
                                        size: 20,
                                        color: Colors.grey,
                                      ),
                                      onPressed: showPromptSettingsDialog,
                                      tooltip: '設定を開く',
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ],
                                ),
                                const Divider(height: 12),
                                Row(
                                  children: [
                                    Icon(
                                      _geminiApiKey != null &&
                                              _geminiApiKey!.isNotEmpty
                                          ? Icons.check_circle
                                          : Icons.warning_amber,
                                      color: _geminiApiKey != null &&
                                              _geminiApiKey!.isNotEmpty
                                          ? Colors.green
                                          : Colors.orange,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _geminiApiKey != null &&
                                                _geminiApiKey!.isNotEmpty
                                            ? 'APIキー設定済み'
                                            : 'APIキーが設定されていません',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: _geminiApiKey != null &&
                                                  _geminiApiKey!.isNotEmpty
                                              ? Colors.green
                                              : Colors.orange,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '使用モデル: $_selectedModel',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                const SizedBox(height: 4),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Text(
                                    '利用可能: ${_selectableModels.map((m) {
                                      final name = m['name'] as String;
                                      final methods =
                                          (m['methods'] as List? ?? [])
                                              .join(',');
                                      return '$name($methods)';
                                    }).join('; ')}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // ★ END: AI Assistant Settings Display
                          const SizedBox(height: 12),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                const Text(
                                  'フィルタ:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                FilterChip(
                                  label: const Text('すべて'),
                                  selected: _filterCategory == 'all',
                                  onSelected: (val) =>
                                      setState(() => _filterCategory = 'all'),
                                ),
                                ..._categoryLabels.entries.map((e) {
                                  return Padding(
                                    padding: const EdgeInsets.only(left: 8.0),
                                    child: FilterChip(
                                      avatar: Icon(
                                        _categoryIcons[e.key],
                                        size: 16,
                                      ),
                                      label: Text(e.value),
                                      selected: _filterCategory == e.key,
                                      onSelected: (val) => setState(
                                        () => _filterCategory = e.key,
                                      ),
                                    ),
                                  );
                                }),
                                const SizedBox(width: 16),
                                const Text(
                                  '並び替え:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  initialValue: _sortOrder,
                                  tooltip: '並び替え順を変更',
                                  icon: Icon(
                                    Icons.sort,
                                    color: _sortOrder != 'manual'
                                        ? Colors.orange
                                        : Colors.grey,
                                  ),
                                  onSelected: (val) =>
                                      setState(() => _sortOrder = val),
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'manual',
                                      child: Text('手動 (ドラッグ)'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'estimated_asc',
                                      child: Text('見積もり時間 (短い順)'),
                                    ),
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
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      '今日の進捗 (Pt)',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '${(progress * 100).toInt()}% ($completedPoints/$totalPoints pt)',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                LinearProgressIndicator(
                                  value: progress,
                                  backgroundColor: Colors.white,
                                  color: progress == 1.0
                                      ? Colors.orange
                                      : Colors.green,
                                  minHeight: 8,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                if (totalEstimatedMinutes > 0)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        const Icon(
                                          Icons.access_time,
                                          size: 14,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '残り見積もり: $totalEstimatedMinutes分',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
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
                        onSubmitted: (_) => addTodo(),
                      ),
                    ),
                    IconButton(
                      onPressed: () => selectDate(context),
                      icon: Icon(
                        Icons.calendar_today,
                        color:
                            _selectedDate != null ? Colors.orange : Colors.grey,
                      ),
                      tooltip: _selectedDate != null ? '期限を設定中' : '期限を設定',
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.repeat,
                        color: _selectedRecurrence != 'none'
                            ? Colors.orange
                            : Colors.grey,
                      ),
                      tooltip: '繰り返し設定',
                      onSelected: (value) {
                        setState(() {
                          _selectedRecurrence = value;
                        });
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'none',
                          child: Text('繰り返しなし'),
                        ),
                        const PopupMenuItem(value: 'daily', child: Text('毎日')),
                        const PopupMenuItem(value: 'weekly', child: Text('毎週')),
                        const PopupMenuItem(
                          value: 'monthly',
                          child: Text('毎月'),
                        ),
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
                      itemBuilder: (context) =>
                          _categoryLabels.entries.map((e) {
                        return PopupMenuItem(
                          value: e.key,
                          child: Row(
                            children: [
                              Icon(_categoryIcons[e.key], color: Colors.grey),
                              const SizedBox(width: 8),
                              Text(e.value),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<int>(
                      icon: Icon(
                        Icons.access_time,
                        color: _selectedDuration != null
                            ? Colors.orange
                            : Colors.grey,
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
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.signal_cellular_alt,
                        color: _difficultyColors[_selectedDifficulty],
                      ),
                      tooltip: '難易度',
                      onSelected: (value) {
                        setState(() {
                          _selectedDifficulty = value;
                        });
                      },
                      itemBuilder: (context) =>
                          _difficultyLabels.entries.map((e) {
                        return PopupMenuItem(
                          value: e.key,
                          child: Text(
                            e.value,
                            style: TextStyle(color: _difficultyColors[e.key]),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: addTodo,
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
                                    Icon(
                                      Icons.wb_sunny_outlined,
                                      size: 64,
                                      color: Colors.grey,
                                    ),
                                    SizedBox(height: 16),
                                    Text('タスクはありません'),
                                  ],
                                ),
                              )
                            : (_filterCategory != 'all' ||
                                    _sortOrder != 'manual')

                                // フィルタ適用中または手動ソート以外は並び替え無効 (ListViewを使用)

                                ? ListView.builder(
                                    itemCount: activeTodos.length,
                                    itemBuilder: (context, index) =>
                                        buildTodoItem(
                                      activeTodos[index],
                                      index,
                                      false,
                                    ),
                                  )
                                : ReorderableListView.builder(
                                    onReorder: onReorder,
                                    itemCount: activeTodos.length,
                                    itemBuilder: (context, index) =>
                                        buildTodoItem(
                                      activeTodos[index],
                                      index,
                                      true,
                                    ),
                                  ),

                    // --- Tab 2: History (Completed) ---

                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : historyTodos.isEmpty
                            ? const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.history,
                                      size: 64,
                                      color: Colors.grey,
                                    ),
                                    SizedBox(height: 16),
                                    Text('完了したタスクはありません'),
                                  ],
                                ),
                              )
                            : Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              onPressed: exportHistoryToCsv,
                                              icon: const Icon(Icons.download),
                                              label: const Text('CSV'),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: FilledButton.icon(
                                              onPressed: generateDailyReport,
                                              icon: const Icon(
                                                Icons.auto_awesome,
                                              ),
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

                                        final createdAtStr =
                                            todo['created_at'] as String?;

                                        final category =
                                            todo['category'] as String? ??
                                                'work';

                                        final actualMinutes =
                                            todo['actual_minutes'] as int?;

                                        final difficulty =
                                            todo['difficulty'] as String? ??
                                                'normal';

                                        String subtitleText = '';

                                        if (createdAtStr != null) {
                                          final createdAt =
                                              DateTime.parse(createdAtStr)
                                                  .toLocal();

                                          subtitleText =
                                              '作成: ${timeago.format(createdAt)}';
                                        }

                                        if (actualMinutes != null) {
                                          subtitleText +=
                                              ' (実績: $actualMinutes分)';
                                        }

                                        return ListTile(
                                          onTap: () => showTaskDetails(
                                            todo,
                                          ), // 履歴でも詳細表示

                                          leading: const Icon(
                                            Icons.check_circle,
                                            color: Colors.green,
                                          ),

                                          title: Text(
                                            task,
                                            style: const TextStyle(
                                              decoration:
                                                  TextDecoration.lineThrough,
                                              color: Colors.grey,
                                            ),
                                          ),

                                          subtitle: Row(
                                            children: [
                                              Icon(
                                                _categoryIcons[category],
                                                size: 12,
                                                color: Colors.grey,
                                              ),
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
                                                onPressed: () => toggleTodo(
                                                  id,
                                                  true,
                                                  task,
                                                  null,
                                                  difficulty,
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                ),
                                                onPressed: () => deleteTodo(id),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),

                    // --- Tab 3: Calendar View ---

                    _buildCalendarView(),
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
                Colors.purple,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarView() {
    return Column(
      children: [
        TableCalendar<Map<String, dynamic>>(
          locale: 'ja_JP',
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          calendarFormat: CalendarFormat.month,
          eventLoader: _getEventsForDay,
          startingDayOfWeek: StartingDayOfWeek.monday,
          calendarStyle: CalendarStyle(
            outsideDaysVisible: false,
            todayDecoration: BoxDecoration(
              color: Colors.orange.shade200,
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              shape: BoxShape.circle,
            ),
            markerDecoration: const BoxDecoration(
              color: Colors.indigo,
              shape: BoxShape.circle,
            ),
          ),
          headerStyle: const HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
          ),
          onDaySelected: (selectedDay, focusedDay) {
            if (!isSameDay(_selectedDay, selectedDay)) {
              setState(() {
                _selectedDay = selectedDay;

                _focusedDay = focusedDay;
              });

              _selectedEvents.value = _getEventsForDay(selectedDay);
            }
          },
          onPageChanged: (focusedDay) {
            _focusedDay = focusedDay;
          },
        ),
        const Divider(),
        Expanded(
          child: ValueListenableBuilder<List<Map<String, dynamic>>>(
            valueListenable: _selectedEvents,
            builder: (context, value, _) {
              if (value.isEmpty) {
                return const Center(
                  child: Text('この日に予定されているタスクはありません。'),
                );
              }

              return ListView.builder(
                itemCount: value.length,
                itemBuilder: (context, index) {
                  final todo = value[index];

                  final isCompleted = todo['is_completed'] as bool;

                  final category = todo['category'] as String? ?? 'work';

                  final difficulty = todo['difficulty'] as String? ?? 'normal';

                  final estimatedMinutes = todo['estimated_minutes'] as int?;

                  return Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 4.0,
                    ),
                    decoration: BoxDecoration(
                      color: isCompleted ? Colors.grey.shade100 : Colors.white,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: ListTile(
                      onTap: () => showTaskDetails(todo),
                      title: Text(
                        '${todo['task']}',
                        style: TextStyle(
                          decoration:
                              isCompleted ? TextDecoration.lineThrough : null,
                          color: isCompleted ? Colors.grey : Colors.black,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Row(
                          children: [
                            Icon(
                              _categoryIcons[category],
                              size: 14,
                              color: _categoryColors[category],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _categoryLabels[category] ?? '',
                              style: const TextStyle(fontSize: 12),
                            ),
                            const Text(
                              ' / ',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            Text(
                              _difficultyLabels[difficulty] ?? '',
                              style: TextStyle(
                                fontSize: 12,
                                color: _difficultyColors[difficulty],
                              ),
                            ),
                            if (estimatedMinutes != null) ...[
                              const Text(
                                ' / ',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const Icon(
                                Icons.access_time,
                                size: 14,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '$estimatedMinutes分',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ],
                        ),
                      ),
                      leading: Icon(
                        isCompleted
                            ? Icons.check_circle
                            : Icons.check_circle_outline,
                        color: isCompleted ? Colors.green : Colors.grey,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget buildTodoItem(
    Map<String, dynamic> todo,
    int index,
    bool isReorderable,
  ) {
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
    final difficulty = todo['difficulty'] as String? ?? 'normal';

    // ロック状態の判定
    final hasIncompleteImportantTasks = _todos.any(
      (t) => t['is_important'] == true && t['is_completed'] == false,
    );
    final isLocked =
        !isCompleted && !isImportant && hasIncompleteImportantTasks;

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

    // 繰り返しの日本語ラベル
    String? recurrenceLabel;
    if (recurrence == 'daily') recurrenceLabel = '毎日';
    if (recurrence == 'weekly') recurrenceLabel = '毎週';
    if (recurrence == 'monthly') recurrenceLabel = '毎月';

    // サブタイトル生成
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

    final points = _difficultyPoints[difficulty] ?? 10;
    subtitleText +=
        ' [${_difficultyLabels[difficulty] ?? difficulty} (${points}pt)]';

    if (isCompleted && actualMinutes != null) {
      subtitleText += ' ✅$actualMinutes分';
      if (estimatedMinutes != null) subtitleText += '/予$estimatedMinutes分';
    } else if (estimatedMinutes != null) {
      subtitleText += ' ⏱$estimatedMinutes分';
    }

    final content = ListTile(
      // 背景色設定（今日締め切りを強調）
      tileColor: !isCompleted && isDueToday ? Colors.orange.shade50 : null,
      shape: !isCompleted && isDueToday
          ? RoundedRectangleBorder(
              side: const BorderSide(color: Colors.orange, width: 1),
              borderRadius: BorderRadius.circular(8),
            )
          : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),

      onTap: isLocked
          ? () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('最重要タスク（★）が残っています。先に片付けましょう！'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          : () => editTodo(
                id,
                task,
                dueDate,
                recurrence,
                category,
                estimatedMinutes,
                difficulty,
              ),
      onLongPress: () => showTaskDetails(todo),
      leading: Checkbox(
        value: isCompleted,
        onChanged: isLocked
            ? (val) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('最重要タスク（★）が残っています。先に片付けましょう！'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            : (val) => toggleTodo(
                  id,
                  isCompleted,
                  task,
                  estimatedMinutes,
                  difficulty,
                ),
      ),
      title: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          Text(
            task,
            style: TextStyle(
              decoration: isCompleted ? TextDecoration.lineThrough : null,
              color: isCompleted
                  ? Colors.grey
                  : (isLocked
                      ? Colors.grey
                      : (isOverdue
                          ? Colors.red
                          : (isDueToday ? Colors.deepOrange : null))),
              fontWeight: (isOverdue || isDueToday) && !isLocked
                  ? FontWeight.bold
                  : null,
            ),
          ),
          // ★ 追加: 今日中バッジ
          if (!isCompleted && isDueToday)
            const Chip(
              label: Text(
                '今日中',
                style: TextStyle(color: Colors.white, fontSize: 10),
              ),
              backgroundColor: Colors.orange,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              side: BorderSide.none,
            ),
          // ★ 追加: 繰り返しバッジ
          if (recurrenceLabel != null)
            Chip(
              avatar: const Icon(Icons.repeat, size: 12, color: Colors.white),
              label: Text(
                recurrenceLabel,
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
              backgroundColor: Colors.purple.shade300,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              side: BorderSide.none,
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(_categoryIcons[category], size: 12, color: Colors.grey),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  subtitleText,
                  style: TextStyle(
                    color: isCompleted
                        ? Colors.grey
                        : (isLocked
                            ? Colors.grey
                            : (isOverdue
                                ? Colors.red
                                : (isDueToday
                                    ? Colors.deepOrange
                                    : (difficulty == 'hard'
                                        ? Colors.red.shade300
                                        : Colors.grey)))),
                    fontWeight: difficulty == 'hard' && !isLocked
                        ? FontWeight.w500
                        : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (subTotal > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: subTotal > 0 ? subDone / subTotal : 0,
                      backgroundColor: Colors.grey.shade200,
                      color: Colors.blueAccent,
                      minHeight: 4,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$subDone/$subTotal',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              isImportant ? Icons.star : Icons.star_border,
              color: isImportant ? Colors.orange : Colors.grey,
            ),
            onPressed: () => toggleImportant(id, isImportant),
          ),
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
      onDismissed: (_) => deleteTodo(id),
      child: isLocked ? Opacity(opacity: 0.5, child: content) : content,
    );
  }
}
