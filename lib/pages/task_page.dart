import 'package:flutter/material.dart';
import '../main.dart'; // supabaseクライアント用
import '../models/task_model.dart';
import 'package:intl/intl.dart';

class TaskPage extends StatefulWidget {
  const TaskPage({super.key});

  @override
  State<TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage> {
  List<TaskModel> _tasks = [];
  bool _isLoading = true;

  // ユーザーが意識すべき「掟」
  final List<String> _principles = [
    '長い説明を処理しきれない\n👉 長い説明を処理する',
    '締切ギリギリまで動けない\n👉 締切がある作業は今すぐ着手',
    '単純作業ほど凡ミスが増える\n👉 絶対にミスがないよう注意する',
    '感情や疲労が顔にそのまま出る\n👉 感情や疲労は顔に出さない',
    'タスクが重なると思考が停止する\n👉 タスクが重なった場合は必ずメモ',
    '言わなくていい一言を足してしまう\n👉 必要以外言わない',
    '距離感を測れず、私的な話をしすぎる\n👉 必要以外言わない',
  ];

  @override
  void initState() {
    super.initState();
    _fetchTasks();
  }

  Future<void> _fetchTasks() async {
    setState(() => _isLoading = true);
    try {
      final response = await supabase
          .from('tasks')
          .select()
          .eq('is_completed', false)
          .order('created_at');

      final data = response as List<dynamic>;
      final tasks = data.map((json) => TaskModel.fromJson(json)).toList();

      // A(Deadline) -> B(Daily) -> C(Routine) -> D(Reward)
      tasks.sort((a, b) {
        final priorityComparison = a.priorityScore.compareTo(b.priorityScore);
        if (priorityComparison != 0) {
          return priorityComparison;
        }
        if (a.deadline != null && b.deadline != null) {
          return a.deadline!.compareTo(b.deadline!);
        }
        return a.createdAt.compareTo(b.createdAt);
      });

      setState(() {
        _tasks = tasks;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラーが発生しました: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addTask(
    String title,
    String description,
    TaskType type,
    DateTime? deadline,
  ) async {
    try {
      final userId = supabase.auth.currentUser!.id;
      final newTask = TaskModel(
        id: '', // DB側で生成
        userId: userId,
        title: title,
        description: description,
        taskType: type,
        deadline: deadline,
        isCompleted: false,
        createdAt: DateTime.now(),
      );

      await supabase.from('tasks').insert(newTask.toJson());
      _fetchTasks();
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('登録エラー: $e')),
        );
      }
    }
  }

  Future<void> _completeTask(TaskModel task) async {
    try {
      if (task.taskType == TaskType.reward) {
        final hasHigherPriority = _tasks.any((t) =>
            t.taskType == TaskType.deadline ||
            t.taskType == TaskType.daily ||
            t.taskType == TaskType.routine);

        if (hasHigherPriority) {
          _showLockedDialog();
          return;
        }
      }

      await supabase
          .from('tasks')
          .update({'is_completed': true}).eq('id', task.id);
      _fetchTasks();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新エラー: $e')),
        );
      }
    }
  }

