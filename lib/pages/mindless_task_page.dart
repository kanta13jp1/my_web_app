import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

enum TaskPriority {
  a,
  b,
  c,
}

class _PhoneDetoxAction {
  final String label;
  final TaskPriority priority;

  const _PhoneDetoxAction({
    required this.label,
    required this.priority,
  });
}

class _CriticalTaskTemplate {
  final String label;
  final TaskPriority priority;

  const _CriticalTaskTemplate({
    required this.label,
    required this.priority,
  });
}

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
  int _completedReadingSessions = 0;
  int _completedWalkBreaks = 0;
  int _phoneSlipCount = 0;
  int _currentReadingStreak = 0;
  bool _phoneShieldEnabled = true;
  TaskPriority _defaultTaskPriority = TaskPriority.c;

  static const List<int> _timeboxPresets = [15, 30, 50, 90];
  static const int _dailyTaskTarget = 100;
  static const int _batchTaskCount = 5;
  static const List<_PhoneDetoxAction> _phoneDetoxActions = [
    _PhoneDetoxAction(label: '朝に触らない', priority: TaskPriority.a),
    _PhoneDetoxAction(label: '仕事に没頭する', priority: TaskPriority.a),
    _PhoneDetoxAction(label: 'グレースケール', priority: TaskPriority.c),
    _PhoneDetoxAction(label: 'SNSをPCに移行', priority: TaskPriority.b),
    _PhoneDetoxAction(label: 'スマホなしで散歩', priority: TaskPriority.b),
    _PhoneDetoxAction(label: '連絡をまとめて返す', priority: TaskPriority.b),
    _PhoneDetoxAction(label: 'ゲームのデータ削除', priority: TaskPriority.a),
    _PhoneDetoxAction(label: 'タイムロッキングコンテナ', priority: TaskPriority.a),
  ];
  static const List<_CriticalTaskTemplate> _criticalTaskTemplates = [
    _CriticalTaskTemplate(
      label: '朝10分の防衛チェック（不審リンク/請求/認証）',
      priority: TaskPriority.a,
    ),
    _CriticalTaskTemplate(
      label: '今日の最重要タスクを1件完了',
      priority: TaskPriority.a,
    ),
    _CriticalTaskTemplate(
      label: '1円収益アクションを1件実行',
      priority: TaskPriority.a,
    ),
    _CriticalTaskTemplate(
      label: '終了前に資産・アカウント記録を更新',
      priority: TaskPriority.a,
    ),
  ];

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

  List<Map<String, dynamic>> get _allTasks {
    return _tasksByHour.values.expand((tasks) => tasks).toList();
  }

  int get _completedTasksToday {
    return _allTasks.where((task) => task['is_completed'] == true).length;
  }

  int get _remainingTasksToTarget {
    final remaining = _dailyTaskTarget - _completedTasksToday;
    return remaining > 0 ? remaining : 0;
  }

  double get _dailyTargetProgress {
    return (_completedTasksToday / _dailyTaskTarget).clamp(0, 1);
  }

  int _priorityTotal(TaskPriority priority) {
    return _allTasks
        .where(
          (task) =>
              _parsePriority(task['content'] as String? ?? '') == priority,
        )
        .length;
  }

  int _priorityCompleted(TaskPriority priority) {
    return _allTasks
        .where(
          (task) =>
              _parsePriority(task['content'] as String? ?? '') == priority &&
              task['is_completed'] == true,
        )
        .length;
  }

  bool get _aPriorityMinimumDone => _priorityCompleted(TaskPriority.a) >= 3;

  TaskPriority _parsePriority(String content) {
    if (content.startsWith('[A]')) return TaskPriority.a;
    if (content.startsWith('[B]')) return TaskPriority.b;
    return TaskPriority.c;
  }

  String _priorityTag(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.a:
        return '[A]';
      case TaskPriority.b:
        return '[B]';
      case TaskPriority.c:
        return '[C]';
    }
  }

  String _priorityLabel(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.a:
        return 'A';
      case TaskPriority.b:
        return 'B';
      case TaskPriority.c:
        return 'C';
    }
  }

  Color _priorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.a:
        return Colors.redAccent;
      case TaskPriority.b:
        return Colors.orange;
      case TaskPriority.c:
        return Colors.blueGrey;
    }
  }

  String _stripPriorityTag(String content) {
    return content.replaceFirst(RegExp(r'^\[(A|B|C)\]\s*'), '').trim();
  }

  String _detoxTaskTitle(_PhoneDetoxAction action) {
    return 'スマホ禁欲: ${action.label}';
  }

  bool _isDetoxTask(Map<String, dynamic> task, _PhoneDetoxAction action) {
    final content = _stripPriorityTag(task['content'] as String? ?? '');
    return content == _detoxTaskTitle(action);
  }

  int get _detoxScheduledCount {
    return _phoneDetoxActions.where((action) {
      return _allTasks.any((task) => _isDetoxTask(task, action));
    }).length;
  }

  int get _detoxCompletedCount {
    return _phoneDetoxActions.where((action) {
      return _allTasks.any(
        (task) => _isDetoxTask(task, action) && task['is_completed'] == true,
      );
    }).length;
  }

  String _criticalTaskTitle(_CriticalTaskTemplate template) {
    return '必須: ${template.label}';
  }

  bool _isCriticalTaskRow(Map<String, dynamic> task) {
    final content = _stripPriorityTag(task['content'] as String? ?? '');
    return content.startsWith('必須: ');
  }

  int get _criticalTotalCount {
    return _allTasks.where(_isCriticalTaskRow).length;
  }

  int get _criticalCompletedCount {
    return _allTasks
        .where((task) => _isCriticalTaskRow(task) && task['is_completed'] == true)
        .length;
  }

  int get _criticalRemainingCount {
    final remaining = _criticalTotalCount - _criticalCompletedCount;
    return remaining > 0 ? remaining : 0;
  }

  bool get _isCriticalLockActive {
    return _criticalTotalCount > 0 && _criticalRemainingCount > 0;
  }

  List<String> get _pendingCriticalTitles {
    return _allTasks
        .where((task) => _isCriticalTaskRow(task) && task['is_completed'] != true)
        .map((task) => _stripPriorityTag(task['content'] as String? ?? ''))
        .toList();
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

  bool _canStartOptionalFlow() {
    if (_isCriticalLockActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('先に必須タスクを完了してください。')),
      );
      return false;
    }
    return true;
  }

  Future<int> _addMissingPhoneDetoxTasks({
    required String userId,
    required int hourSlot,
  }) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final dynamic existingRowsRaw = await _supabase
        .from('mindless_tasks')
        .select('content')
        .eq('user_id', userId)
        .eq('task_date', dateStr);
    final existingRows = existingRowsRaw is List
        ? existingRowsRaw
        : const <dynamic>[];

    final existingDetoxTitles = existingRows
        .whereType<Map<String, dynamic>>()
        .map((row) => _stripPriorityTag(row['content'] as String? ?? ''))
        .where((content) => content.startsWith('スマホ禁欲: '))
        .toSet();

    final actionsToInsert = _phoneDetoxActions.where((action) {
      return !existingDetoxTitles.contains(_detoxTaskTitle(action));
    }).toList();

    if (actionsToInsert.isEmpty) {
      return 0;
    }

    final inserts = actionsToInsert.map((action) {
      return <String, dynamic>{
        'user_id': userId,
        'task_date': dateStr,
        'hour_slot': hourSlot,
        'content': '${_priorityTag(action.priority)} ${_detoxTaskTitle(action)}',
        'is_completed': false,
      };
    }).toList();

    await _supabase.from('mindless_tasks').insert(inserts);
    return actionsToInsert.length;
  }

  void _startCriticalFocusSprint() {
    if (_isTimeboxRunning) return;
    _startTimebox(
      mode: '必須遂行',
      goal: '今日の必須タスクを進める',
      minutes: 25,
    );
  }

  Future<void> _syncCriticalTasks() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final dynamic rowsRaw = await _supabase
          .from('mindless_tasks')
          .select('content')
          .eq('user_id', userId)
          .eq('task_date', dateStr);
      final rows = rowsRaw is List ? rowsRaw : const <dynamic>[];

      final existingTitles = rows
          .whereType<Map<String, dynamic>>()
          .map((row) => _stripPriorityTag(row['content'] as String? ?? ''))
          .toSet();

      final templatesToInsert = _criticalTaskTemplates.where((template) {
        return !existingTitles.contains(_criticalTaskTitle(template));
      }).toList();

      if (templatesToInsert.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('必須タスクは展開済みです。')));
        return;
      }

      final nowHour = DateTime.now().hour;
      final inserts = templatesToInsert.map((template) {
        return <String, dynamic>{
          'user_id': userId,
          'task_date': dateStr,
          'hour_slot': nowHour,
          'content': '${_priorityTag(template.priority)} ${_criticalTaskTitle(template)}',
          'is_completed': false,
        };
      }).toList();

      await _supabase.from('mindless_tasks').insert(inserts);
      await _loadTasks();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('必須タスクを${templatesToInsert.length}件追加しました。'),
        ),
      );
    } catch (e) {
      debugPrint('Critical task sync failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('必須タスクの追加に失敗しました。')));
    }
  }

  Future<void> _startTimeboxFlow(String mode) async {
    if (!_canStartOptionalFlow()) return;

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
          if (_timeboxMode == '読書') {
            _completedReadingSessions += 1;
            _currentReadingStreak += 1;
          } else if (_timeboxMode == '散歩') {
            _completedWalkBreaks += 1;
            _currentReadingStreak = 0;
          }
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

  void _startReadingAlbum() {
    if (_isTimeboxRunning || !_canStartOptionalFlow()) return;
    _startTimebox(
      mode: '読書',
      goal: '読書に没頭（スマホを見ない）',
      minutes: 60,
    );
  }

  void _startWalkBreak(int minutes) {
    if (_isTimeboxRunning || !_canStartOptionalFlow()) return;
    _startTimebox(
      mode: '散歩',
      goal: '喫茶店を出て歩く',
      minutes: minutes,
    );
  }

  void _logPhoneSlip() {
    if (!_isTimeboxRunning || _timeboxMode != '読書' || !_phoneShieldEnabled) {
      return;
    }
    setState(() {
      _phoneSlipCount += 1;
    });
  }

  void _startFiveTaskSprint() {
    if (_isTimeboxRunning || !_canStartOptionalFlow()) return;
    _startTimebox(
      mode: '5件バッチ',
      goal: '15分で5件を終わらせる',
      minutes: 15,
    );
  }

  Future<void> _startPhoneLockFocus() async {
    if (_isTimeboxRunning || !_canStartOptionalFlow()) return;
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final insertedCount = await _addMissingPhoneDetoxTasks(
        userId: userId,
        hourSlot: DateTime.now().hour,
      );

      if (mounted) {
        setState(() {
          _phoneShieldEnabled = true;
        });
      }
      await _loadTasks();
      if (!mounted) return;

      if (insertedCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('スマホ禁欲項目を$insertedCount件自動追加しました。'),
          ),
        );
      }

      _startTimebox(
        mode: '物理ロック',
        goal: 'スマホを封印して他のことに没頭する',
        minutes: 90,
      );
    } catch (e) {
      debugPrint('Phone lock start failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('物理ロック開始に失敗しました（通信/認証）')));
    }
  }

  Future<void> _showPhoneDetoxTemplateDialog() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    int selectedHour = DateTime.now().hour;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: const Text('スマホ禁欲8項目を追加'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('今日のタスクとして8項目を一括追加します。'),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: selectedHour,
                  decoration: const InputDecoration(
                    labelText: '配置する時間帯',
                    border: OutlineInputBorder(),
                  ),
                  items: List.generate(24, (hour) {
                    return DropdownMenuItem<int>(
                      value: hour,
                      child: Text('$hour:00'),
                    );
                  }),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedHour = value);
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                onPressed: () async {
                  try {
                    final insertedCount = await _addMissingPhoneDetoxTasks(
                      userId: userId,
                      hourSlot: selectedHour,
                    );

                    if (insertedCount == 0) {
                      if (!mounted) return;
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('すでに追加済みです。')),
                      );
                      return;
                    }
                    if (!mounted) return;
                    Navigator.of(context).pop();
                    await _loadTasks();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'スマホ禁欲項目を$insertedCount件追加しました。',
                        ),
                      ),
                    );
                  } catch (e) {
                    debugPrint('PhoneDetox insert failed: $e');
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('追加に失敗しました（通信/認証）')),
                    );
                  }
                },
                child: const Text('追加'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showBatchAddDialog() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final controller = TextEditingController();
    TaskPriority selectedPriority = _defaultTaskPriority;
    int selectedHour = DateTime.now().hour;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: const Text('5件バッチを追加'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'タスクの共通名',
                      hintText: '例: 見積もりメール返信',
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('優先度'),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: TaskPriority.values.map((priority) {
                      final selected = selectedPriority == priority;
                      final color = _priorityColor(priority);
                      return ChoiceChip(
                        label: Text(_priorityLabel(priority)),
                        selected: selected,
                        selectedColor: color.withValues(alpha: 0.18),
                        side: BorderSide(
                          color: selected ? color : Colors.grey.shade400,
                        ),
                        onSelected: (_) {
                          setDialogState(() => selectedPriority = priority);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: selectedHour,
                    decoration: const InputDecoration(
                      labelText: '配置する時間帯',
                      border: OutlineInputBorder(),
                    ),
                    items: List.generate(24, (hour) {
                      return DropdownMenuItem<int>(
                        value: hour,
                        child: Text('$hour:00'),
                      );
                    }),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selectedHour = value);
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                onPressed: () async {
                  final raw = controller.text.trim();
                  if (raw.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('タスク名を入力してください。')),
                    );
                    return;
                  }

                  final base = _stripPriorityTag(raw);
                  final dateStr =
                      DateFormat('yyyy-MM-dd').format(_selectedDate);
                  final tag = _priorityTag(selectedPriority);
                  final inserts = List.generate(_batchTaskCount, (index) {
                    return <String, dynamic>{
                      'user_id': userId,
                      'task_date': dateStr,
                      'hour_slot': selectedHour,
                      'content': '$tag $base ${index + 1}/$_batchTaskCount',
                      'is_completed': false,
                    };
                  });

                  await _supabase.from('mindless_tasks').insert(inserts);
                  if (!mounted) return;
                  setState(() => _defaultTaskPriority = selectedPriority);
                  Navigator.of(context).pop();
                  await _loadTasks();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '$_batchTaskCount件のバッチを追加しました（${_priorityLabel(selectedPriority)}）。',
                      ),
                    ),
                  );
                },
                child: const Text('追加'),
              ),
            ],
          );
        },
      ),
    );
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
    TaskPriority selectedPriority = _defaultTaskPriority;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('$hour時のタスクを追加'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: const InputDecoration(hintText: '例: お湯を沸かす'),
                  ),
                  const SizedBox(height: 12),
                  const Text('優先度'),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: TaskPriority.values.map((priority) {
                      final selected = selectedPriority == priority;
                      final color = _priorityColor(priority);
                      return ChoiceChip(
                        label: Text(_priorityLabel(priority)),
                        selected: selected,
                        selectedColor: color.withValues(alpha: 0.18),
                        side: BorderSide(
                          color: selected ? color : Colors.grey.shade400,
                        ),
                        onSelected: (_) {
                          setDialogState(() => selectedPriority = priority);
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('キャンセル'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, controller.text.trim()),
                child: const Text('追加'),
              ),
            ],
          );
        },
      ),
    );

    if (result != null && result.isNotEmpty) {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      final cleanedContent = _stripPriorityTag(result);
      final taggedContent = '${_priorityTag(selectedPriority)} $cleanedContent';

      await _supabase.from('mindless_tasks').insert({
        'user_id': userId,
        'task_date': DateFormat('yyyy-MM-dd').format(_selectedDate),
        'hour_slot': hour,
        'content': taggedContent,
        'is_completed': false,
      });
      setState(() => _defaultTaskPriority = selectedPriority);
      _loadTasks();
    }
  }

  Widget _buildHundredTaskPanel() {
    final done = _completedTasksToday;
    final ratioText = '$done / $_dailyTaskTarget 完了';
    final remainingText = _remainingTasksToTarget == 0
        ? '今日の100件達成'
        : '残り $_remainingTasksToTarget 件';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.lightBlue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt, color: Colors.blue.shade700),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  '100タスク量産モード',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                ratioText,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(value: _dailyTargetProgress),
          const SizedBox(height: 6),
          Text(
            remainingText,
            style: TextStyle(
              color:
                  _remainingTasksToTarget == 0 ? Colors.green : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildPriorityProgressChip(TaskPriority.a),
              _buildPriorityProgressChip(TaskPriority.b),
              _buildPriorityProgressChip(TaskPriority.c),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showBatchAddDialog,
                  icon: const Icon(Icons.playlist_add),
                  label: const Text('5件バッチ追加'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isTimeboxRunning ? null : _startFiveTaskSprint,
                  icon: const Icon(Icons.timer),
                  label: const Text('15分で5件'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _aPriorityMinimumDone ? 'Aタスク3件以上を達成済み' : 'Aタスクは最低3件を先に完了',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _aPriorityMinimumDone ? Colors.green : Colors.redAccent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCriticalLockPanel() {
    final total = _criticalTotalCount;
    final done = _criticalCompletedCount;
    final statusText = total == 0
        ? 'まず「必須タスクを展開」を押して開始'
        : _isCriticalLockActive
            ? 'ロック中: 残り$_criticalRemainingCount件'
            : 'ロック解除: 必須タスク完了';
    final progress = total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0).toDouble();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _isCriticalLockActive ? Colors.red.shade300 : Colors.green.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isCriticalLockActive ? Icons.lock : Icons.lock_open,
                color: _isCriticalLockActive ? Colors.redAccent : Colors.green,
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  '今日の必須タスク・ロック',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '$done/$total',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(value: progress),
          const SizedBox(height: 6),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 12,
              color: _isCriticalLockActive ? Colors.redAccent : Colors.green,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (_pendingCriticalTitles.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _pendingCriticalTitles.take(3).map((title) {
                return Chip(
                  label: Text(
                    title,
                    style: const TextStyle(fontSize: 11),
                  ),
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _syncCriticalTasks,
                  icon: const Icon(Icons.fact_check),
                  label: const Text('必須タスクを展開'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isTimeboxRunning ? null : _startCriticalFocusSprint,
                  icon: const Icon(Icons.gpp_good),
                  label: const Text('必須25分集中'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneDetoxPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.phonelink_erase, color: Colors.red.shade700),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'スマホ禁欲プロトコル',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '$_detoxCompletedCount/${_phoneDetoxActions.length}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '物理的に使えなくして、他のことに没頭する。',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _phoneDetoxActions
                .map((action) => _buildDetoxActionChip(action))
                .toList(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showPhoneDetoxTemplateDialog,
                  icon: const Icon(Icons.checklist_rtl),
                  label: Text('8項目を追加 ($_detoxScheduledCount済み)'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isTimeboxRunning ? null : _startPhoneLockFocus,
                  icon: const Icon(Icons.lock_clock),
                  label: const Text('物理ロック90分'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetoxActionChip(_PhoneDetoxAction action) {
    final scheduled = _allTasks.any((task) => _isDetoxTask(task, action));
    final completed = _allTasks.any(
      (task) => _isDetoxTask(task, action) && task['is_completed'] == true,
    );

    final chipColor = completed
        ? Colors.green
        : scheduled
            ? _priorityColor(action.priority)
            : Colors.grey;
    final icon = completed
        ? Icons.check_circle
        : scheduled
            ? Icons.radio_button_checked
            : Icons.radio_button_unchecked;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: chipColor),
          const SizedBox(width: 4),
          Text(
            action.label,
            style: TextStyle(
              color: chipColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
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
          const SizedBox(height: 10),
          _buildCriticalLockPanel(),
          const SizedBox(height: 10),
          _buildHundredTaskPanel(),
          const SizedBox(height: 10),
          _buildPhoneDetoxPanel(),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.menu_book, size: 18, color: Colors.brown),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '読書ルーティン（喫茶店 + アルバム）',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'アルバム1枚=60分で読書。2枚集中したら30〜60分散歩して、次の店で繰り返す。',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed:
                            _isTimeboxRunning ? null : _startReadingAlbum,
                        icon: const Icon(Icons.library_music),
                        label: const Text('アルバム1枚読書'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isTimeboxRunning
                            ? null
                            : () => _startWalkBreak(30),
                        icon: const Icon(Icons.directions_walk),
                        label: const Text('散歩30分'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isTimeboxRunning
                            ? null
                            : () => _startWalkBreak(60),
                        icon: const Icon(Icons.route),
                        label: const Text('散歩60分'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            _isTimeboxRunning ? null : _startReadingAlbum,
                        icon: const Icon(Icons.replay),
                        label: const Text('もう1枚読む'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: _phoneShieldEnabled,
                  onChanged: (value) {
                    setState(() => _phoneShieldEnabled = value);
                  },
                  title: const Text('読書中はスマホを見ないモード'),
                ),
                if (_phoneShieldEnabled)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.phone_android,
                          size: 16,
                          color: Colors.redAccent,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'スマホ逸脱 $phoneSlipLabel',
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: _isTimeboxRunning && _timeboxMode == '読書'
                              ? _logPhoneSlip
                              : null,
                          child: const Text('見てしまった +1'),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildMetricChip(
                      icon: Icons.menu_book,
                      label: '読書',
                      value: _completedReadingSessions.toString(),
                    ),
                    _buildMetricChip(
                      icon: Icons.directions_walk,
                      label: '散歩',
                      value: _completedWalkBreaks.toString(),
                    ),
                    _buildMetricChip(
                      icon: Icons.local_fire_department,
                      label: '連続読書',
                      value: _currentReadingStreak.toString(),
                    ),
                  ],
                ),
              ],
            ),
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

  String get phoneSlipLabel => '$_phoneSlipCount 回';

  Widget _buildPriorityProgressChip(TaskPriority priority) {
    final total = _priorityTotal(priority);
    final done = _priorityCompleted(priority);
    final color = _priorityColor(priority);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '${_priorityLabel(priority)} $done/$total',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildMetricChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.blueGrey.shade700),
          const SizedBox(width: 4),
          Text(
            '$label $value',
            style: TextStyle(
              color: Colors.blueGrey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
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
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.38,
            ),
            child: SingleChildScrollView(
              child: _buildTimeboxPanel(),
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
                                      final rawContent =
                                          task['content'] as String? ?? '';
                                      final priority =
                                          _parsePriority(rawContent);
                                      final displayContent =
                                          _stripPriorityTag(rawContent);
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
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      _priorityColor(priority)
                                                          .withValues(
                                                    alpha: 0.14,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  _priorityLabel(priority),
                                                  style: TextStyle(
                                                    color: _priorityColor(
                                                      priority,
                                                    ),
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  displayContent,
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
