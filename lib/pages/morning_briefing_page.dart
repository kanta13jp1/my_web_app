import 'package:flutter/material.dart';
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
  late final Stream<List<Map<String, dynamic>>> _todosStream;

  @override
  void initState() {
    super.initState();
    _todosStream = Supabase.instance.client
        .from('daily_todos')
        .stream(primaryKey: ['id']).order('created_at', ascending: false);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkOverdueTasks();
    });
  }

  @override
  void dispose() {
    _todoController.dispose();
    super.dispose();
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
          .update({'created_at': now}).in_('id', ids);

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

  Future<void> _addTodo() async {
    final text = _todoController.text.trim();
    if (text.isEmpty) return;

    try {
      await Supabase.instance.client.from('daily_todos').insert({
        'task': text,
        'is_completed': false,
      });
      _todoController.clear();
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

  Future<void> _deleteTodo(String id) async {
    await Supabase.instance.client.from('daily_todos').delete().eq('id', id);
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
                      hintText: '新しいタスクを追加...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onSubmitted: (_) => _addTodo(),
                  ),
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
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _todosStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('エラー: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final todos = snapshot.data!;
                if (todos.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.task_alt, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('タスクはありません'),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: todos.length,
                  itemBuilder: (context, index) {
                    final todo = todos[index];
                    final isCompleted = todo['is_completed'] as bool;
                    final id = todo['id'] as String;
                    final task = todo['task'] as String;

                    return ListTile(
                      leading: Checkbox(
                        value: isCompleted,
                        onChanged: (val) => _toggleTodo(id, isCompleted, task),
                      ),
                      title: Text(
                        task,
                        style: TextStyle(
                          decoration: isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          color: isCompleted ? Colors.grey : null,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deleteTodo(id),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}