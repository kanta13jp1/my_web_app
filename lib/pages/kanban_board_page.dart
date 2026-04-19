import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// カンバンボードページ
///
/// Notion のボードビューに相当。
/// `someday_tasks` テーブルをカンバン形式で表示する。
/// - Todo: is_completed=false, is_important=false
/// - 進行中: is_completed=false, is_important=true
/// - 完了: is_completed=true
class KanbanBoardPage extends StatefulWidget {
  const KanbanBoardPage({super.key});

  @override
  State<KanbanBoardPage> createState() => _KanbanBoardPageState();
}

class _KanbanBoardPageState extends State<KanbanBoardPage> {
  final _supabase = Supabase.instance.client;
  final _addController = TextEditingController();
  bool _loading = true;
  List<Map<String, dynamic>> _tasks = [];

  static const _colTodo = 'todo';
  static const _colDoing = 'doing';
  static const _colDone = 'done';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final data = await _supabase
          .from('someday_tasks')
          .select('id, task, is_completed, is_important, category, created_at')
          .eq('user_id', uid)
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _tasks = List<Map<String, dynamic>>.from(data as List);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _columnOf(Map<String, dynamic> task) {
    if (task['is_completed'] == true) return _colDone;
    if (task['is_important'] == true) return _colDoing;
    return _colTodo;
  }

  List<Map<String, dynamic>> _tasksFor(String col) =>
      _tasks.where((t) => _columnOf(t) == col).toList();

  Future<void> _moveTo(String id, String col) async {
    try {
      final update = switch (col) {
        _colTodo => {'is_completed': false, 'is_important': false},
        _colDoing => {'is_completed': false, 'is_important': true},
        _colDone => {'is_completed': true, 'is_important': false},
        _ => <String, dynamic>{},
      };
      await _supabase.from('someday_tasks').update(update).eq('id', id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新に失敗しました: $e')),
      );
    }
  }

  Future<void> _addTask(String text) async {
    if (text.isEmpty) return;
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await _supabase.from('someday_tasks').insert({
        'user_id': uid,
        'task': text,
        'is_completed': false,
        'is_important': false,
        'category': 'action',
      });
      _addController.clear();
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('追加に失敗しました: $e')),
      );
    }
  }

  Future<void> _delete(String id) async {
    try {
      await _supabase.from('someday_tasks').delete().eq('id', id).select();
      await _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('カンバンボード'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: '更新',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Add task bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _addController,
                          decoration: InputDecoration(
                            hintText: '新しいタスクを追加...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            isDense: true,
                          ),
                          textInputAction: TextInputAction.done,
                          onSubmitted: _addTask,
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('追加'),
                        onPressed: () => _addTask(_addController.text.trim()),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Kanban columns
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 600;
                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildColumn(
                                _colTodo,
                                'To Do',
                                Icons.radio_button_unchecked,
                                const Color(0xFF6366F1),
                                isDark,
                              ),
                            ),
                            Expanded(
                              child: _buildColumn(
                                _colDoing,
                                '進行中',
                                Icons.play_circle_outline,
                                const Color(0xFFF59E0B),
                                isDark,
                              ),
                            ),
                            Expanded(
                              child: _buildColumn(
                                _colDone,
                                '完了',
                                Icons.check_circle_outline,
                                const Color(0xFF10B981),
                                isDark,
                              ),
                            ),
                          ],
                        );
                      }
                      return ListView(
                        padding: const EdgeInsets.only(bottom: 24),
                        children: [
                          _buildColumn(
                            _colTodo,
                            'To Do',
                            Icons.radio_button_unchecked,
                            const Color(0xFF6366F1),
                            isDark,
                          ),
                          _buildColumn(
                            _colDoing,
                            '進行中',
                            Icons.play_circle_outline,
                            const Color(0xFFF59E0B),
                            isDark,
                          ),
                          _buildColumn(
                            _colDone,
                            '完了',
                            Icons.check_circle_outline,
                            const Color(0xFF10B981),
                            isDark,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildColumn(
    String col,
    String label,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    final tasks = _tasksFor(col);
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? color.withAlpha(15) : color.withAlpha(10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Column header
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color,
                    height: 1.5,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: color.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${tasks.length}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Task cards
          ...tasks.map((t) => _buildCard(t, col, color, isDark)),
          if (tasks.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'タスクなし',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? const Color(0xFF9E9E9E)
                        : const Color(0xFFBDBDBD),
                    height: 1.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCard(
    Map<String, dynamic> task,
    String currentCol,
    Color color,
    bool isDark,
  ) {
    final text = task['task']?.toString() ?? '';
    final id = task['id']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark
              ? const Color(0xFF616161)
              : Theme.of(context).colorScheme.surfaceContainerHigh,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.drag_indicator,
              size: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white : Colors.black87,
                  decoration: currentCol == _colDone
                      ? TextDecoration.lineThrough
                      : null,
                  height: 1.5,
                ),
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              padding: EdgeInsets.zero,
              itemBuilder: (_) => [
                if (currentCol != _colTodo)
                  const PopupMenuItem(
                    value: 'todo',
                    child: Row(
                      children: [
                        Icon(
                          Icons.radio_button_unchecked,
                          size: 16,
                          color: Color(0xFF6366F1),
                        ),
                        SizedBox(width: 8),
                        Text('To Do に戻す'),
                      ],
                    ),
                  ),
                if (currentCol != _colDoing)
                  const PopupMenuItem(
                    value: 'doing',
                    child: Row(
                      children: [
                        Icon(
                          Icons.play_circle_outline,
                          size: 16,
                          color: Color(0xFFF59E0B),
                        ),
                        SizedBox(width: 8),
                        Text('進行中に移動'),
                      ],
                    ),
                  ),
                if (currentCol != _colDone)
                  const PopupMenuItem(
                    value: 'done',
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 16,
                          color: Color(0xFF10B981),
                        ),
                        SizedBox(width: 8),
                        Text('完了にする'),
                      ],
                    ),
                  ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 16, color: Colors.red),
                      SizedBox(width: 8),
                      Text(
                        '削除',
                        style: TextStyle(
                          color: Colors.red,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              onSelected: (action) {
                if (action == 'delete') {
                  _delete(id);
                } else {
                  _moveTo(id, action);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
