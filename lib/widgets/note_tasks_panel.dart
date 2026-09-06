import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/note_task_service.dart';

class NoteTasksPanel extends StatefulWidget {
  const NoteTasksPanel({
    super.key,
    required this.noteId,
    required this.repository,
  });

  final int noteId;
  final NoteTaskRepository repository;

  @override
  State<NoteTasksPanel> createState() => _NoteTasksPanelState();
}

class _NoteTasksPanelState extends State<NoteTasksPanel> {
  List<NoteTask> _tasks = const <NoteTask>[];
  bool _isLoading = true;
  bool _isMutating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadTasks());
  }

  Future<void> _loadTasks() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final tasks = await widget.repository.loadTasks(noteId: widget.noteId);
      if (!mounted) return;
      setState(() {
        _tasks = tasks;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _runMutation(
    Future<void> Function() action, {
    required String successMessage,
  }) async {
    if (_isMutating) return;
    setState(() {
      _isMutating = true;
      _error = null;
    });
    try {
      await action();
      final tasks = await widget.repository.loadTasks(noteId: widget.noteId);
      if (!mounted) return;
      setState(() {
        _tasks = tasks;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isMutating = false;
        });
      }
    }
  }

  Future<DateTime?> _pickDateTime(DateTime? current) async {
    final initial = current?.toLocal() ??
        DateTime.now().toLocal().add(const Duration(days: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (!mounted || date == null) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _showTaskEditor([NoteTask? task]) async {
    final draft = await showDialog<NoteTaskDraft>(
      context: context,
      builder: (_) => _NoteTaskEditorDialog(
        task: task,
        onPickDateTime: _pickDateTime,
      ),
    );
    if (draft == null || !mounted) return;

    await _runMutation(
      () => task == null
          ? widget.repository.createTask(
              noteId: widget.noteId,
              draft: draft,
            )
          : widget.repository.updateTask(task: task, draft: draft),
      successMessage: task == null ? 'タスクを追加しました' : 'タスクを更新しました',
    );
  }

  Future<void> _showAssigneeEditor(NoteTask task) async {
    final draft = await showDialog<_NoteTaskAssigneeDraft>(
      context: context,
      builder: (_) => _NoteTaskAssigneeDialog(task: task),
    );
    if (draft == null || !mounted) return;
    await _runMutation(
      () => widget.repository.assignTask(
        task: task,
        email: draft.remove ? null : draft.email,
        displayName: draft.remove ? null : draft.displayName,
      ),
      successMessage: draft.remove ? '担当者を解除しました' : '担当者を更新しました',
    );
  }

  Future<void> _addReminder(NoteTask task) async {
    final remindAt = await _pickDateTime(task.dueAt);
    if (remindAt == null || !mounted) return;
    await _runMutation(
      () => widget.repository.addReminder(task: task, remindAt: remindAt),
      successMessage: 'リマインダーを追加しました',
    );
  }

  Future<void> _deleteTask(NoteTask task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('タスクを削除しますか？'),
        content: Text('「${task.title}」を削除します。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            key: const Key('note_task_confirm_delete_button'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _runMutation(
      () => widget.repository.deleteTask(task),
      successMessage: 'タスクを削除しました',
    );
  }

  @override
  Widget build(BuildContext context) {
    final completed = _tasks.where((task) => task.isCompleted).length;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 640;
        return Column(
          key: Key(
            isNarrow ? 'note_tasks_panel_narrow' : 'note_tasks_panel_wide',
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'タスク',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          '$completed / ${_tasks.length} 完了',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const Key('note_tasks_refresh_button'),
                    onPressed: _isMutating ? null : _loadTasks,
                    icon: const Icon(Icons.refresh),
                    tooltip: '再読み込み',
                  ),
                  FilledButton.icon(
                    key: const Key('note_task_add_button'),
                    onPressed: _isMutating ? null : () => _showTaskEditor(),
                    icon: const Icon(Icons.add_task),
                    label: Text(isNarrow ? '追加' : 'タスクを追加'),
                  ),
                ],
              ),
            ),
            if (_isMutating) const LinearProgressIndicator(minHeight: 2),
            if (_error != null)
              MaterialBanner(
                content: Text('タスク操作に失敗しました: $_error'),
                actions: [
                  TextButton(
                    onPressed: _loadTasks,
                    child: const Text('再試行'),
                  ),
                ],
              ),
            Expanded(child: _buildBody(isNarrow)),
          ],
        );
      },
    );
  }

  Widget _buildBody(bool isNarrow) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_tasks.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 96),
          Icon(Icons.task_alt, size: 48),
          SizedBox(height: 12),
          Text(
            'このメモにはタスクがありません。',
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 6),
          Text(
            '「追加」から期限・繰り返し・リマインダー付きのタスクを作成できます。',
            textAlign: TextAlign.center,
          ),
        ],
      );
    }
    return RefreshIndicator(
      onRefresh: _loadTasks,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        itemCount: _tasks.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) => _buildTaskCard(
          _tasks[index],
          isNarrow: isNarrow,
        ),
      ),
    );
  }

  Widget _buildTaskCard(NoteTask task, {required bool isNarrow}) {
    final theme = Theme.of(context);
    final dueAt = task.dueAt?.toLocal();
    return Card(
      key: ValueKey('note_task_card_${task.id}'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  key: ValueKey('note_task_checkbox_${task.id}'),
                  value: task.isCompleted,
                  onChanged: _isMutating
                      ? null
                      : (value) => _runMutation(
                            () => widget.repository.setCompleted(
                              task: task,
                              completed: value == true,
                            ),
                            successMessage:
                                value == true ? 'タスクを完了しました' : 'タスクを再開しました',
                          ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      task.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        decoration: task.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  key: ValueKey('note_task_edit_${task.id}'),
                  onPressed: _isMutating || !task.isOwnedByCurrentUser
                      ? null
                      : () => _showTaskEditor(task),
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: '編集',
                ),
                IconButton(
                  key: ValueKey('note_task_assignee_${task.id}'),
                  onPressed: _isMutating || !task.isOwnedByCurrentUser
                      ? null
                      : () => _showAssigneeEditor(task),
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  tooltip: '担当者を設定',
                ),
                IconButton(
                  key: ValueKey('note_task_add_reminder_${task.id}'),
                  onPressed: _isMutating || !task.isOwnedByCurrentUser
                      ? null
                      : () => _addReminder(task),
                  icon: const Icon(Icons.add_alarm_outlined),
                  tooltip: 'リマインダーを追加',
                ),
                IconButton(
                  key: ValueKey('note_task_delete_${task.id}'),
                  onPressed: _isMutating ||
                          task.isImported ||
                          !task.isOwnedByCurrentUser
                      ? null
                      : () => _deleteTask(task),
                  icon: const Icon(Icons.delete_outline),
                  tooltip: task.isImported ? 'Evernote原本の削除完了までは保護されます' : '削除',
                ),
              ],
            ),
            Padding(
              padding: EdgeInsets.only(left: isNarrow ? 8 : 48),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (task.isImported)
                    const Chip(
                      avatar: Icon(Icons.cloud_done_outlined, size: 16),
                      label: Text('Evernote移行'),
                    ),
                  if (task.hasAssignee)
                    Chip(
                      key: ValueKey('note_task_assignee_chip_${task.id}'),
                      avatar: const Icon(Icons.person_outline, size: 16),
                      label: Text(task.assigneeLabel!),
                    ),
                  if (dueAt != null)
                    Chip(
                      avatar: const Icon(Icons.event_outlined, size: 16),
                      label: Text(
                        DateFormat('yyyy/MM/dd HH:mm').format(dueAt),
                      ),
                    ),
                  if (task.recurrence != null)
                    Chip(
                      avatar: const Icon(Icons.repeat, size: 16),
                      label: Text(task.recurrence!),
                    ),
                  if (task.repeatAfterCompletion == true)
                    const Chip(label: Text('完了後に繰り返す')),
                ],
              ),
            ),
            if (task.reminders.isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding: EdgeInsets.only(left: isNarrow ? 8 : 48),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: task.reminders.map((reminder) {
                    final remindAt = reminder.remindAt?.toLocal();
                    return InputChip(
                      key: ValueKey(
                        'note_task_reminder_${reminder.id}',
                      ),
                      avatar: const Icon(Icons.alarm_outlined, size: 16),
                      label: Text(
                        remindAt == null
                            ? '日時未設定'
                            : DateFormat('yyyy/MM/dd HH:mm').format(remindAt),
                      ),
                      onDeleted: _isMutating || reminder.isImported
                          ? null
                          : () => _runMutation(
                                () =>
                                    widget.repository.deleteReminder(reminder),
                                successMessage: 'リマインダーを削除しました',
                              ),
                      deleteButtonTooltipMessage: reminder.isImported
                          ? 'Evernote原本の削除完了までは保護されます'
                          : 'リマインダーを削除',
                    );
                  }).toList(growable: false),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NoteTaskAssigneeDraft {
  const _NoteTaskAssigneeDraft({
    this.email,
    this.displayName,
    this.remove = false,
  });

  final String? email;
  final String? displayName;
  final bool remove;
}

class _NoteTaskAssigneeDialog extends StatefulWidget {
  const _NoteTaskAssigneeDialog({required this.task});

  final NoteTask task;

  @override
  State<_NoteTaskAssigneeDialog> createState() =>
      _NoteTaskAssigneeDialogState();
}

class _NoteTaskAssigneeDialogState extends State<_NoteTaskAssigneeDialog> {
  late final TextEditingController _emailController;
  late final TextEditingController _nameController;
  String? _emailError;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.task.assigneeEmail);
    _nameController =
        TextEditingController(text: widget.task.assigneeDisplayName);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('タスクの担当者'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'メールが本サイトの利用者と一致すると、担当タスクとして'
              '表示されます。元のメモ本文は自動共有されません。',
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('note_task_assignee_email_field'),
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'メールアドレス',
                errorText: _emailError,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('note_task_assignee_name_field'),
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '表示名（任意）',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        if (widget.task.hasAssignee)
          TextButton(
            key: const Key('note_task_assignee_remove_button'),
            onPressed: () => Navigator.pop(
              context,
              const _NoteTaskAssigneeDraft(remove: true),
            ),
            child: const Text('担当解除'),
          ),
        FilledButton(
          key: const Key('note_task_assignee_save_button'),
          onPressed: () {
            final email = _emailController.text.trim();
            final validEmail =
                RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
            if (!validEmail) {
              setState(() {
                _emailError = '有効なメールアドレスを入力してください。';
              });
              return;
            }
            Navigator.pop(
              context,
              _NoteTaskAssigneeDraft(
                email: email,
                displayName: _nameController.text.trim(),
              ),
            );
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}

class _NoteTaskEditorDialog extends StatefulWidget {
  const _NoteTaskEditorDialog({
    required this.task,
    required this.onPickDateTime,
  });

  final NoteTask? task;
  final Future<DateTime?> Function(DateTime? current) onPickDateTime;

  @override
  State<_NoteTaskEditorDialog> createState() => _NoteTaskEditorDialogState();
}

class _NoteTaskEditorDialogState extends State<_NoteTaskEditorDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _recurrenceController;
  DateTime? _dueAt;
  late bool _repeatAfterCompletion;
  String? _titleError;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title ?? '');
    _recurrenceController = TextEditingController(
      text: widget.task?.recurrence ?? '',
    );
    _dueAt = widget.task?.dueAt?.toLocal();
    _repeatAfterCompletion = widget.task?.repeatAfterCompletion ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _recurrenceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dueLabel = _dueAt == null
        ? '期限なし'
        : DateFormat('yyyy/MM/dd HH:mm').format(_dueAt!);
    return AlertDialog(
      title: Text(widget.task == null ? 'タスクを追加' : 'タスクを編集'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const Key('note_task_title_field'),
                controller: _titleController,
                autofocus: true,
                maxLength: 4096,
                decoration: InputDecoration(
                  labelText: 'タスク名',
                  errorText: _titleError,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: Text(dueLabel)),
                  TextButton.icon(
                    key: const Key('note_task_due_button'),
                    onPressed: () async {
                      final selected = await widget.onPickDateTime(_dueAt);
                      if (selected == null || !mounted) return;
                      setState(() {
                        _dueAt = selected;
                      });
                    },
                    icon: const Icon(Icons.event_outlined),
                    label: const Text('期限'),
                  ),
                  if (_dueAt != null)
                    IconButton(
                      key: const Key('note_task_due_clear_button'),
                      onPressed: () {
                        setState(() {
                          _dueAt = null;
                        });
                      },
                      icon: const Icon(Icons.clear),
                      tooltip: '期限を削除',
                    ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('note_task_recurrence_field'),
                controller: _recurrenceController,
                decoration: const InputDecoration(
                  labelText: '繰り返し',
                  hintText: '例: RRULE:FREQ=WEEKLY',
                  helperText: 'EvernoteのRRULEもそのまま編集できます。',
                ),
              ),
              SwitchListTile(
                key: const Key('note_task_repeat_after_completion'),
                contentPadding: EdgeInsets.zero,
                title: const Text('完了後に次回分を繰り返す'),
                value: _repeatAfterCompletion,
                onChanged: (value) {
                  setState(() {
                    _repeatAfterCompletion = value;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          key: const Key('note_task_save_button'),
          onPressed: () {
            final title = _titleController.text.trim();
            if (title.isEmpty) {
              setState(() {
                _titleError = 'タスク名を入力してください。';
              });
              return;
            }
            Navigator.pop(
              context,
              NoteTaskDraft(
                title: title,
                dueAt: _dueAt,
                recurrence: _recurrenceController.text,
                repeatAfterCompletion: _repeatAfterCompletion,
              ),
            );
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
