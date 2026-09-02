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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/gamification_service.dart';
import '../services/completion_goal_service.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:my_web_app/utils/tab_route_url_sync.dart';

class MorningBriefingPage extends StatefulWidget {
  const MorningBriefingPage({super.key});

  @override
  State<MorningBriefingPage> createState() => _MorningBriefingPageState();
}

class _MorningBriefingPageState extends State<MorningBriefingPage>
    with SingleTickerProviderStateMixin, TabRouteUrlSync {
  // タブ: タスク / カレンダー / 履歴 / ストック
  @override
  List<String> get tabUrlSlugs => const <String>[
        'tasks',
        'calendar',
        'history',
        'stock',
      ];

  @override
  TabController get tabUrlController => _tabController;

  final TextEditingController _todoController = TextEditingController();
  List<Map<String, dynamic>> _todos = [];
  List<Map<String, dynamic>> _subtasks = [];
  List<Map<String, dynamic>> _somedayTasks = [];
  StreamSubscription? _todosSubscription;
  StreamSubscription? _subtasksSubscription;
  StreamSubscription? _somedayTasksSubscription;
  Timer? _reconnectTimer;
  late TabController _tabController;
  bool _isLoading = true;
  DateTime? _selectedDate;
  // for Calendar View
  late final ValueNotifier<List<Map<String, dynamic>>> _selectedEvents;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.twoWeeks;

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
  static const String _defaultGeminiModel = 'gemini-2.5-flash';
  static const Set<String> _legacyGeminiModels = {
    'gemini-pro',
    'gemini-1.5-flash',
    'gemini-1.5-pro',
    'gemini-2.0-flash',
  };

  String _selectedModel = _defaultGeminiModel; // 日報生成用モデル
  bool _addToStock = false; // ★ Add this line
  String _customPromptInstructions = _defaultPromptInstructions;
  static const String _defaultPromptInstructions =
      'あなたは優秀なビジネスパーソンです。以下の本日のタスク実績データを元に、簡潔で分かりやすい日報を作成してください。\n'
      '構成は「本日の業務内容」「成果・振り返り」「明日の予定・課題」としてください。\n'
      '特に「振り返り」の内容を重視し、ポジティブかつ建設的なトーンでまとめてください。';

  List<Map<String, dynamic>> _selectableModels = [
    {
      'name': 'gemini-2.5-flash',
      'methods': ['generateContent'],
    },
    {
      'name': 'gemini-2.5-pro',
      'methods': ['generateContent'],
    },
  ];

  String _normalizeSelectedGeminiModel(String? model) {
    final normalized = model?.trim();
    if (normalized == null || normalized.isEmpty) {
      return _defaultGeminiModel;
    }
    if (_legacyGeminiModels.contains(normalized)) {
      return _defaultGeminiModel;
    }
    return normalized;
  }

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
    'work': const Color(0xFF6366F1),
    'private': const Color(0xFF0D9488),
    'health': const Color(0xFFB91C1C),
    'study': const Color(0xFFFF6B35),
    'routine': const Color(0xFF0D9488), // ★ 追加
    'other': const Color(0xFF9CA3AF),
  };

  final Map<String, String> _difficultyLabels = {
    'easy': '簡単',
    'normal': '普通',
    'hard': '難しい',
  };

  final Map<String, Color> _difficultyColors = {
    'easy': const Color(0xFF0D9488),
    'normal': const Color(0xFF6366F1),
    'hard': const Color(0xFFB91C1C),
  };

  final Map<String, int> _difficultyPoints = {
    'easy': 5,
    'normal': 10,
    'hard': 20,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
      DateTime? taskDate;
      DateTime? dueDate;

      final taskDateRaw = todo['task_date']?.toString();
      if (taskDateRaw != null && taskDateRaw.isNotEmpty) {
        taskDate = DateTime.tryParse(taskDateRaw);
      }

      final dueDateRaw = todo['due_date']?.toString();
      if (dueDateRaw != null && dueDateRaw.isNotEmpty) {
        try {
          dueDate = DateTime.parse(dueDateRaw).toLocal();
        } catch (e) {
          debugPrint('Invalid due_date format: $dueDateRaw');
        }
      }

      final matchesTaskDate = taskDate != null && isSameDay(taskDate, day);
      final matchesDueDate = dueDate != null && isSameDay(dueDate, day);
      return matchesTaskDate || matchesDueDate;
    }).toList();
  }

  String _dateOnly(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d'; // YYYY-MM-DD
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

    _somedayTasksSubscription?.cancel();
    _somedayTasksSubscription = Supabase.instance.client
        .from('someday_tasks')
        .stream(primaryKey: ['id']).listen(
      (data) {
        if (mounted) {
          setState(() {
            _somedayTasks = data;
          });
        }
      },
      onError: (error) {
        debugPrint('Someday Tasks Stream error: $error');
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
          backgroundColor: Color(0xFFFF6B35),
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
    _somedayTasksSubscription?.cancel();
    _todoController.dispose();
    _selectedEvents.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // 1) Prompt / Model は今まで通り SharedPreferences
    final savedModel =
        _normalizeSelectedGeminiModel(prefs.getString('gemini_model'));

    final prompt =
        prefs.getString('daily_report_prompt') ?? _defaultPromptInstructions;

    if (!mounted) return;
    setState(() {
      _customPromptInstructions = prompt;
      _selectedModel = savedModel;
    });
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
    final todayStr = _dateOnly(DateTime.now());

    try {
      final response = await Supabase.instance.client
          .from('daily_todos')
          .select()
          .eq('is_completed', false)
          .lt('task_date', todayStr); // ✅ task_dateが今日より前

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
    final todayStr = _dateOnly(DateTime.now());

    try {
      await Supabase.instance.client
          .from('daily_todos')
          .update({'task_date': todayStr}) // ✅ created_atは触らない
          .filter('id', 'in', ids);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${tasks.length}件のタスクを今日のタスクに移動しました'),
            backgroundColor: const Color(0xFF0D9488),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラーが発生しました: $e'),
            backgroundColor: const Color(0xFFB91C1C),
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
        'recurrence': recurrence,
        'category': category,
        'estimated_minutes': estimatedMinutes,
        'difficulty': difficulty,
        'order_index': maxOrder + 1,
        'task_date': _dateOnly(nextDate), // ✅
      });
    } catch (e) {
      debugPrint('Error creating recurring task: $e');
    }
  }

  Future<void> addTodo() async {
    final text = _todoController.text.trim();
    if (text.isEmpty) return;

    final bool isStocking = _addToStock;
    final tableName = isStocking ? 'someday_tasks' : 'daily_todos';

    final Map<String, dynamic> data = {
      'task': text,
      'is_completed': false,
      'is_important': false,
      'category': _selectedCategory,
      'estimated_minutes': _selectedDuration,
      'difficulty': _selectedDifficulty,
    };

    if (!isStocking) {
      int maxOrder = 0;
      if (_todos.isNotEmpty) {
        for (var t in _todos) {
          final o = t['order_index'] as int? ?? 0;
          if (o > maxOrder) maxOrder = o;
        }
      }
      data['order_index'] = maxOrder + 1;

      data['due_date'] = _selectedDate?.toIso8601String();
      data['recurrence'] = _selectedRecurrence;

      // ✅ 追加：どの日のタスクか（未指定なら今日）
      final baseDay = _selectedDate ?? DateTime.now();
      data['task_date'] = _dateOnly(baseDay);
    }

    try {
      await Supabase.instance.client.from(tableName).insert(data);
      _todoController.clear();
      if (!mounted) return;
      setState(() {
        _selectedDate = null;
        _selectedRecurrence = 'none';
        _selectedCategory = 'work';
        _selectedDuration = null;
        _selectedDifficulty = 'normal';
        _addToStock = false; // Reset the switch
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isStocking ? 'タスクをストックしました。' : 'タスクを追加しました。'),
            backgroundColor: const Color(0xFF0D9488),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラーが発生しました: $e'),
            backgroundColor: const Color(0xFFB91C1C),
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
    final goalBefore = CompletionGoalService.buildSnapshot(todos: _todos);
    final completedAtIso =
        !currentValue ? DateTime.now().toIso8601String() : null;

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
                  backgroundColor: Color(0xFFFF6B35),
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
        'completed_at': completedAtIso,
      };

      if (!currentValue) {
        updates['actual_minutes'] = actualMinutes;
        updates['reflection'] = reflection;
      } else {
        updates['actual_minutes'] = null; // 未完了に戻す場合は実績時間をクリア
        updates['reflection'] = null;
      }

      try {
        await Supabase.instance.client
            .from('daily_todos')
            .update(updates)
            .eq('id', id);
      } catch (e) {
        if (!updates.containsKey('completed_at')) {
          rethrow;
        }
        final fallbackUpdates = Map<String, dynamic>.from(updates)
          ..remove('completed_at');
        await Supabase.instance.client
            .from('daily_todos')
            .update(fallbackUpdates)
            .eq('id', id);
      }

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
            backgroundColor: const Color(0xFF0D9488),
            duration: const Duration(seconds: 1),
          ),
        );
        final simulatedTodos = _todos
            .map(
              (todo) => todo['id'] == id
                  ? {
                      ...todo,
                      'is_completed': true,
                      'completed_at': completedAtIso,
                    }
                  : todo,
            )
            .toList();
        final goalAfter = CompletionGoalService.buildSnapshot(
          todos: simulatedTodos,
        );
        if (!goalBefore.isAchieved && goalAfter.isAchieved) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '前日超え達成: 昨日 ${goalAfter.yesterdayCompletedCount}件 → 今日 ${goalAfter.todayCompletedCount}件',
              ),
              backgroundColor: const Color(0xFF6366F1),
              duration: const Duration(seconds: 2),
            ),
          );
        }
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

  Future<bool> _deleteTodoWithFeedback(
    String id, {
    required String taskTitle,
  }) async {
    try {
      await Supabase.instance.client
          .from('daily_subtasks')
          .delete()
          .eq('todo_id', id)
          .select();
      await Supabase.instance.client
          .from('daily_todos')
          .delete()
          .eq('id', id)
          .select();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('「$taskTitle」を削除しました。'),
            backgroundColor: const Color(0xFF0D9488),
          ),
        );
      }
      return true;
    } catch (e) {
      debugPrint('Error deleting todo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('タスクの削除に失敗しました: $e'),
            backgroundColor: const Color(0xFFB91C1C),
          ),
        );
      }
      return false;
    }
  }

  Future<bool> _confirmDeleteTodo(Map<String, dynamic> todo) async {
    final id = todo['id']?.toString();
    if (id == null || id.isEmpty) {
      return false;
    }

    final taskTitle = (todo['task'] as String? ?? 'このタスク').trim();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('タスクを削除'),
        content: Text('「$taskTitle」を削除しますか？\nサブタスクもまとめて削除されます。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB91C1C),
            ),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (result != true) {
      return false;
    }

    return _deleteTodoWithFeedback(id, taskTitle: taskTitle);
  }

  bool _isMissingDailyTodoDetailsColumn(Object error) {
    return error is PostgrestException &&
        error.code == 'PGRST204' &&
        error.message.contains("'details' column") &&
        error.message.contains("'daily_todos'");
  }

  Future<bool> _updateDailyTodoWithDetailsFallback(
    String id,
    Map<String, dynamic> values,
  ) async {
    try {
      await Supabase.instance.client.from('daily_todos').update(values).eq(
            'id',
            id,
          );
      return false;
    } on PostgrestException catch (e) {
      if (!values.containsKey('details') ||
          !_isMissingDailyTodoDetailsColumn(e)) {
        rethrow;
      }

      final fallbackValues = Map<String, dynamic>.from(values)
        ..remove('details');
      await Supabase.instance.client
          .from('daily_todos')
          .update(fallbackValues)
          .eq('id', id);
      return true;
    }
  }

  Future<bool> _insertDailyTodoWithDetailsFallback(
    Map<String, dynamic> values,
  ) async {
    try {
      await Supabase.instance.client.from('daily_todos').insert(values);
      return false;
    } on PostgrestException catch (e) {
      if (!values.containsKey('details') ||
          !_isMissingDailyTodoDetailsColumn(e)) {
        rethrow;
      }

      final fallbackValues = Map<String, dynamic>.from(values)
        ..remove('details');
      await Supabase.instance.client.from('daily_todos').insert(fallbackValues);
      return true;
    }
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
    await Supabase.instance.client
        .from('daily_subtasks')
        .delete()
        .eq('id', id)
        .select();
  }

  Future<void> editTodo(
    String id,
    String currentTask,
    DateTime? currentDueDate,
    String? currentRecurrence,
    String? currentCategory,
    int? currentDuration,
    String? currentDifficulty,
    String? currentDetails, // <-- Add currentDetails
  ) async {
    final editController = TextEditingController(text: currentTask);
    final editDetailsController = TextEditingController(
      text: currentDetails,
    ); // <-- Add controller for details
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
            content: SingleChildScrollView(
              // <-- Wrap with SingleChildScrollView
              child: Column(
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
                  // ★★★ NEW FIELD FOR DETAILS ★★★
                  TextField(
                    controller: editDetailsController,
                    decoration: const InputDecoration(
                      labelText: '詳細・補足情報',
                      hintText: 'タスクに関するメモやリンクなどを自由入力...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 4, // Allow multi-line input
                  ),
                  // ★★★ END OF NEW FIELD ★★★
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
                              color: const Color(0xFF9CA3AF),
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
                          style: TextStyle(
                            color: _difficultyColors[e.key],
                            height: 1.5,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => editDifficulty = val!),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton.icon(
                onPressed: () async {
                  final deleted = await _confirmDeleteTodo(<String, dynamic>{
                    'id': id,
                    'task': editController.text.trim().isNotEmpty
                        ? editController.text.trim()
                        : currentTask,
                  });
                  if (deleted && context.mounted) {
                    Navigator.pop(context);
                  }
                },
                icon: const Icon(
                  Icons.delete_outline,
                  color: Color(0xFFB91C1C),
                ),
                label: const Text(
                  '削除',
                  style: TextStyle(
                    color: Color(0xFFB91C1C),
                    height: 1.5,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                onPressed: () async {
                  final newTask = editController.text.trim();
                  if (newTask.isNotEmpty) {
                    try {
                      final detailsDropped =
                          await _updateDailyTodoWithDetailsFallback(id, {
                        'task': newTask,
                        'details': editDetailsController.text
                            .trim(), // <-- Save details
                        'due_date': editDate?.toIso8601String(),
                        'recurrence': editRecurrence,
                        'category': editCategory,
                        'estimated_minutes': editDuration,
                        'difficulty': editDifficulty,
                      });
                      if (context.mounted) Navigator.pop(context);
                      if (detailsDropped && mounted) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'daily_todos.details 列が未反映のため、詳細メモはまだ保存されていません。Supabase マイグレーションを適用してください。',
                            ),
                            backgroundColor: Color(0xFFFF6B35),
                          ),
                        );
                      }
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
    final details = (todo['details'] as String?)?.trim();
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
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      height: 1.5,
                    ),
                  ),
                  if (details != null && details.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text(
                      '詳細:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(details),
                  ],
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
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        height: 1.5,
                      ),
                    ),
                    Text(reflection),
                  ],
                  Text('作成: ${formattedDate(createdAtStr)}'),
                  const Divider(height: 24),
                  const Text(
                    'サブタスク',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      height: 1.5,
                    ),
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
                        icon: const Icon(
                          Icons.add_circle,
                          color: Color(0xFF6366F1),
                        ),
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
                          style: TextStyle(
                            color: Color(0xFF9CA3AF),
                            height: 1.5,
                          ),
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
                                  color: stCompleted
                                      ? const Color(0xFF9CA3AF)
                                      : null,
                                  height: 1.5,
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
    if (_sortOrder != 'manual') return;

    // ✅ ① 変更前の order_index をスナップショット
    final oldOrderById = <String, int>{
      for (final t in _todos)
        (t['id'] as String): ((t['order_index'] as num?)?.toInt() ?? 0),
    };

    // UIに表示されている activeTodos を再現（既存ロジック踏襲）
    final activeTodos =
        _todos.where((todo) => todo['is_completed'] == false).toList();

    activeTodos.sort((a, b) {
      final aImp = a['is_important'] as bool? ?? false;
      final bImp = b['is_important'] as bool? ?? false;
      if (aImp != bImp) return aImp ? -1 : 1;

      final aOrder = a['order_index'] as num? ?? 0;
      final bOrder = b['order_index'] as num? ?? 0;
      return aOrder.compareTo(bOrder);
    });

    setState(() {
      if (oldIndex < newIndex) newIndex -= 1;

      final movedItem = activeTodos.removeAt(oldIndex);
      activeTodos.insert(newIndex, movedItem);

      // ✅ ② active → completed の順に連番を振り直す（あなたの方針を維持）
      final completedTodos =
          _todos.where((t) => t['is_completed'] == true).toList();

      int newOrderIndex = 0;
      for (final todo in activeTodos) {
        final masterTodo = _todos.firstWhere((t) => t['id'] == todo['id']);
        masterTodo['order_index'] = newOrderIndex++;
      }
      for (final todo in completedTodos) {
        final masterTodo = _todos.firstWhere((t) => t['id'] == todo['id']);
        masterTodo['order_index'] = newOrderIndex++;
      }
    });

    // ✅ ③ DB保存はUI更新後に“一括”で（失敗率↓ / 体感↑）
    // unawaited が使える環境ならこれでOK（dart:async）
    unawaited(updateOrderInDbBatch(oldOrderById));
  }

  Future<void> updateOrderInDbBatch(Map<String, int> oldOrderById) async {
    try {
      // 変更があった行だけまとめる（id, order_index）
      final updates = <Map<String, dynamic>>[];

      for (final t in _todos) {
        final id = t['id'] as String;
        final newOrder = (t['order_index'] as num? ?? 0).toInt();
        final oldOrder = oldOrderById[id];

        if (oldOrder == null || oldOrder != newOrder) {
          updates.add({
            'id': id,
            'order_index': newOrder,
          });
        }
      }

      if (updates.isEmpty) return;

      // ✅ 1回で更新（onConflict: 'id' が重要）
      await Supabase.instance.client
          .from('daily_todos')
          .upsert(updates, onConflict: 'id');
    } catch (e) {
      debugPrint('updateOrderInDbBatch error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('並び替え保存に失敗しました: $e'),
          backgroundColor: const Color(0xFFB91C1C),
        ),
      );
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
    final todayStr = _dateOnly(DateTime.now());

    final historyTodos = _todos.where((t) {
      if (t['is_completed'] != true) {
        return false;
      }
      final completedAt = _parseLocalDateTime(t['completed_at'] as String?);
      if (completedAt != null) {
        return _dateOnly(completedAt) == todayStr;
      }
      final td = t['task_date'] as String?;
      return td == todayStr;
    }).toList();

    if (historyTodos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('日報を生成するための完了タスクがありません')),
      );
      return;
    }

    if (Supabase.instance.client.auth.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);

    try {
      final prompt = buildDailyReportPrompt(historyTodos);
      final res = await Supabase.instance.client.functions.invoke(
        'ai-assistant',
        body: {
          'action': 'generate',
          'model': _selectedModel,
          'content': prompt,
          'useMagi': false,
        },
      );
      final data = res.data;
      final responseText =
          (data is Map<String, dynamic> && data['success'] == true)
              ? data['result'] as String?
              : null;

      if (mounted && responseText != null) {
        showReportDialog(responseText, historyTodos);
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
                          'モデル「$_selectedModel」は利用制限に達したか、利用できません。',
                        ),
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
              backgroundColor: const Color(0xFFB91C1C),
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<List<Map<String, dynamic>>> fetchGeminiModels() async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'ai-hub',
        body: const {'action': 'provider.models'},
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      return (data['models'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map>()
          .map((model) => Map<String, dynamic>.from(model))
          .where((model) => model['provider'] == 'google')
          .where((model) {
            final methods = model['supportedGenerationMethods'];
            return methods is List && methods.contains('generateContent');
          })
          .map<Map<String, dynamic>>((model) => {
                'name': model['name']?.toString() ?? '',
                'methods': List<String>.from(
                  model['supportedGenerationMethods'] as List,
                ),
              })
          .where((model) => (model['name'] as String).isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('Failed to fetch models: $e');
    }
    return [];
  }

  List<String> _modelMethodsFromMap(Map<String, dynamic> modelMap) {
    final rawMethods = modelMap['methods'];
    if (rawMethods is! List) {
      return const <String>[];
    }
    return rawMethods
        .map((method) => method.toString().trim())
        .where((method) => method.isNotEmpty)
        .toList();
  }

  Widget _buildModelMethodChip(String method) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border:
            Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.12)),
      ),
      child: Text(
        method,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF4338CA),
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildModelAvailabilityPanel({
    required List<Map<String, dynamic>> models,
    required String selectedModel,
  }) {
    final selected = models.cast<Map<String, dynamic>>().firstWhere(
          (model) => (model['name']?.toString() ?? '') == selectedModel,
          orElse: () => <String, dynamic>{
            'name': selectedModel,
            'methods': const <String>[],
          },
        );
    final selectedMethods = _modelMethodsFromMap(selected);

    return Container(
      padding: const EdgeInsets.all(12),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '現在のモデル',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            selectedModel,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          if (selectedMethods.isEmpty)
            Text(
              '利用可能メソッド: 未取得',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final method in selectedMethods)
                  _buildModelMethodChip(method),
              ],
            ),
          const Divider(height: 18),
          Text(
            '利用可能なモデル一覧',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          for (final model in models)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: ((model['name']?.toString() ?? '') == selectedModel)
                        ? const Color(0xFF6366F1).withValues(alpha: 0.25)
                        : Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      model['name']?.toString() ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Builder(
                      builder: (context) {
                        final methods = _modelMethodsFromMap(model);
                        if (methods.isEmpty) {
                          return Text(
                            '利用可能メソッド: 未取得',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              height: 1.5,
                            ),
                          );
                        }
                        return Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final method in methods)
                              _buildModelMethodChip(method),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> showPromptSettingsDialog() async {
    final controller = TextEditingController(text: _customPromptInstructions);
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
                  const Text(
                    'AI認証情報はサーバーで管理されています。モデルと日報プロンプトを設定できます。',
                  ),
                  const SizedBox(height: 16),
                  if (isFetchingModels)
                    const LinearProgressIndicator()
                  else
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          setDialogState(() => isFetchingModels = true);
                          final models = await fetchGeminiModels();
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
                  _buildModelAvailabilityPanel(
                    models: currentSelectableModels,
                    selectedModel: tempSelectedModel,
                  ),
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
                  setDialogState(
                    () => tempSelectedModel = _defaultGeminiModel,
                  );
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
                  if (mounted) {
                    setState(() {
                      _customPromptInstructions = controller.text;
                      _selectedModel = tempSelectedModel;
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
                  labelColor: Color(0xFF6366F1),
                  unselectedLabelColor: Color(0xFF9CA3AF),
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
                          color:
                              Theme.of(context).colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        child: Markdown(
                          data: report,
                          selectable: true, // Allow text selection
                          styleSheet: MarkdownStyleSheet(
                            h1: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6366F1),
                              height: 1.5,
                            ),
                            h2: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6366F1),
                              height: 1.5,
                            ),
                            h3: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              height: 1.5,
                            ),
                            p: const TextStyle(
                              fontSize: 14,
                              height: 1.5,
                            ),
                            listBullet: const TextStyle(
                              fontSize: 16,
                              height: 1.5,
                            ),
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
                const Color(0xFF0D9488),
              ),
              buildStatCard(
                '合計時間',
                '$totalMinutes分',
                Icons.timer,
                const Color(0xFF6366F1),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'カテゴリ別内訳',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: categoryCounts.entries.map((e) {
                  final color =
                      _categoryColors[e.key] ?? const Color(0xFF9CA3AF);
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
                      color: Color(0xFFE5E7EB),
                      height: 1.5,
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
                    color: _categoryColors[key] ?? const Color(0xFF9CA3AF),
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
            style: TextStyle(
              fontWeight: FontWeight.bold,
              height: 1.5,
            ),
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
                          color: Color(0xFF000000),
                          fontWeight: FontWeight.bold,
                          height: 1.5,
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
                          color: Color(0xFF9CA3AF),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          height: 1.5,
                        );
                        String text = '';
                        if (value.toInt() == 0) text = '見積もり';
                        if (value.toInt() == 1) text = '実績';
                        return SideTitleWidget(
                          meta: meta,
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
                  makeBarGroup(
                    0,
                    totalEstimated.toDouble(),
                    const Color(0xFFFF6B35),
                  ),
                  makeBarGroup(
                    1,
                    totalMinutes.toDouble(),
                    const Color(0xFF6366F1),
                  ),
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
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF9CA3AF),
                height: 1.5,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBeatYesterdayGoalCard(
    BuildContext context,
    DailyCompletionGoalSnapshot snapshot,
  ) {
    final achieved = snapshot.isAchieved;
    final theme = Theme.of(context);
    final accentColor =
        achieved ? const Color(0xFF0D9488) : const Color(0xFFFF6B35);
    final headline = achieved ? '前日超えを達成しました' : '今日は昨日より1件多く完了する';
    final detail = achieved
        ? '昨日 ${snapshot.yesterdayCompletedCount}件 → 今日 ${snapshot.todayCompletedCount}件'
        : '昨日 ${snapshot.yesterdayCompletedCount}件 / 今日 ${snapshot.todayCompletedCount}件 / 目標 ${snapshot.targetCount}件';
    final helper = achieved
        ? 'このまま上振れを狙えます。次の1件を短時間で片付ける。'
        : 'あと ${snapshot.remainingCount}件で前日超えです。短い未完了タスクから先に片付けます。';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                achieved ? Icons.trending_up : Icons.flag,
                color: accentColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '前日超えチャレンジ',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: accentColor,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  achieved ? '達成' : '進行中',
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            headline,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: snapshot.progress,
            minHeight: 8,
            borderRadius: BorderRadius.circular(999),
            backgroundColor:
                Theme.of(context).colorScheme.surfaceContainerHighest,
            color: accentColor,
          ),
          const SizedBox(height: 8),
          Text(
            helper,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
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
    final completionGoalSnapshot = CompletionGoalService.buildSnapshot(
      todos: _todos,
    );
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
            Tab(icon: Icon(Icons.list_alt), text: 'タスク'),
            Tab(icon: Icon(Icons.calendar_today), text: 'カレンダー'),
            Tab(icon: Icon(Icons.history), text: '履歴'),
            Tab(icon: Icon(Icons.inventory_2), text: 'ストック'),
          ],
          labelColor: const Color(0xFFE5E7EB),
          unselectedLabelColor: const Color(0xB3E5E7EB),
          indicatorColor: const Color(0xFFFF6B35),
        ),
        backgroundColor: const Color(0xFF1E1B4B),
        foregroundColor: const Color(0xFFE5E7EB),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // ヘッダーメッセージ
              Container(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1A1A2E)
                    : const Color(0xFFEEF2FF),
                child: ExpansionTile(
                  title: const Text(
                    '今日のミッション',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      height: 1.5,
                    ),
                  ),
                  subtitle: Text(
                    _isHeaderExpanded ? 'タップして閉じる' : 'タップして開く',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
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
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              height: 1.5,
                            ),
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
                                  color: const Color(0xFFFF6B35),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${_weatherData!['temperature']}°C (Tokyo)',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    height: 1.5,
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
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerLow,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF9CA3AF)
                                      .withValues(alpha: 0.1),
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
                                        height: 1.5,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit,
                                        size: 20,
                                        color: Color(0xFF9CA3AF),
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
                                    const Icon(
                                      Icons.cloud_done,
                                      color: Color(0xFF0D9488),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        'AI認証情報はサーバーで管理',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0D9488),
                                          height: 1.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '使用モデル: $_selectedModel',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    height: 1.5,
                                  ),
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
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                      height: 1.5,
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
                                    color: Color(0xFF9CA3AF),
                                    height: 1.5,
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
                                    color: Color(0xFF9CA3AF),
                                    height: 1.5,
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  initialValue: _sortOrder,
                                  tooltip: '並び替え順を変更',
                                  icon: Icon(
                                    Icons.sort,
                                    color: _sortOrder != 'manual'
                                        ? const Color(0xFFFF6B35)
                                        : const Color(0xFF9CA3AF),
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
                                        height: 1.5,
                                      ),
                                    ),
                                    Text(
                                      '${(progress * 100).toInt()}% ($completedPoints/$totalPoints pt)',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                LinearProgressIndicator(
                                  value: progress,
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                  color: progress == 1.0
                                      ? const Color(0xFFFF6B35)
                                      : const Color(0xFF0D9488),
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
                                          color: Color(0xFF9CA3AF),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '残り見積もり: $totalEstimatedMinutes分',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF9CA3AF),
                                            height: 1.5,
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
                    const SizedBox(height: 12),
                    _buildBeatYesterdayGoalCard(
                      context,
                      completionGoalSnapshot,
                    ),
                  ],
                ),
              ),

              // 入力エリア
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: SwitchListTile(
                  title: const Text('タスクをストックする（いつかやる）'),
                  value: _addToStock,
                  onChanged: (bool value) {
                    setState(() {
                      _addToStock = value;
                    });
                  },
                  secondary: const Icon(Icons.inventory_2_outlined),
                  dense: true,
                  activeThumbColor: const Color(0xFFFF6B35),
                  tileColor: _addToStock ? const Color(0xFFFFF7ED) : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: _addToStock
                          ? const Color(0xFFFDBA74)
                          : Colors.transparent,
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isCompact = constraints.maxWidth < 520;
                    if (isCompact) {
                      return _buildCompactTaskComposer(context);
                    }
                    return Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _todoController,
                            decoration: const InputDecoration(
                              hintText: 'タスクを追加...',
                              border: OutlineInputBorder(),
                              contentPadding:
                                  EdgeInsets.symmetric(horizontal: 16),
                            ),
                            onSubmitted: (_) => addTodo(),
                          ),
                        ),
                        IconButton(
                          onPressed: () => selectDate(context),
                          icon: Icon(
                            Icons.calendar_today,
                            color: _selectedDate != null
                                ? const Color(0xFFFF6B35)
                                : const Color(0xFF9CA3AF),
                          ),
                          tooltip: _selectedDate != null ? '期限を設定中' : '期限を設定',
                        ),
                        const SizedBox(width: 8),
                        PopupMenuButton<String>(
                          icon: Icon(
                            Icons.repeat,
                            color: _selectedRecurrence != 'none'
                                ? const Color(0xFFFF6B35)
                                : const Color(0xFF9CA3AF),
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
                            const PopupMenuItem(
                              value: 'daily',
                              child: Text('毎日'),
                            ),
                            const PopupMenuItem(
                              value: 'weekly',
                              child: Text('毎週'),
                            ),
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
                            color: const Color(0xFF9CA3AF),
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
                                  Icon(
                                    _categoryIcons[e.key],
                                    color: const Color(0xFF9CA3AF),
                                  ),
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
                                ? const Color(0xFFFF6B35)
                                : const Color(0xFF9CA3AF),
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
                            const PopupMenuItem(
                              value: 90,
                              child: Text('1.5時間'),
                            ),
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
                                style: TextStyle(
                                  color: _difficultyColors[e.key],
                                  height: 1.5,
                                ),
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
                    );
                  },
                ),
              ),

              // リストエリア

              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // --- Tab 1: Active Tasks (タスク) ---
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
                                      color: Color(0xFF9CA3AF),
                                    ),
                                    SizedBox(height: 16),
                                    Text('今日のタスクはありません'),
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
                                // 手動ソート用のReorderableListView
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

                    // --- Tab 2: Calendar View (カレンダー) ---
                    _buildAdaptiveCalendarView(),

                    // --- Tab 3: History (履歴) ---
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
                                      color: Color(0xFF9CA3AF),
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
                                            color: Color(0xFF0D9488),
                                          ),
                                          title: Text(
                                            task,
                                            style: const TextStyle(
                                              decoration:
                                                  TextDecoration.lineThrough,
                                              color: Color(0xFF9CA3AF),
                                              height: 1.5,
                                            ),
                                          ),
                                          subtitle: Row(
                                            children: [
                                              Icon(
                                                _categoryIcons[category],
                                                size: 12,
                                                color: const Color(0xFF9CA3AF),
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
                                                onPressed: () =>
                                                    _confirmDeleteTodo(
                                                  todo,
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

                    // --- Tab 4: Someday/Stock (ストック) ---
                    _buildSomedayTaskView(),
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
                Color(0xFF0D9488),
                Color(0xFF6366F1),
                Color(0xFFEC4899),
                Color(0xFFFF6B35),
                Color(0xFF6366F1),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactTaskComposer(BuildContext context) {
    final hasSelectionSummary = _selectedDate != null ||
        _selectedRecurrence != 'none' ||
        _selectedDuration != null ||
        _selectedDifficulty != 'normal';

    return Column(
      key: const Key('morning_briefing_task_composer_compact'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                key: const Key('morning_briefing_task_input'),
                controller: _todoController,
                minLines: 1,
                maxLines: 2,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  hintText: 'タスクを追加...',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                onSubmitted: (_) => addTodo(),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 56,
              width: 56,
              child: IconButton.filled(
                key: const Key('morning_briefing_add_task_button'),
                onPressed: addTodo,
                icon: const Icon(Icons.add),
                tooltip: '追加',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          key: const Key('morning_briefing_task_controls'),
          spacing: 8,
          runSpacing: 8,
          children: [
            IconButton(
              onPressed: () => selectDate(context),
              icon: Icon(
                Icons.calendar_today,
                color: _selectedDate != null
                    ? const Color(0xFFFF6B35)
                    : const Color(0xFF9CA3AF),
              ),
              tooltip: _selectedDate != null ? '日付を変更' : '日付を設定',
            ),
            PopupMenuButton<String>(
              icon: Icon(
                Icons.repeat,
                color: _selectedRecurrence != 'none'
                    ? const Color(0xFFFF6B35)
                    : const Color(0xFF9CA3AF),
              ),
              tooltip: '繰り返し設定',
              onSelected: (value) {
                setState(() {
                  _selectedRecurrence = value;
                });
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'none', child: Text('繰り返しなし')),
                PopupMenuItem(value: 'daily', child: Text('毎日')),
                PopupMenuItem(value: 'weekly', child: Text('毎週')),
                PopupMenuItem(value: 'monthly', child: Text('毎月')),
              ],
            ),
            PopupMenuButton<String>(
              icon: Icon(
                _categoryIcons[_selectedCategory],
                color: const Color(0xFF9CA3AF),
              ),
              tooltip: 'カテゴリー選択',
              onSelected: (value) {
                setState(() {
                  _selectedCategory = value;
                });
              },
              itemBuilder: (context) => _categoryLabels.entries.map((e) {
                return PopupMenuItem(
                  value: e.key,
                  child: Row(
                    children: [
                      Icon(
                        _categoryIcons[e.key],
                        color: const Color(0xFF9CA3AF),
                      ),
                      const SizedBox(width: 8),
                      Text(e.value),
                    ],
                  ),
                );
              }).toList(),
            ),
            PopupMenuButton<int>(
              icon: Icon(
                Icons.access_time,
                color: _selectedDuration != null
                    ? const Color(0xFFFF6B35)
                    : const Color(0xFF9CA3AF),
              ),
              tooltip: '見積時間',
              onSelected: (value) {
                setState(() {
                  _selectedDuration = value;
                });
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 15, child: Text('15分')),
                PopupMenuItem(value: 30, child: Text('30分')),
                PopupMenuItem(value: 45, child: Text('45分')),
                PopupMenuItem(value: 60, child: Text('1時間')),
                PopupMenuItem(value: 90, child: Text('1.5時間')),
                PopupMenuItem(value: 120, child: Text('2時間')),
              ],
            ),
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
              itemBuilder: (context) => _difficultyLabels.entries.map((e) {
                return PopupMenuItem(
                  value: e.key,
                  child: Text(
                    e.value,
                    style: TextStyle(
                      color: _difficultyColors[e.key],
                      height: 1.5,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        if (hasSelectionSummary) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_selectedDate != null)
                Chip(
                  avatar: const Icon(Icons.event, size: 16),
                  label: Text(
                    '${_selectedDate!.year}/${_selectedDate!.month}/${_selectedDate!.day}',
                  ),
                ),
              if (_selectedRecurrence != 'none')
                Chip(
                  avatar: const Icon(Icons.repeat, size: 16),
                  label: Text(_recurrenceChipLabel(_selectedRecurrence)),
                ),
              if (_selectedDuration != null)
                Chip(
                  avatar: const Icon(Icons.access_time, size: 16),
                  label: Text('${_selectedDuration!}分'),
                ),
              if (_selectedDifficulty != 'normal')
                Chip(
                  avatar: const Icon(Icons.signal_cellular_alt, size: 16),
                  label: Text(_difficultyChipLabel(_selectedDifficulty)),
                ),
            ],
          ),
        ],
      ],
    );
  }

  String _recurrenceChipLabel(String value) {
    switch (value) {
      case 'daily':
        return '毎日';
      case 'weekly':
        return '毎週';
      case 'monthly':
        return '毎月';
      default:
        return '繰り返しなし';
    }
  }

  String _difficultyChipLabel(String value) {
    switch (value) {
      case 'easy':
        return '簡単';
      case 'hard':
        return '難しい';
      default:
        return '普通';
    }
  }

  DateTime? _parseLocalDateTime(String? rawValue) {
    if (rawValue == null || rawValue.isEmpty) {
      return null;
    }

    try {
      return DateTime.parse(rawValue).toLocal();
    } catch (_) {
      return null;
    }
  }

  String _formatCalendarDate(
    DateTime? date, {
    bool includeWeekday = false,
    bool includeTime = false,
  }) {
    if (date == null) {
      return '未設定';
    }

    const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
    final buffer = StringBuffer(
      '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}',
    );

    if (includeWeekday) {
      buffer.write(' (${weekdays[date.weekday - 1]})');
    }

    final hasTime = date.hour != 0 || date.minute != 0;
    if (includeTime && hasTime) {
      buffer.write(
        ' ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
      );
    }

    return buffer.toString();
  }

  Widget _buildCalendarMetaChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarTaskCard(
    Map<String, dynamic> todo, {
    bool compact = false,
  }) {
    final task = (todo['task'] as String? ?? '').trim();
    final details = (todo['details'] as String?)?.trim();
    final isCompleted = todo['is_completed'] as bool? ?? false;
    final isImportant = todo['is_important'] as bool? ?? false;
    final category = todo['category'] as String? ?? 'work';
    final difficulty = todo['difficulty'] as String? ?? 'normal';
    final recurrence = todo['recurrence'] as String? ?? 'none';
    final estimatedMinutes = (todo['estimated_minutes'] as num?)?.toInt();
    final actualMinutes = (todo['actual_minutes'] as num?)?.toInt();
    final dueDate = _parseLocalDateTime(todo['due_date'] as String?);
    final todoId = todo['id'] as String?;
    final matchingSubtasks = todoId == null
        ? const <Map<String, dynamic>>[]
        : _subtasks.where((item) => item['todo_id'] == todoId).toList();
    final completedSubtasks =
        matchingSubtasks.where((item) => item['is_completed'] == true).length;

    final now = DateTime.now();
    final isOverdue = !isCompleted &&
        dueDate != null &&
        DateTime(
          dueDate.year,
          dueDate.month,
          dueDate.day,
          23,
          59,
          59,
        ).isBefore(now);

    return Card(
      margin: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 4 : 6,
      ),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isOverdue
              ? const Color(0xFFFCA5A5)
              : (isCompleted
                  ? Theme.of(context).colorScheme.surfaceContainerHigh
                  : Theme.of(context).colorScheme.surfaceContainerHighest),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => showTaskDetails(todo),
        child: Padding(
          padding: EdgeInsets.all(compact ? 12 : 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isCompleted
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: isCompleted
                        ? const Color(0xFF0D9488)
                        : const Color(0xFF9CA3AF),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                task,
                                style: TextStyle(
                                  fontSize: compact ? 14 : 15,
                                  fontWeight: FontWeight.w700,
                                  decoration: isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: isCompleted
                                      ? const Color(0xFF9CA3AF)
                                      : (isOverdue
                                          ? const Color(0xFFB91C1C)
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurface),
                                  height: 1.5,
                                ),
                              ),
                            ),
                            if (isImportant)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  '重要',
                                  style: TextStyle(
                                    color: Color(0xFF78350F),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            if (isCompleted)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0FDFA),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  '完了',
                                  style: TextStyle(
                                    color: Color(0xFF0F766E),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (details != null && details.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            details,
                            maxLines: compact ? 2 : 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (todoId != null)
                        IconButton(
                          key: Key('morning_briefing_calendar_delete_$todoId'),
                          onPressed: () => _confirmDeleteTodo(todo),
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'タスクを削除',
                          color: const Color(0xFFB91C1C),
                          visualDensity: VisualDensity.compact,
                        ),
                      Icon(
                        Icons.chevron_right,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: compact ? 8 : 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildCalendarMetaChip(
                    icon: dueDate == null ? Icons.event_busy : Icons.event,
                    label: dueDate == null
                        ? '期限未設定'
                        : _formatCalendarDate(dueDate, includeTime: true),
                    color: isOverdue
                        ? const Color(0xFFB91C1C)
                        : const Color(0xFF475569),
                  ),
                  _buildCalendarMetaChip(
                    icon: _categoryIcons[category] ?? Icons.category,
                    label: _categoryLabels[category] ?? category,
                    color: _categoryColors[category] ?? const Color(0xFF9CA3AF),
                  ),
                  if (recurrence != 'none')
                    _buildCalendarMetaChip(
                      icon: Icons.repeat,
                      label: _recurrenceChipLabel(recurrence),
                      color: const Color(0xFF6366F1),
                    ),
                  _buildCalendarMetaChip(
                    icon: Icons.signal_cellular_alt,
                    label: _difficultyLabels[difficulty] ?? difficulty,
                    color: _difficultyColors[difficulty] ??
                        const Color(0xFF6366F1),
                  ),
                  if (estimatedMinutes != null)
                    _buildCalendarMetaChip(
                      icon: Icons.timer_outlined,
                      label: '見積 $estimatedMinutes分',
                      color: const Color(0xFF6366F1),
                    ),
                  if (actualMinutes != null)
                    _buildCalendarMetaChip(
                      icon: Icons.play_circle_outline,
                      label: '実績 $actualMinutes分',
                      color: const Color(0xFF0D9488),
                    ),
                ],
              ),
              if (matchingSubtasks.isNotEmpty) ...[
                SizedBox(height: compact ? 8 : 10),
                Row(
                  children: [
                    const Icon(
                      Icons.checklist,
                      size: 16,
                      color: Color(0xFF9CA3AF),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'サブタスク $completedSubtasks/${matchingSubtasks.length} 完了',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ],
              SizedBox(height: compact ? 6 : 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'タップで詳細',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _useCalendarBottomSheet(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return size.width < 520 || size.height < 760;
  }

  bool _useWideCalendarSplit(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return size.width >= 1120 && size.height >= 760;
  }

  Future<void> _showCalendarDayTasksSheet(
    DateTime day,
    List<Map<String, dynamic>> tasks,
  ) async {
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: tasks.isEmpty ? 0.42 : 0.78,
          minChildSize: 0.32,
          maxChildSize: 0.94,
          builder: (context, scrollController) {
            return Material(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _formatCalendarDate(day, includeWeekday: true),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tasks.isEmpty
                        ? 'この日に登録されているタスクはありません。'
                        : '${tasks.length}件のタスクが登録されています。',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (tasks.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color:
                            Theme.of(context).colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text('別の日付を選ぶか、タスクを追加してください。'),
                    )
                  else
                    ...tasks.map(_buildCalendarTaskCard),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCompactCalendarSummaryCard(
    BuildContext context,
    DateTime selectedDay,
    List<Map<String, dynamic>> tasks,
  ) {
    final completedCount =
        tasks.where((todo) => todo['is_completed'] == true).length;
    final firstTask =
        tasks.isNotEmpty ? (tasks.first['task'] as String? ?? '').trim() : null;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1A1A2E)
            : const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatCalendarDate(selectedDay, includeWeekday: true),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tasks.isEmpty
                ? 'この日は未登録です。'
                : '登録 ${tasks.length}件 / 完了 $completedCount件',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
          if (firstTask != null && firstTask.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '先頭タスク: $firstTask',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _showCalendarDayTasksSheet(selectedDay, tasks),
              icon: const Icon(Icons.list_alt),
              label: Text(tasks.isEmpty ? 'この日の状況を見る' : 'この日の詳細を開く'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarDetailPane(
    DateTime selectedDay,
    List<Map<String, dynamic>> tasks, {
    required bool dense,
  }) {
    final completedCount =
        tasks.where((todo) => todo['is_completed'] == true).length;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(dense ? 12 : 14),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1A1A2E)
                  : const Color(0xFFEEF2FF),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatCalendarDate(
                    selectedDay,
                    includeWeekday: true,
                  ),
                  style: TextStyle(
                    fontSize: dense ? 15 : 16,
                    fontWeight: FontWeight.w800,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '登録 ${tasks.length}件 / 完了 $completedCount件',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: dense ? 12 : 13,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
                if (tasks.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'カードをタップすると詳細とサブタスクを確認できます。',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (tasks.isEmpty)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'この日に登録されているタスクはありません。',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.only(
                  top: dense ? 8 : 10,
                  bottom: dense ? 10 : 12,
                ),
                itemCount: tasks.length,
                itemBuilder: (context, index) =>
                    _buildCalendarTaskCard(tasks[index], compact: dense),
              ),
            ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildCalendarViewLegacy() {
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
            todayDecoration: const BoxDecoration(
              color: Color(0xFFFDBA74),
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              shape: BoxShape.circle,
            ),
            markerDecoration: const BoxDecoration(
              color: Color(0xFF6366F1),
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
                      color: isCompleted
                          ? Theme.of(context).colorScheme.surfaceContainerHigh
                          : const Color(0xFFE5E7EB),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                      ),
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: ListTile(
                      onTap: () => showTaskDetails(todo),
                      title: Text(
                        '${todo['task']}',
                        style: TextStyle(
                          decoration:
                              isCompleted ? TextDecoration.lineThrough : null,
                          color: isCompleted
                              ? Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.38)
                              : Theme.of(context).colorScheme.onSurface,
                          height: 1.5,
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
                              style: const TextStyle(
                                fontSize: 12,
                                height: 1.5,
                              ),
                            ),
                            const Text(
                              ' / ',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF9CA3AF),
                                height: 1.5,
                              ),
                            ),
                            Text(
                              _difficultyLabels[difficulty] ?? '',
                              style: TextStyle(
                                fontSize: 12,
                                color: _difficultyColors[difficulty],
                                height: 1.5,
                              ),
                            ),
                            if (estimatedMinutes != null) ...[
                              const Text(
                                ' / ',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF9CA3AF),
                                  height: 1.5,
                                ),
                              ),
                              const Icon(
                                Icons.access_time,
                                size: 14,
                                color: Color(0xFF9CA3AF),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '$estimatedMinutes分',
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      leading: Icon(
                        isCompleted
                            ? Icons.check_circle
                            : Icons.check_circle_outline,
                        color: isCompleted
                            ? const Color(0xFF0D9488)
                            : const Color(0xFF9CA3AF),
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

  // ignore: unused_element
  Widget _buildCalendarViewCurrentLegacy() {
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
            todayDecoration: const BoxDecoration(
              color: Color(0xFFFDBA74),
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              shape: BoxShape.circle,
            ),
            markerDecoration: const BoxDecoration(
              color: Color(0xFF6366F1),
              shape: BoxShape.circle,
            ),
          ),
          headerStyle: const HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
          ),
          onDaySelected: (selectedDay, focusedDay) {
            if (!isSameDay(_selectedDay, selectedDay)) {
              final events = _getEventsForDay(selectedDay);
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });

              _selectedEvents.value = events;

              if (_useCalendarBottomSheet(context)) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  _showCalendarDayTasksSheet(selectedDay, events);
                });
              }
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
              final selectedDay = _selectedDay ?? _focusedDay;
              final completedCount =
                  value.where((todo) => todo['is_completed'] == true).length;

              return Column(
                children: [
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF1A1A2E)
                          : const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatCalendarDate(
                            selectedDay,
                            includeWeekday: true,
                          ),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '登録 ${value.length}件 / 完了 $completedCount件',
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                            height: 1.5,
                          ),
                        ),
                        if (value.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'カードをタップすると詳細とサブタスクを確認できます。',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (value.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Text('この日に登録されているタスクはありません。'),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: value.length,
                        itemBuilder: (context, index) =>
                            _buildCalendarTaskCard(value[index]),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAdaptiveCalendarView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = _useCalendarBottomSheet(context);
        final isWideSplit = !isCompact && _useWideCalendarSplit(context);
        final denseCalendar = !isCompact && constraints.maxHeight < 720;
        final isTwoWeeks = _calendarFormat == CalendarFormat.twoWeeks;
        final rowHeight = isCompact
            ? 42.0
            : (isTwoWeeks ? 30.0 : (denseCalendar ? 34.0 : 38.0));
        final daysOfWeekHeight =
            isTwoWeeks ? 16.0 : (denseCalendar ? 18.0 : 22.0);

        final calendar = Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            denseCalendar ? 8 : 10,
            denseCalendar ? 4 : 8,
            denseCalendar ? 8 : 10,
            denseCalendar ? 8 : 10,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
            ),
          ),
          child: TableCalendar<Map<String, dynamic>>(
            locale: 'ja_JP',
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            calendarFormat: _calendarFormat,
            availableCalendarFormats: const {
              CalendarFormat.month: '月',
              CalendarFormat.twoWeeks: '2週',
              CalendarFormat.week: '週',
            },
            onFormatChanged: (format) {
              if (_calendarFormat != format) {
                setState(() => _calendarFormat = format);
              }
            },
            rowHeight: rowHeight,
            daysOfWeekHeight: daysOfWeekHeight,
            sixWeekMonthsEnforced: false,
            eventLoader: _getEventsForDay,
            startingDayOfWeek: StartingDayOfWeek.monday,
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              canMarkersOverflow: false,
              markersMaxCount: 1,
              cellMargin: EdgeInsets.symmetric(
                horizontal: isTwoWeeks ? 1.0 : (denseCalendar ? 1.5 : 2.5),
                vertical: isTwoWeeks ? 1.0 : (denseCalendar ? 1.5 : 2.5),
              ),
              todayDecoration: const BoxDecoration(
                color: Color(0xFFFDBA74),
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                shape: BoxShape.circle,
              ),
              markerDecoration: const BoxDecoration(
                color: Color(0xFF6366F1),
                shape: BoxShape.circle,
              ),
              defaultTextStyle: TextStyle(
                fontSize: isTwoWeeks ? 12 : (denseCalendar ? 13 : 14),
                height: 1.5,
              ),
              weekendTextStyle: TextStyle(
                fontSize: isTwoWeeks ? 12 : (denseCalendar ? 13 : 14),
                height: 1.5,
              ),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: TextStyle(
                fontSize: isTwoWeeks ? 10 : (denseCalendar ? 11 : 12),
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
              weekendStyle: TextStyle(
                fontSize: isTwoWeeks ? 10 : (denseCalendar ? 11 : 12),
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
            headerStyle: HeaderStyle(
              formatButtonVisible: true,
              formatButtonShowsNext: false,
              formatButtonDecoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFA5B4FC)),
                borderRadius: BorderRadius.circular(12),
              ),
              formatButtonTextStyle: const TextStyle(
                fontSize: 11,
                color: Color(0xFF4338CA),
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
              titleCentered: true,
              headerPadding: EdgeInsets.symmetric(
                vertical: isTwoWeeks ? 2 : (denseCalendar ? 2 : 6),
              ),
              titleTextStyle: TextStyle(
                fontSize: isTwoWeeks ? 14 : (denseCalendar ? 16 : 18),
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
              leftChevronMargin: EdgeInsets.zero,
              rightChevronMargin: EdgeInsets.zero,
              leftChevronPadding: const EdgeInsets.all(4),
              rightChevronPadding: const EdgeInsets.all(4),
            ),
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, day, events) {
                if (events.isEmpty) {
                  return const SizedBox.shrink();
                }

                final countLabel =
                    events.length > 9 ? '9+' : events.length.toString();

                return Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    margin: EdgeInsets.only(
                      bottom: denseCalendar ? 1 : 2,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF818CF8),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      countLabel,
                      style: const TextStyle(
                        color: Color(0xFFE5E7EB),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        height: 1.5,
                      ),
                    ),
                  ),
                );
              },
            ),
            onDaySelected: (selectedDay, focusedDay) {
              if (!isSameDay(_selectedDay, selectedDay)) {
                final events = _getEventsForDay(selectedDay);

                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });

                _selectedEvents.value = events;

                if (_useCalendarBottomSheet(context)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    _showCalendarDayTasksSheet(selectedDay, events);
                  });
                }
              }
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
          ),
        );

        return ValueListenableBuilder<List<Map<String, dynamic>>>(
          valueListenable: _selectedEvents,
          builder: (context, value, _) {
            final selectedDay = _selectedDay ?? _focusedDay;

            if (isCompact) {
              return Column(
                children: [
                  calendar,
                  const SizedBox(height: 8),
                  _buildCompactCalendarSummaryCard(
                    context,
                    selectedDay,
                    value,
                  ),
                ],
              );
            }

            final detailPane = _buildCalendarDetailPane(
              selectedDay,
              value,
              dense: denseCalendar,
            );

            if (isWideSplit) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Flexible(
                    flex: 8,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: calendar,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    flex: 11,
                    child: detailPane,
                  ),
                ],
              );
            }

            return Column(
              children: [
                calendar,
                const SizedBox(height: 8),
                Expanded(child: detailPane),
              ],
            );
          },
        );
      },
    );
  }

  // ignore: unused_element
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
            todayDecoration: const BoxDecoration(
              color: Color(0xFFFDBA74),
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              shape: BoxShape.circle,
            ),
            markerDecoration: const BoxDecoration(
              color: Color(0xFF6366F1),
              shape: BoxShape.circle,
            ),
          ),
          headerStyle: const HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
          ),
          onDaySelected: (selectedDay, focusedDay) {
            if (!isSameDay(_selectedDay, selectedDay)) {
              final events = _getEventsForDay(selectedDay);

              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });

              _selectedEvents.value = events;

              if (_useCalendarBottomSheet(context)) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  _showCalendarDayTasksSheet(selectedDay, events);
                });
              }
            }
          },
          onPageChanged: (focusedDay) {
            _focusedDay = focusedDay;
          },
        ),
        const Divider(),
        ValueListenableBuilder<List<Map<String, dynamic>>>(
          valueListenable: _selectedEvents,
          builder: (context, value, _) {
            final selectedDay = _selectedDay ?? _focusedDay;
            final isCompact = _useCalendarBottomSheet(context);

            if (isCompact) {
              return _buildCompactCalendarSummaryCard(
                context,
                selectedDay,
                value,
              );
            }

            final completedCount =
                value.where((todo) => todo['is_completed'] == true).length;
            final isDark = Theme.of(context).brightness == Brightness.dark;

            return Expanded(
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1A1A2E)
                          : const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatCalendarDate(
                            selectedDay,
                            includeWeekday: true,
                          ),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '登録 ${value.length}件 / 完了 $completedCount件',
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                            height: 1.5,
                          ),
                        ),
                        if (value.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'カードをタップすると詳細とサブタスクを確認できます。',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (value.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Text('この日に登録されているタスクはありません。'),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: value.length,
                        itemBuilder: (context, index) =>
                            _buildCalendarTaskCard(value[index]),
                      ),
                    ),
                ],
              ),
            );
          },
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
      tileColor: !isCompleted && isDueToday ? const Color(0xFFFFF7ED) : null,
      shape: !isCompleted && isDueToday
          ? RoundedRectangleBorder(
              side: const BorderSide(color: Color(0xFFFF6B35), width: 1),
              borderRadius: BorderRadius.circular(8),
            )
          : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),

      onTap: isLocked
          ? () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('最重要タスク（★）が残っています。先に片付けましょう！'),
                  backgroundColor: Color(0xFFFF6B35),
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
                todo['details'] as String?,
              ),
      onLongPress: () => showTaskDetails(todo),
      leading: Checkbox(
        value: isCompleted,
        onChanged: isLocked
            ? (val) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('最重要タスク（★）が残っています。先に片付けましょう！'),
                    backgroundColor: Color(0xFFFF6B35),
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
                  ? const Color(0xFF9CA3AF)
                  : (isLocked
                      ? const Color(0xFF9CA3AF)
                      : (isOverdue
                          ? const Color(0xFFB91C1C)
                          : (isDueToday ? const Color(0xFFFF6B35) : null))),
              fontWeight: (isOverdue || isDueToday) && !isLocked
                  ? FontWeight.bold
                  : null,
              height: 1.5,
            ),
          ),
          // ★ 追加: 今日中バッジ
          if (!isCompleted && isDueToday)
            const Chip(
              label: Text(
                '今日中',
                style: TextStyle(
                  color: Color(0xFFE5E7EB),
                  fontSize: 10,
                  height: 1.5,
                ),
              ),
              backgroundColor: Color(0xFFFF6B35),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              side: BorderSide.none,
            ),
          // ★ 追加: 繰り返しバッジ
          if (recurrenceLabel != null)
            Chip(
              avatar: const Icon(
                Icons.repeat,
                size: 12,
                color: Color(0xFFE5E7EB),
              ),
              label: Text(
                recurrenceLabel,
                style: const TextStyle(
                  color: Color(0xFFE5E7EB),
                  fontSize: 10,
                  height: 1.5,
                ),
              ),
              backgroundColor: const Color(0xFFA78BFA),
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
              Icon(
                _categoryIcons[category],
                size: 12,
                color: const Color(0xFF9CA3AF),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  subtitleText,
                  style: TextStyle(
                    color: isCompleted
                        ? const Color(0xFF9CA3AF)
                        : (isLocked
                            ? const Color(0xFF9CA3AF)
                            : (isOverdue
                                ? const Color(0xFFB91C1C)
                                : (isDueToday
                                    ? const Color(0xFFFF6B35)
                                    : (difficulty == 'hard'
                                        ? const Color(0xFFF87171)
                                        : const Color(0xFF9CA3AF))))),
                    fontWeight: difficulty == 'hard' && !isLocked
                        ? FontWeight.w500
                        : null,
                    height: 1.5,
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
                      backgroundColor:
                          Theme.of(context).colorScheme.surfaceContainerHigh,
                      color: const Color(0xFF6366F1),
                      minHeight: 4,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$subDone/$subTotal',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF9CA3AF),
                      height: 1.5,
                    ),
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
              color: isImportant
                  ? const Color(0xFFFF6B35)
                  : const Color(0xFF9CA3AF),
            ),
            onPressed: () => toggleImportant(id, isImportant),
          ),
          IconButton(
            key: Key('morning_briefing_delete_todo_$id'),
            icon: const Icon(
              Icons.delete_outline,
              color: Color(0xFFB91C1C),
            ),
            tooltip: 'タスクを削除',
            onPressed: () => _confirmDeleteTodo(todo),
          ),
          if (isReorderable)
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(Icons.drag_handle, color: Color(0xFF9CA3AF)),
              ),
            ),
        ],
      ),
    );

    return Dismissible(
      key: Key(id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: const Color(0xFFB91C1C),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete, color: Color(0xFFE5E7EB)),
      ),
      confirmDismiss: (direction) => _confirmDeleteTodo(todo),
      /*
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
                  backgroundColor: Color(0xFFB91C1C),
                ),
                child: const Text('削除'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => deleteTodo(id),
      */
      onDismissed: (_) {},
      child: isLocked ? Opacity(opacity: 0.5, child: content) : content,
    );
  }

  Widget _buildSomedayTaskView() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_somedayTasks.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 64,
                color: Color(0xFF9CA3AF),
              ),
              SizedBox(height: 16),
              Text(
                'ストックされたタスクはありません。',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF9CA3AF),
                  height: 1.5,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '「いつかやる」タスクをここに追加して、頭をスッキリさせましょう。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF9CA3AF),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Sort tasks by creation date, newest first
    final sortedTasks = List<Map<String, dynamic>>.from(_somedayTasks);
    sortedTasks.sort((a, b) {
      final aDateStr = a['created_at'] as String?;
      final bDateStr = b['created_at'] as String?;
      if (aDateStr == null && bDateStr == null) return 0;
      if (aDateStr == null) return 1; // nulls last
      if (bDateStr == null) return -1; // nulls last
      final aDate = DateTime.parse(aDateStr);
      final bDate = DateTime.parse(bDateStr);
      return bDate.compareTo(aDate); // newest first
    });

    return ListView.builder(
      itemCount: sortedTasks.length,
      itemBuilder: (context, index) {
        final task = sortedTasks[index];
        final id = task['id'] as String;
        final taskTitle = task['task'] as String;
        final createdAtStr = task['created_at'] as String?;
        String createdDate = '';
        if (createdAtStr != null) {
          createdDate = timeago.format(DateTime.parse(createdAtStr).toLocal());
        }

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            title: Text(taskTitle),
            subtitle: Text('追加日: $createdDate'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.upgrade, color: Color(0xFF0D9488)),
                  tooltip: '今日のタスクにする',
                  onPressed: () => _moveSomedayTaskToToday(id),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Color(0xFFB91C1C),
                  ),
                  tooltip: '削除',
                  onPressed: () => _deleteSomedayTask(id),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _moveSomedayTaskToToday(String id) async {
    final taskToMove = _somedayTasks.firstWhere((t) => t['id'] == id);

    try {
      // Get max order_index from daily_todos
      int maxOrder = 0;
      if (_todos.isNotEmpty) {
        for (var t in _todos) {
          final o = t['order_index'] as int? ?? 0;
          if (o > maxOrder) maxOrder = o;
        }
      }

      final detailsDropped = await _insertDailyTodoWithDetailsFallback({
        'task': taskToMove['task'],
        'is_completed': false,
        'is_important': taskToMove['is_important'] ?? false,
        'category': taskToMove['category'] ?? 'work',
        'difficulty': taskToMove['difficulty'] ?? 'normal',
        'details': taskToMove['details'],
        'order_index': maxOrder + 1, // Add to the end of the list
      });

      await Supabase.instance.client
          .from('someday_tasks')
          .delete()
          .eq('id', id)
          .select();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              detailsDropped
                  ? 'タスクを今日へ移動しました。詳細メモは DB 反映後に利用できます。'
                  : 'タスクを「今日」に移動しました。',
            ),
            backgroundColor: detailsDropped
                ? const Color(0xFFFF6B35)
                : const Color(0xFF0D9488),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error moving task: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('移動エラー: $e'),
          ),
        );
      }
    }
  }

  Future<void> _deleteSomedayTask(String id) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ストックタスクの削除'),
        content: const Text('このタスクを完全に削除しますか？\nこの操作は元に戻せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB91C1C),
            ),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (result != true) return;

    try {
      await Supabase.instance.client
          .from('someday_tasks')
          .delete()
          .eq('id', id)
          .select();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('タスクを削除しました。'),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error deleting someday task: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('削除エラー: $e'),
          ),
        );
      }
    }
  }
}
