import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/notification_service.dart';

enum _StockTaskViewMode {
  all,
  thinkingOnly,
  actionOnly,
}

class StockTasksPage extends StatefulWidget {
  final SupabaseClient? supabaseClient;
  final NotificationService? notificationService;
  final DateTime Function()? nowProvider;

  const StockTasksPage({
    super.key,
    this.supabaseClient,
    this.notificationService,
    this.nowProvider,
  });

  @override
  State<StockTasksPage> createState() => _StockTasksPageState();
}

class _StockTasksPageState extends State<StockTasksPage> {
  final _taskController = TextEditingController();
  static const String _saturdayReminderKey =
      'stock_tasks_saturday_reminder_enabled';
  static const String _categoryThinking = 'thinking_topic';
  static const String _categoryAction = 'action_task';

  SupabaseClient get _supabase =>
      widget.supabaseClient ?? Supabase.instance.client;

  NotificationService get _notificationService =>
      widget.notificationService ?? context.read<NotificationService>();

  DateTime _now() => widget.nowProvider?.call() ?? DateTime.now();

  // タスクリスト
  List<Map<String, dynamic>> _incompleteTasks = [];
  List<Map<String, dynamic>> _completedTasks = [];
  bool _isLoading = true;
  bool _saturdayReminderEnabled = true;
  bool _composeAsThinking = true;
  _StockTaskViewMode _viewMode = _StockTaskViewMode.all;

  @override
  void initState() {
    super.initState();
    _loadReminderPreference();
    _loadTasks();
  }

  @override
  void dispose() {
    _taskController.dispose();
    super.dispose();
  }

  bool get _isSaturday => _now().weekday == DateTime.saturday;

  int get _pendingCount => _incompleteTasks.length;

  String _categoryOfTask(Map<String, dynamic> task) {
    final category = (task['category'] as String?)?.trim();
    if (category == _categoryThinking || category == _categoryAction) {
      return category!;
    }
    return _categoryAction;
  }

  bool _isThinkingTask(Map<String, dynamic> task) {
    return _categoryOfTask(task) == _categoryThinking;
  }

  bool _isActionTask(Map<String, dynamic> task) {
    return _categoryOfTask(task) == _categoryAction;
  }

  int get _thinkingTaskCount =>
      _incompleteTasks.where(_isThinkingTask).length +
      _completedTasks.where(_isThinkingTask).length;

  int get _actionTaskCount =>
      _incompleteTasks.where(_isActionTask).length +
      _completedTasks.where(_isActionTask).length;

  List<Map<String, dynamic>> _applyViewMode(
    List<Map<String, dynamic>> tasks,
  ) {
    switch (_viewMode) {
      case _StockTaskViewMode.all:
        return tasks;
      case _StockTaskViewMode.thinkingOnly:
        return tasks.where(_isThinkingTask).toList();
      case _StockTaskViewMode.actionOnly:
        return tasks.where(_isActionTask).toList();
    }
  }

