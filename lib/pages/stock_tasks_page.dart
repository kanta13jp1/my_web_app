import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// 通知機能を使う場合は flutter_local_notifications が必要ですが、
// まずは画面機能を完成させます。

class StockTasksPage extends StatefulWidget {
  const StockTasksPage({super.key});

  @override
  State<StockTasksPage> createState() => _StockTasksPageState();
}

class _StockTasksPageState extends State<StockTasksPage> {
  final _taskController = TextEditingController();
  final _supabase = Supabase.instance.client;

  // タスクリスト
  List<Map<String, dynamic>> _incompleteTasks = [];
  List<Map<String, dynamic>> _completedTasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final data = await _supabase
          .from('stock_tasks')
          .select()
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

  // ※ flutter_local_notifications の導入が必要です
  Future<void> _scheduleSaturdayReminder() async {
    // 1. 通知プラグインの初期化 (main.dart等で行うのが一般的)
    // 2. タイムゾーンの初期化
    // 3. スケジュール登録
    /*
  await flutterLocalNotificationsPlugin.zonedSchedule(
    0,
    '週末ストックの確認',
    '時間がある時にやることリストを確認しましょう！',
    _nextSaturday10AM(), // 次の土曜10時を計算する関数
    const NotificationDetails(...),
    uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
    matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime, // 毎週繰り返す
  );
  */
  }

  Future<void> _addTask() async {
    final title = _taskController.text.trim();
    if (title.isEmpty) return;

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _supabase.from('stock_tasks').insert({
        'user_id': userId,
        'title': title,
        'is_completed': false,
      });
      _taskController.clear();
      _loadTasks(); // リロード
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラー: $e')),
      );
    }
  }

  Future<void> _toggleTask(int id, bool currentValue) async {
    try {
      await _supabase.from('stock_tasks').update({
        'is_completed': !currentValue,
      }).eq('id', id);
      _loadTasks();
    } catch (e) {
      debugPrint('Error toggling task: $e');
    }
  }

  Future<void> _deleteTask(int id) async {
    try {
      await _supabase.from('stock_tasks').delete().eq('id', id);
      _loadTasks();
    } catch (e) {
      debugPrint('Error deleting task: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('週末ストック (Stock Tasks)'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active),
            tooltip: '土曜リマインド設定',
            onPressed: () {
              // ここに通知設定ロジックを入れる（後述）
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('毎週土曜 10:00 の通知をオンにしました')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // タスクリストエリア
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadTasks,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (_incompleteTasks.isEmpty && _completedTasks.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 50),
                            child: Center(
                              child: Text('時間ができたらやりたいことを\n書き留めましょう',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey)),
                            ),
                          ),

                        // 未完了タスク
                        ..._incompleteTasks.map((task) => _buildTaskTile(task)),

                        if (_completedTasks.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text('完了済み',
                                style: TextStyle(color: Colors.grey)),
                          ),
                          const Divider(),
                          // 完了済みタスク
                          ..._completedTasks
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
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _taskController,
                    decoration: const InputDecoration(
                      hintText: '新しいタスクを追加',
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _addTask(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle,
                      size: 32, color: Colors.teal),
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
    final bool isCompleted = task['is_completed'];
    return Dismissible(
      key: ValueKey(task['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _deleteTask(task['id']),
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        color: Colors.white,
        child: ListTile(
          leading: IconButton(
            icon: Icon(
              isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isCompleted ? Colors.teal : Colors.grey,
            ),
            onPressed: () => _toggleTask(task['id'], isCompleted),
          ),
          title: Text(
            task['title'],
            style: TextStyle(
              fontSize: 16,
              decoration: isCompleted ? TextDecoration.lineThrough : null,
              color: isCompleted ? Colors.grey : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}