  void _showLockedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('甘えを捨てろ'),
          ],
        ),
        content: const Text(
          'やるべきこと（A, B, C）が残っています。\n楽しみは全てが終わった後だ。',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('作業に戻る',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Color _getTypeColor(TaskType type) {
    switch (type) {
      case TaskType.deadline:
        return Colors.red.shade700;
      case TaskType.daily:
        return Colors.orange.shade800;
      case TaskType.routine:
        return Colors.blue.shade700;
      case TaskType.reward:
        return Colors.green.shade700;
    }
  }

  String _getTypeLabel(TaskType type) {
    switch (type) {
      case TaskType.deadline:
        return 'A. 締切厳守';
      case TaskType.daily:
        return 'B. 毎日必須';
      case TaskType.routine:
        return 'C. 自己研鑽';
      case TaskType.reward:
        return 'D. 報酬';
    }
  }

  // ■ 掟ヘッダー（デザイン改善版）
  Widget _buildPrinciplesCard() {
    final todaySeed = DateTime.now().day;
    final principle = _principles[todaySeed % _principles.length];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey.shade900, Colors.black],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.psychology, color: Colors.redAccent.shade100),
              const SizedBox(width: 8),
              Text(
                '今日の意識改革',
                style: TextStyle(
                  color: Colors.redAccent.shade100,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            principle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ■ タスクカード（デザイン改善版）
  Widget _buildTaskCard(TaskModel task, bool isTopTask) {
    bool isLocked = false;
    if (task.taskType == TaskType.reward) {
      final hasHigherPriority =
          _tasks.any((t) => t.taskType != TaskType.reward);
      isLocked = hasHigherPriority;
    }

    final typeColor = _getTypeColor(task.taskType);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isTopTask
            ? Border.all(color: typeColor, width: 2)
            : Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 左側のカラーバー
              Container(
                width: 6,
                color: isLocked ? Colors.grey : typeColor,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ラベルと締切
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isLocked
                                  ? Colors.grey.shade100
                                  : typeColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _getTypeLabel(task.taskType),
                              style: TextStyle(
                                color: isLocked ? Colors.grey : typeColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (task.deadline != null)
                            Row(
                              children: [
                                Icon(Icons.timer_outlined,
                                    size: 14,
                                    color: task.isOverdue
                                        ? Colors.red
                                        : Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  DateFormat('MM/dd HH:mm')
                                      .format(task.deadline!),
                                  style: TextStyle(
                                    color: task.isOverdue
                                        ? Colors.red
                                        : Colors.grey.shade600,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // タイトル
                      Text(
                        task.title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isLocked ? Colors.grey : Colors.black87,
                          decoration:
                              isLocked ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      // トップタスクのみのアドバイス表示
                      if (isTopTask && !isLocked) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade100),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('💡', style: TextStyle(fontSize: 16)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  task.adviceMessage,
                                  style: TextStyle(
                                    color: Colors.red.shade900,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // 完了ボタンエリア
              Container(
                width: 60,
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: Colors.grey.shade100),
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _completeTask(task),
                    child: Center(
                      child: isLocked
                          ? const Icon(Icons.lock, color: Colors.grey)
                          : Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: const Icon(Icons.check,
                                  size: 20, color: Colors.grey),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title:
            const Text('優先順位厳守', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchTasks,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildPrinciplesCard(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _tasks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.task_alt,
                                size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text(
                              'タスクなし\n素晴らしい！やるべきことは全て完了しました。',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 100),
                        itemCount: _tasks.length,
                        itemBuilder: (context, index) {
                          return _buildTaskCard(_tasks[index], index == 0);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTaskDialog(),
        backgroundColor: Colors.black,
        elevation: 4,
        label: const Row(
          children: [
            Icon(Icons.add_task, color: Colors.white),
            SizedBox(width: 8),
            Text('思考停止でタスク登録',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  void _showAddTaskDialog() {
    final titleController = TextEditingController();
    TaskType selectedType = TaskType.deadline;
    DateTime? selectedDeadline;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('タスクを追加',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: titleController,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'タスク内容',
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('種類を選択 (優先度順)',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey)),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<TaskType>(
                    value: selectedType,
                    decoration: InputDecoration(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: TaskType.deadline,
                          child: Text('🔴 A: 締切あり (最優先)')),
                      DropdownMenuItem(
                          value: TaskType.daily,
                          child: Text('🟠 B: 毎日やる (生活)')),
                      DropdownMenuItem(
                          value: TaskType.routine,
                          child: Text('🔵 C: 定期/学習 (投資)')),
                      DropdownMenuItem(
                          value: TaskType.reward,
                          child: Text('🟢 D: 快楽/報酬 (最後)')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedType = value!;
                        if (selectedType != TaskType.deadline) {
                          selectedDeadline = null;
                        }
                      });
                    },
                  ),
                  if (selectedType == TaskType.deadline) ...[
                    const SizedBox(height: 20),
                    ListTile(
                      tileColor: Colors.grey.shade100,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      title: Text(
                        selectedDeadline == null
                            ? '締切日時を設定 (必須)'
                            : DateFormat('yyyy/MM/dd HH:mm')
                                .format(selectedDeadline!),
                        style: TextStyle(
                            color: selectedDeadline == null
                                ? Colors.grey
                                : Colors.black),
                      ),
                      trailing:
                          const Icon(Icons.calendar_today, color: Colors.red),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2030),
                        );
                        if (date != null) {
                          if (!context.mounted) return;
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                          );
                          if (time != null) {
                            setState(() {
                              selectedDeadline = DateTime(
                                date.year,
                                date.month,
                                date.day,
                                time.hour,
                                time.minute,
                              );
                            });
                          }
                        }
                      },
                    ),
                  ],
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        if (titleController.text.isEmpty) return;
                        if (selectedType == TaskType.deadline &&
                            selectedDeadline == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Aタイプのタスクには締切日時が必須です')));
                          return;
                        }
                        _addTask(
                          titleController.text,
                          '',
                          selectedType,
                          selectedDeadline,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('追加する',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// 拡張メソッド: 期限切れチェック用
extension TaskModelExtension on TaskModel {
  bool get isOverdue {
    if (deadline == null) return false;
    return DateTime.now().isAfter(deadline!);
  }
}
