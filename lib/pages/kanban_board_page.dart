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

class _KanbanColumnMeta {
  final String id;
  final String label;
  final IconData icon;
  final Color color;

  const _KanbanColumnMeta({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
  });
}

class _KanbanBoardPageState extends State<KanbanBoardPage> {
  final _supabase = Supabase.instance.client;
  final _addController = TextEditingController();
  bool _loading = true;
  bool _requiresLogin = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _tasks = [];

  static const _colTodo = 'todo';
  static const _colDoing = 'doing';
  static const _colDone = 'done';

  static const List<_KanbanColumnMeta> _columns = <_KanbanColumnMeta>[
    _KanbanColumnMeta(
      id: _colTodo,
      label: 'To Do',
      icon: Icons.radio_button_unchecked,
      color: Color(0xFF6366F1),
    ),
    _KanbanColumnMeta(
      id: _colDoing,
      label: '進行中',
      icon: Icons.play_circle_outline,
      color: Color(0xFFF59E0B),
    ),
    _KanbanColumnMeta(
      id: _colDone,
      label: '完了',
      icon: Icons.check_circle_outline,
      color: Color(0xFF10B981),
    ),
  ];

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
    if (!mounted) return;
    setState(() {
      _requiresLogin = false;
      _errorMessage = null;
      _loading = true;
    });
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) {
      if (!mounted) return;
      setState(() {
        _requiresLogin = true;
        _tasks = [];
        _loading = false;
      });
      return;
    }
    try {
      final data = await _supabase
          .from('someday_tasks')
          .select('id, task, is_completed, is_important, category, created_at')
          .eq('user_id', uid)
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _tasks = List<Map<String, dynamic>>.from(data as List);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'タスクの読み込みに失敗しました。';
        _loading = false;
      });
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
    if (id.isEmpty) return;
    try {
      final update = switch (col) {
        _colTodo => {'is_completed': false, 'is_important': false},
        _colDoing => {'is_completed': false, 'is_important': true},
        _colDone => {'is_completed': true, 'is_important': false},
        _ => <String, dynamic>{},
      };
      if (update.isEmpty) return;
      await _supabase.from('someday_tasks').update(update).eq('id', id);
      if (!mounted) return;
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('更新に失敗しました。')),
      );
    }
  }

  Future<void> _addTask(String text, {String column = _colTodo}) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('タスクを追加するにはログインしてください。')),
      );
      return;
    }
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    try {
      await _supabase.from('someday_tasks').insert({
        'user_id': uid,
        'task': trimmed,
        'is_completed': column == _colDone,
        'is_important': column == _colDoing,
        'category': 'action',
      });
      if (!mounted) return;
      _addController.clear();
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('追加に失敗しました。')),
      );
    }
  }

  Future<void> _showAddTaskDialog(String column, String label) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('タスクを追加するにはログインしてください。')),
      );
      return;
    }
    var draft = '';
    final entered = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$label にタスクを追加'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'タスク名を入力...',
            border: OutlineInputBorder(),
          ),
          textInputAction: TextInputAction.done,
          onChanged: (value) => draft = value,
          onSubmitted: (value) => Navigator.of(ctx).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(draft),
            child: const Text('追加'),
          ),
        ],
      ),
    );
    if (!mounted || entered == null) return;
    await _addTask(entered, column: column);
  }

  Future<void> _delete(String id) async {
    if (id.isEmpty) return;
    try {
      await _supabase.from('someday_tasks').delete().eq('id', id).select();
      if (!mounted) return;
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('削除に失敗しました。')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_requiresLogin) {
      return KanbanSignedOutState(
        onLogin: () => Navigator.of(context).pushNamed('/login'),
      );
    }
    if (_errorMessage != null) {
      return KanbanErrorState(
        message: _errorMessage!,
        onRetry: _load,
      );
    }
    return Column(
      children: [
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
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 600;
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final col in _columns)
                      Expanded(
                        child: _buildColumnView(col, scrollable: true),
                      ),
                  ],
                );
              }
              return ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  for (final col in _columns)
                    _buildColumnView(col, scrollable: false),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildColumnView(
    _KanbanColumnMeta col, {
    required bool scrollable,
  }) {
    return KanbanColumnView(
      id: col.id,
      label: col.label,
      icon: col.icon,
      color: col.color,
      tasks: _tasksFor(col.id),
      scrollable: scrollable,
      onAdd: () => _showAddTaskDialog(col.id, col.label),
      onMove: _moveTo,
      onDelete: _delete,
    );
  }
}