  Future<void> _loadReminderPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_saturdayReminderKey) ?? true;
    if (mounted) {
      setState(() {
        _saturdayReminderEnabled = enabled;
      });
    }
  }

  Future<void> _loadTasks() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final data = await _supabase
          .from('someday_tasks')
          .select('id, task, is_completed, created_at, category')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> tasks =
          List<Map<String, dynamic>>.from(data);

      if (mounted) {
        setState(() {
          _incompleteTasks =
              tasks.where((t) => t['is_completed'] == false).toList();
          _completedTasks =
              tasks.where((t) => t['is_completed'] == true).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading tasks: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleSaturdayReminder() async {
    final next = !_saturdayReminderEnabled;
    try {
      if (next) {
        await _notificationService.scheduleSaturdayReminder();
      } else {
        await _notificationService.cancelSaturdayReminder();
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_saturdayReminderKey, next);

      if (mounted) {
        setState(() {
          _saturdayReminderEnabled = next;
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            next ? '土曜10:00リマインドを有効にしました。' : '土曜10:00リマインドを無効にしました。',
          ),
        ),
      );
    } catch (e) {
      debugPrint('Saturday reminder toggle failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('通知設定の更新に失敗しました。')),
      );
    }
  }

  Future<void> _addTask() async {
    final taskText = _taskController.text.trim();
    if (taskText.isEmpty) return;

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _supabase.from('someday_tasks').insert({
        'user_id': userId,
        'task': taskText,
        'is_completed': false,
        'is_important': false,
        'category': _composeAsThinking ? _categoryThinking : _categoryAction,
      });
      _taskController.clear();
      await _loadTasks();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ストック追加に失敗しました。')),
      );
    }
  }

  Future<void> _toggleTask(String id, bool currentValue) async {
    try {
      await _supabase.from('someday_tasks').update({
        'is_completed': !currentValue,
      }).eq('id', id);
      await _loadTasks();
    } catch (e) {
      debugPrint('Error toggling task: $e');
    }
  }

  Future<void> _deleteTask(String id) async {
    try {
      await _supabase.from('someday_tasks').delete().eq('id', id);
      await _loadTasks();
    } catch (e) {
      debugPrint('Error deleting task: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('時間があるときのストック'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(
              _saturdayReminderEnabled
                  ? Icons.notifications_active
                  : Icons.notifications_off,
            ),
            tooltip: '土曜リマインド設定',
            onPressed: _toggleSaturdayReminder,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _isSaturday
                  ? Colors.amber.withValues(alpha: 0.16)
                  : Colors.teal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isSaturday ? Colors.amber : Colors.teal.shade200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isSaturday ? '今日は土曜日。ストック見直しデーです。' : '次に時間ができたときの候補をここに蓄積。',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  _isSaturday
                      ? (_pendingCount == 0
                          ? '未完了タスクはありません。'
                          : '未完了タスクが$_pendingCount件あります。')
                      : '土曜10:00にリマインドされます（${_saturdayReminderEnabled ? 'ON' : 'OFF'}）。',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface),
                ),
                const SizedBox(height: 6),
                Text(
                  '思考ネタ $_thinkingTaskCount 件 / 行動タスク $_actionTaskCount 件',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('すべて'),
                      selected: _viewMode == _StockTaskViewMode.all,
                      onSelected: (_) {
                        setState(() => _viewMode = _StockTaskViewMode.all);
                      },
                    ),
                    ChoiceChip(
                      label: const Text('思考ネタ'),
                      selected: _viewMode == _StockTaskViewMode.thinkingOnly,
                      onSelected: (_) {
                        setState(
                          () => _viewMode = _StockTaskViewMode.thinkingOnly,
                        );
                      },
                    ),
                    ChoiceChip(
                      label: const Text('行動タスク'),
                      selected: _viewMode == _StockTaskViewMode.actionOnly,
                      onSelected: (_) {
                        setState(
                          () => _viewMode = _StockTaskViewMode.actionOnly,
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          // タスクリストエリア
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadTasks,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (_applyViewMode(_incompleteTasks).isEmpty &&
                            _applyViewMode(_completedTasks).isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 50),
                            child: Center(
                              child: Text(
                                '思考ネタや行動タスクを\nストックしておきましょう',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          ),

                        // 未完了タスク
                        ..._applyViewMode(_incompleteTasks)
                            .map((task) => _buildTaskTile(task)),

                        if (_applyViewMode(_completedTasks).isNotEmpty) ...[
                          const SizedBox(height: 20),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              '完了済み',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                          const Divider(),
                          // 完了済みタスク
                          ..._applyViewMode(_completedTasks)
                              .map((task) => _buildTaskTile(task)),
                        ],
                      ],
                    ),
                  ),
          ),

          // 入力エリア (Google Tasks風)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('思考ネタ'),
                      selected: _composeAsThinking,
                      onSelected: (_) {
                        setState(() => _composeAsThinking = true);
                      },
                    ),
                    ChoiceChip(
                      label: const Text('行動タスク'),
                      selected: !_composeAsThinking,
                      onSelected: (_) {
                        setState(() => _composeAsThinking = false);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: TextField(
                    controller: _taskController,
                    decoration: InputDecoration(
                      hintText: _composeAsThinking
                          ? '脳に余裕があるときに考えるネタ'
                          : '次に時間があるときにやること',
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _addTask(),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.add_circle,
                    size: 32,
                    color: Colors.teal,
                  ),
                  onPressed: _addTask,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskTile(Map<String, dynamic> task) {
    final String id = task['id'].toString();
    final bool isCompleted = task['is_completed'] == true;
    final String text = task['task'] as String? ?? '';
    final bool isThinking = _isThinkingTask(task);
    final badgeColor = isThinking ? Colors.deepPurple : Colors.teal;
    final badgeText = isThinking ? '思考ネタ' : '行動';
    return Dismissible(
      key: ValueKey(id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _deleteTask(id),
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Theme.of(context).colorScheme.surfaceContainerHigh),
        ),
        color: Colors.white,
        child: ListTile(
          leading: IconButton(
            icon: Icon(
              isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isCompleted ? Colors.teal : Colors.grey,
            ),
            onPressed: () => _toggleTask(id, isCompleted),
          ),
          title: Text(
            text,
            style: TextStyle(
              fontSize: 16,
              decoration: isCompleted ? TextDecoration.lineThrough : null,
              color: isCompleted ? Colors.grey : Theme.of(context).colorScheme.onSurface,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
