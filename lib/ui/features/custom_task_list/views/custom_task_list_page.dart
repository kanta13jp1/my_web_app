import 'package:flutter/material.dart';

import '../../../../data/repositories/custom_task_list_repository.dart';
import '../../../../domain/models/custom_task_list.dart';
import '../view_models/custom_task_list_view_model.dart';

class CustomTaskListPage extends StatefulWidget {
  final CustomTaskListViewModel? viewModel;

  const CustomTaskListPage({super.key, this.viewModel});

  @override
  State<CustomTaskListPage> createState() => _CustomTaskListPageState();
}

class _CustomTaskListPageState extends State<CustomTaskListPage> {
  late final CustomTaskListViewModel _viewModel;
  late final bool _ownsViewModel;
  final _goalController = TextEditingController();
  final _situationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ownsViewModel = widget.viewModel == null;
    _viewModel = widget.viewModel ??
        CustomTaskListViewModel(repository: CustomTaskListRepositoryImpl());
    _restore();
  }

  Future<void> _restore() async {
    await _viewModel.restore();
    if (!mounted) return;
    _goalController.text = _viewModel.goal;
    _situationController.text = _viewModel.situation;
  }

  @override
  void dispose() {
    _goalController.dispose();
    _situationController.dispose();
    if (_ownsViewModel) _viewModel.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    FocusScope.of(context).unfocus();
    final success = await _viewModel.generate(
      goal: _goalController.text,
      situation: _situationController.text,
    );
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_viewModel.items.length}件のタスクを生成しました。')),
      );
    }
  }

  Future<void> _editTask(CustomTaskItem task) async {
    final title = await showDialog<String>(
      context: context,
      builder: (context) => _EditTaskDialog(initialTitle: task.title),
    );
    if (title != null) await _viewModel.editTask(task.id, title);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI カスタムタスクリスト')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ListenableBuilder(
                listenable: _viewModel,
                builder: (context, _) => LayoutBuilder(
                  builder: (context, constraints) {
                    final input = _InputPanel(
                      goalController: _goalController,
                      situationController: _situationController,
                      isLoading: _viewModel.isLoading,
                      onGenerate: _generate,
                    );
                    final list = _TaskListPanel(
                      viewModel: _viewModel,
                      onEdit: _editTask,
                    );
                    final isWide = constraints.maxWidth >= 760;
                    return SingleChildScrollView(
                      key: Key(
                        isWide
                            ? 'custom_task_wide_layout'
                            : 'custom_task_compact_layout',
                      ),
                      child: isWide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(width: 350, child: input),
                                const SizedBox(width: 16),
                                Expanded(child: list),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                input,
                                const SizedBox(height: 16),
                                list,
                              ],
                            ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EditTaskDialog extends StatefulWidget {
  final String initialTitle;

  const _EditTaskDialog({required this.initialTitle});

  @override
  State<_EditTaskDialog> createState() => _EditTaskDialogState();
}

class _EditTaskDialogState extends State<_EditTaskDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialTitle);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('タスクを編集'),
      content: TextField(
        key: const Key('custom_task_edit_field'),
        controller: _controller,
        autofocus: true,
        maxLength: 120,
        decoration: const InputDecoration(
          labelText: 'アクション',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          key: const Key('custom_task_edit_save_button'),
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('保存'),
        ),
      ],
    );
  }
}

class _InputPanel extends StatelessWidget {
  final TextEditingController goalController;
  final TextEditingController situationController;
  final bool isLoading;
  final VoidCallback onGenerate;

  const _InputPanel({
    required this.goalController,
    required this.situationController,
    required this.isLoading,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: colorScheme.primary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'あなた専用の行動リストを作る',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '目標と今の状況を伝えると、AIが実行しやすいアクションへ分解します。',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            TextField(
              key: const Key('custom_task_goal_field'),
              controller: goalController,
              minLines: 2,
              maxLines: 4,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: '達成したい目標',
                hintText: '例: 来週までに引っ越し準備を終える',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('custom_task_situation_field'),
              controller: situationController,
              minLines: 3,
              maxLines: 6,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: '現状・使える時間・制約',
                hintText: '例: 平日は30分だけ。荷物が多く、車は使えない',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 4),
            FilledButton.icon(
              key: const Key('custom_task_generate_button'),
              onPressed: isLoading ? null : onGenerate,
              icon: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.playlist_add_check_circle_outlined),
              label: Text(isLoading ? 'AIが作成中…' : 'タスクリストを生成'),
            ),
            const SizedBox(height: 10),
            Text(
              '入力内容はタスクリスト生成のためAIに送信されます。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskListPanel extends StatelessWidget {
  final CustomTaskListViewModel viewModel;
  final ValueChanged<CustomTaskItem> onEdit;

  const _TaskListPanel({required this.viewModel, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final items = viewModel.items;
    final colorScheme = Theme.of(context).colorScheme;
    final progress =
        items.isEmpty ? 0.0 : viewModel.completedCount / items.length;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                const Text(
                  'カスタムタスクリスト',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                if (items.isNotEmpty)
                  Chip(
                    avatar: const Icon(Icons.task_alt, size: 18),
                    label: Text(
                      '${viewModel.completedCount} / ${items.length} 完了',
                    ),
                  ),
              ],
            ),
            if (items.isNotEmpty) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(value: progress),
            ],
            if (viewModel.errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                key: const Key('custom_task_error_message'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  viewModel.errorMessage!,
                  style: TextStyle(color: colorScheme.onErrorContainer),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (items.isEmpty)
              Container(
                key: const Key('custom_task_empty_state'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 40,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.checklist_rounded,
                      size: 48,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'まだタスクはありません',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '目標または現状を入力して、3件以上の具体的なアクションを生成します。',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              )
            else
              ...items.map(
                (task) => _TaskRow(
                  key: ValueKey(task.id),
                  task: task,
                  onToggle: () => viewModel.toggleTask(task.id),
                  onEdit: () => onEdit(task),
                  onDelete: () => viewModel.deleteTask(task.id),
                ),
              ),
            if (items.isNotEmpty && viewModel.source.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '生成元: ${viewModel.source}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  final CustomTaskItem task;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TaskRow({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              Checkbox(
                key: Key('custom_task_checkbox_${task.id}'),
                value: task.isCompleted,
                onChanged: (_) => onToggle(),
                semanticLabel: '${task.title}を完了にする',
              ),
              Expanded(
                child: Text(
                  task.title,
                  style: TextStyle(
                    decoration:
                        task.isCompleted ? TextDecoration.lineThrough : null,
                    color: task.isCompleted
                        ? colorScheme.onSurfaceVariant
                        : colorScheme.onSurface,
                  ),
                ),
              ),
              IconButton(
                key: Key('custom_task_edit_${task.id}'),
                tooltip: '編集',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                key: Key('custom_task_delete_${task.id}'),
                tooltip: '削除',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