String _safeKanbanString(dynamic value) => value?.toString() ?? '';

class KanbanColumnView extends StatelessWidget {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final List<Map<String, dynamic>> tasks;
  final bool scrollable;
  final VoidCallback onAdd;
  final void Function(String id, String nextStatus) onMove;
  final ValueChanged<String> onDelete;

  const KanbanColumnView({
    super.key,
    required this.id,
    required this.label,
    required this.color,
    required this.tasks,
    required this.scrollable,
    required this.onAdd,
    required this.onMove,
    required this.onDelete,
    this.icon = Icons.view_kanban_outlined,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? color.withAlpha(15) : color.withAlpha(10);
    final emptyColor = theme.colorScheme.onSurfaceVariant;
    final mainSize = scrollable ? MainAxisSize.max : MainAxisSize.min;
    final cards = _buildChildren(context, emptyColor, isDark);

    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Column(
        mainAxisSize: mainSize,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(icon, size: 16, color: color),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          label,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: color,
                            height: 1.5,
                          ),
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
                IconButton(
                  icon: Icon(Icons.add, size: 18, color: color),
                  tooltip: '$label に追加',
                  onPressed: onAdd,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (scrollable)
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 8),
                children: cards,
              ),
            )
          else ...[
            ...cards,
            if (tasks.isNotEmpty) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildChildren(
    BuildContext context,
    Color emptyColor,
    bool isDark,
  ) {
    if (tasks.isEmpty) {
      return <Widget>[
        Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              'タスクなし',
              style: TextStyle(
                fontSize: 12,
                color: emptyColor,
                height: 1.5,
              ),
            ),
          ),
        ),
      ];
    }
    return tasks.map((t) => _buildCard(context, t, isDark)).toList();
  }

  Widget _buildCard(
    BuildContext context,
    Map<String, dynamic> task,
    bool isDark,
  ) {
    final text = _safeKanbanString(task['task']);
    final taskId = _safeKanbanString(task['id']);
    final colorScheme = Theme.of(context).colorScheme;
    final cardBgColor = isDark ? const Color(0xFF1F2937) : Colors.white;
    final lightBorder = colorScheme.surfaceContainerHigh;
    final borderColor = isDark ? const Color(0xFF616161) : lightBorder;
    final textColor = isDark ? Colors.white : Colors.black87;
    final textDeco = id == 'done' ? TextDecoration.lineThrough : null;

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
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
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 12,
                  color: textColor,
                  decoration: textDeco,
                  height: 1.5,
                ),
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
              padding: EdgeInsets.zero,
              itemBuilder: (_) => [
                if (id != 'todo')
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
                if (id != 'doing')
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
                if (id != 'done')
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
                      Icon(
                        Icons.delete_outline,
                        size: 16,
                        color: Color(0xFFE53935),
                      ),
                      SizedBox(width: 8),
                      Text(
                        '削除',
                        style: TextStyle(
                          color: Color(0xFFE53935),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              onSelected: (action) {
                if (action == 'delete') {
                  onDelete(taskId);
                } else {
                  onMove(taskId, action);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class KanbanSignedOutState extends StatelessWidget {
  final VoidCallback onLogin;

  const KanbanSignedOutState({
    super.key,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    return Center(
      key: const Key('kanban_signed_out_state'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.lock_outline,
              size: 48,
              color: Color(0xFF6366F1),
            ),
            const SizedBox(height: 16),
            Text(
              'ログインするとカンバンボードを利用できます。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: textColor,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onLogin,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.login, size: 18),
                  SizedBox(width: 8),
                  Text('ログイン'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class KanbanErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const KanbanErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    return Center(
      key: const Key('kanban_error_state'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: Color(0xFFE53935),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: textColor,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('再試行'),
            ),
          ],
        ),
      ),
    );
  }
}
