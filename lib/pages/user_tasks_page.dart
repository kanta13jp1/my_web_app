import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// WBS tasks that require manual user action.
///
/// Routes:
/// - /user-tasks
/// - /wbs-user-tasks
class UserTasksPage extends StatefulWidget {
  const UserTasksPage({super.key});

  @override
  State<UserTasksPage> createState() => _UserTasksPageState();
}

class _UserTasksPageState extends State<UserTasksPage> {
  final _supabase = Supabase.instance.client;
  final _dateFormat = DateFormat('yyyy/MM/dd');

  List<Map<String, dynamic>> _tasks = const [];
  bool _loading = true;
  bool _saving = false;
  String? _assistTaskId;
  bool _showCompleted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    if (_supabase.auth.currentUser == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'tools-hub',
        body: {
          'action': 'wbs.get_user_tasks',
          'include_completed': _showCompleted,
          'limit': 100,
        },
      );
      final data = response.data;
      if (data is Map && data['error'] != null) {
        throw Exception(data['error']);
      }
      final rows = List<Map<String, dynamic>>.from(
        ((data as Map?)?['tasks'] as List? ?? const []),
      );
      rows.sort(_compareTasks);
      if (mounted) {
        setState(() {
          _tasks = rows;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _compareTasks(Map<String, dynamic> a, Map<String, dynamic> b) {
    const statusRank = {
      'blocked': 0,
      'pending': 1,
      'in_progress': 2,
      'completed': 3,
    };
    final statusCmp =
        (statusRank[a['status']] ?? 9).compareTo(statusRank[b['status']] ?? 9);
    if (statusCmp != 0) return statusCmp;

    const priorityRank = {'high': 0, 'medium': 1, 'low': 2};
    final priorityCmp = (priorityRank[a['priority']] ?? 9)
        .compareTo(priorityRank[b['priority']] ?? 9);
    if (priorityCmp != 0) return priorityCmp;

    final aDue = DateTime.tryParse('${a['end_date'] ?? ''}');
    final bDue = DateTime.tryParse('${b['end_date'] ?? ''}');
    if (aDue == null && bDue != null) return 1;
    if (aDue != null && bDue == null) return -1;
    if (aDue != null && bDue != null) {
      final dueCmp = aDue.compareTo(bDue);
      if (dueCmp != 0) return dueCmp;
    }
    return '${a['title'] ?? ''}'.compareTo('${b['title'] ?? ''}');
  }

  Future<void> _submitReport(
    Map<String, dynamic> task, {
    required String reportStatus,
    required int progress,
    String? status,
    String? note,
    String? blockers,
    String? nextAction,
  }) async {
    setState(() => _saving = true);
    try {
      final response = await _supabase.functions.invoke(
        'tools-hub',
        body: {
          'action': 'wbs.user_task_report',
          'task_id': task['id'],
          'progress': progress,
          'status': status ?? reportStatus,
          if (note != null && note.isNotEmpty) 'report_text': note,
          if (blockers != null && blockers.isNotEmpty) 'blockers': blockers,
          if (nextAction != null && nextAction.isNotEmpty)
            'next_action': nextAction,
        },
      );
      final data = response.data;
      if (data is Map && data['error'] != null) {
        throw Exception(data['error']);
      }
      await _loadTasks();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ 報告を記録しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新に失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openReportDialog(Map<String, dynamic> task) async {
    final latestReport = task['latest_report'] as Map?;
    var reportStatus = '${task['user_report_status'] ?? 'in_progress'}';
    if (reportStatus == 'not_reported') reportStatus = 'in_progress';
    var progress = (task['progress'] as num?)?.round() ?? 0;
    final noteController = TextEditingController(
      text: '${latestReport?['report_text'] ?? task['user_report_note'] ?? ''}',
    );
    final blockersController = TextEditingController(
      text: '${latestReport?['blockers'] ?? ''}',
    );
    final nextActionController = TextEditingController(
      text: '${latestReport?['next_action'] ?? ''}',
    );

    final result = await showDialog<_ReportResult>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('実施状況を報告'),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${task['title'] ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: reportStatus,
                      decoration: const InputDecoration(labelText: '状況'),
                      items: const [
                        DropdownMenuItem(
                          value: 'in_progress',
                          child: Text('対応中'),
                        ),
                        DropdownMenuItem(
                          value: 'waiting',
                          child: Text('相手待ち'),
                        ),
                        DropdownMenuItem(
                          value: 'blocked',
                          child: Text('詰まりあり'),
                        ),
                        DropdownMenuItem(
                          value: 'completed',
                          child: Text('完了'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          reportStatus = value;
                          if (value == 'completed') progress = 100;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Text('進捗 $progress%'),
                    Slider(
                      value: progress.toDouble(),
                      min: 0,
                      max: 100,
                      divisions: 20,
                      label: '$progress%',
                      onChanged: reportStatus == 'completed'
                          ? null
                          : (value) => setDialogState(
                                () => progress = value.round(),
                              ),
                    ),
                    TextField(
                      controller: noteController,
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: '実施状況',
                        hintText: '実施内容、進めた手順など',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: blockersController,
                      minLines: 2,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: '詰まり・ブロッカー',
                        hintText: '困っていること、不明点など（省略可）',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nextActionController,
                      minLines: 2,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: '次のアクション',
                        hintText: '次に何をするか（省略可）',
                      ),
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
              FilledButton.icon(
                onPressed: () => Navigator.pop(
                  context,
                  _ReportResult(
                    reportStatus: reportStatus,
                    progress: progress,
                    note: noteController.text.trim(),
                    blockers: blockersController.text.trim(),
                    nextAction: nextActionController.text.trim(),
                  ),
                ),
                icon: const Icon(Icons.send_outlined),
                label: const Text('報告する'),
              ),
            ],
          );
        },
      ),
    );

    noteController.dispose();
    blockersController.dispose();
    nextActionController.dispose();
    if (result == null) return;

    await _submitReport(
      task,
      reportStatus: result.reportStatus,
      progress: result.progress,
      status: result.reportStatus,
      note: result.note,
      blockers: result.blockers,
      nextAction: result.nextAction,
    );
  }

  Future<void> _openAiAssist(
    Map<String, dynamic> task, {
    required String mode,
  }) async {
    final taskId = '${task['id'] ?? ''}'.trim();
    if (taskId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('タスクIDを取得できませんでした')),
      );
      return;
    }

    setState(() {
      _assistTaskId = taskId;
    });

    try {
      final response = await _supabase.functions.invoke(
        'tools-hub',
        body: {
          'action': 'wbs.user_task_ai_assist',
          'task_id': taskId,
          'mode': mode,
        },
      );
      final data = response.data;
      if (data is Map && data['error'] != null) {
        throw Exception(data['error']);
      }
      final payload =
          data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
      final guidanceRaw = payload['guidance'];
      final guidance = guidanceRaw is Map
          ? Map<String, dynamic>.from(guidanceRaw)
          : <String, dynamic>{};

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => _AiAssistDialog(
          taskTitle: '${payload['task_title'] ?? task['title'] ?? ''}',
          mode: mode,
          guidance: guidance,
          generatedBy:
              '${payload['generated_by'] ?? guidance['generated_by'] ?? ''}',
          parentTask: task,
          onTasksRegistered: _loadTasks,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI支援の生成に失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _assistTaskId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeTasks = _tasks.where((task) => task['status'] != 'completed');
    final urgentTasks = activeTasks.where(_isUrgent).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('WBS ユーザータスク'),
        actions: [
          IconButton(
            tooltip: '更新',
            onPressed: _loading ? null : _loadTasks,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadTasks,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SummaryPanel(
              total: activeTasks.length,
              urgent: urgentTasks,
              saving: _saving || _assistTaskId != null,
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              value: _showCompleted,
              onChanged: (value) {
                setState(() => _showCompleted = value);
                _loadTasks();
              },
              title: const Text('完了済みも表示'),
              secondary: const Icon(Icons.done_all_outlined),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _MessagePanel(
                icon: Icons.error_outline,
                title: '読み込みに失敗しました',
                message: _error!,
              )
            else if (_tasks.isEmpty)
              const _MessagePanel(
                icon: Icons.task_alt,
                title: 'ユーザー対応タスクはありません',
                message: '手動操作が必要なWBSタスクが割り振られると、ここに表示されます。',
              )
            else
              ..._tasks.map(
                (task) => _UserTaskCard(
                  task: task,
                  dateFormat: _dateFormat,
                  urgent: _isUrgent(task),
                  saving: _saving,
                  aiBusy: _assistTaskId == '${task['id'] ?? ''}',
                  onBreakdown: () => _openAiAssist(task, mode: 'breakdown'),
                  onProcedure: () => _openAiAssist(task, mode: 'procedure'),
                  onStart: () => _submitReport(
                    task,
                    reportStatus: 'in_progress',
                    progress: (task['progress'] as num?)?.round() ?? 10,
                    status: 'in_progress',
                  ),
                  onReport: () => _openReportDialog(task),
                  onComplete: () => _submitReport(
                    task,
                    reportStatus: 'completed',
                    progress: 100,
                    status: 'completed',
                    note: 'サイト上のユーザータスクUIから完了報告',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool _isUrgent(Map<String, dynamic> task) {
    final due = DateTime.tryParse('${task['end_date'] ?? ''}');
    if (due == null) return false;
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    return due.difference(startOfToday).inDays <= 7;
  }
}

class _SummaryPanel extends StatelessWidget {
  final int total;
  final int urgent;
  final bool saving;

  const _SummaryPanel({
    required this.total,
    required this.urgent,
    required this.saving,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.person_pin_circle_outlined, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '手動操作が必要なWBSタスク',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  Text('未完了 $total 件 / 期限7日以内 $urgent 件'),
                ],
              ),
            ),
            if (saving)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
      ),
    );
  }
}

class _UserTaskCard extends StatelessWidget {
  final Map<String, dynamic> task;
  final DateFormat dateFormat;
  final bool urgent;
  final bool saving;
  final bool aiBusy;
  final VoidCallback onBreakdown;
  final VoidCallback onProcedure;
  final VoidCallback onStart;
  final VoidCallback onReport;
  final VoidCallback onComplete;

  const _UserTaskCard({
    required this.task,
    required this.dateFormat,
    required this.urgent,
    required this.saving,
    required this.aiBusy,
    required this.onBreakdown,
    required this.onProcedure,
    required this.onStart,
    required this.onReport,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final status = '${task['status'] ?? 'pending'}';
    final reportStatus = '${task['user_report_status'] ?? 'not_reported'}';
    final progress = (task['progress'] as num?)?.round() ?? 0;
    final due = DateTime.tryParse('${task['end_date'] ?? ''}');
    final latestReport = task['latest_report'] as Map?;
    final note = (latestReport?['report_text'] as String? ??
            task['user_report_note'] as String? ??
            '')
        .trim();
    final nextAction = (latestReport?['next_action'] as String? ?? '').trim();
    final completed = status == 'completed';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  completed ? Icons.task_alt : Icons.assignment_ind_outlined,
                  color: completed
                      ? Colors.green
                      : urgent
                          ? Colors.deepOrange
                          : Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${task['title'] ?? ''}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _Chip(label: '${task['category'] ?? 'WBS'}'),
                _Chip(label: _statusLabel(status)),
                _Chip(label: _reportLabel(reportStatus)),
                if (due != null)
                  _Chip(
                    label: '期限 ${dateFormat.format(due)}',
                    danger: urgent && !completed,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress / 100,
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 6),
            Text('進捗 $progress%'),
            if (note.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                note,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (nextAction.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 12,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      nextAction,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: saving || completed || aiBusy ? null : onStart,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('着手'),
                ),
                OutlinedButton.icon(
                  onPressed: saving || completed || aiBusy ? null : onBreakdown,
                  icon: const Icon(Icons.account_tree_outlined),
                  label: const Text('タスク分割'),
                ),
                OutlinedButton.icon(
                  onPressed: saving || completed || aiBusy ? null : onProcedure,
                  icon: const Icon(Icons.menu_book_outlined),
                  label: const Text('手順を見る'),
                ),
                FilledButton.icon(
                  onPressed: saving || completed || aiBusy ? null : onReport,
                  icon: const Icon(Icons.edit_note),
                  label: const Text('状況報告'),
                ),
                OutlinedButton.icon(
                  onPressed: saving || completed || aiBusy ? null : onComplete,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('完了'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(String status) => switch (status) {
        'in_progress' => 'WBS: 進行中',
        'blocked' => 'WBS: 停止中',
        'completed' => 'WBS: 完了',
        _ => 'WBS: 未着手',
      };

  String _reportLabel(String status) => switch (status) {
        'in_progress' => '報告: 対応中',
        'waiting' => '報告: 相手待ち',
        'blocked' => '報告: 詰まりあり',
        'completed' => '報告: 完了',
        _ => '報告: 未報告',
      };
}

class _Chip extends StatelessWidget {
  final String label;
  final bool danger;

  const _Chip({required this.label, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final color =
        danger ? Colors.deepOrange : Theme.of(context).colorScheme.primary;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _MessagePanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _MessagePanel({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(icon, size: 42, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _AiAssistDialog extends StatefulWidget {
  final String taskTitle;
  final String mode;
  final Map<String, dynamic> guidance;
  final String generatedBy;
  final Map<String, dynamic> parentTask;
  final VoidCallback onTasksRegistered;

  const _AiAssistDialog({
    required this.taskTitle,
    required this.mode,
    required this.guidance,
    required this.generatedBy,
    required this.parentTask,
    required this.onTasksRegistered,
  });

  @override
  State<_AiAssistDialog> createState() => _AiAssistDialogState();
}

class _AiAssistDialogState extends State<_AiAssistDialog> {
  bool _isRegistering = false;
  int _registerProgress = 0;
  bool _isSavingNote = false;

  Future<void> _saveToNote(
    String summary,
    List<Map<String, dynamic>> subtasks,
    List<Map<String, dynamic>> steps,
    List<String> prerequisites,
    List<String> blockers,
    List<String> checklist,
  ) async {
    setState(() => _isSavingNote = true);
    final buf = StringBuffer();
    if (summary.isNotEmpty) buf.writeln('## AIの見立て\n$summary\n');
    final isBreakdown = widget.mode == 'breakdown';
    if (isBreakdown && subtasks.isNotEmpty) {
      buf.writeln('## サブタスク');
      for (var i = 0; i < subtasks.length; i++) {
        final t = _aiText(subtasks[i]['title']);
        final d =
            _aiText(subtasks[i]['description'] ?? subtasks[i]['goal'] ?? '');
        buf.writeln('${i + 1}. **$t**${d.isNotEmpty ? '\n   $d' : ''}');
      }
      buf.writeln();
    } else if (!isBreakdown && steps.isNotEmpty) {
      buf.writeln('## 手順');
      for (var i = 0; i < steps.length; i++) {
        final t = _aiText(steps[i]['step'] ?? steps[i]['title'] ?? '');
        buf.writeln('${i + 1}. $t');
      }
      buf.writeln();
    }
    if (prerequisites.isNotEmpty) {
      buf.writeln('## 事前確認\n${prerequisites.map((e) => '- $e').join('\n')}\n');
    }
    if (blockers.isNotEmpty) {
      buf.writeln('## 詰まりやすい点\n${blockers.map((e) => '- $e').join('\n')}\n');
    }
    if (checklist.isNotEmpty) {
      buf.writeln(
        '## 完了前チェック\n${checklist.map((e) => '- [ ] $e').join('\n')}\n',
      );
    }

    try {
      await Supabase.instance.client.functions.invoke(
        'tools-hub',
        body: {
          'action': 'note.add',
          'title': 'AIアシスト: ${widget.taskTitle}',
          'content': buf.toString().trim(),
          'tags': ['ai-assist', isBreakdown ? 'breakdown' : 'procedure'],
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ ノートに保存しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('⚠ 保存に失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingNote = false);
    }
  }

  Future<void> _registerAllSubtasks(
    List<Map<String, dynamic>> subtasks,
  ) async {
    setState(() {
      _isRegistering = true;
      _registerProgress = 0;
    });
    int success = 0;
    int failed = 0;
    final errors = <String>[];
    final supabase = Supabase.instance.client;
    final parent = widget.parentTask;

    for (var i = 0; i < subtasks.length; i++) {
      final s = subtasks[i];
      try {
        await supabase.functions.invoke(
          'tools-hub',
          body: {
            'action': 'wbs.add_task',
            'category': parent['category'],
            'category_icon': parent['category_icon'],
            'category_order': parent['category_order'],
            'title':
                '${parent['title'] ?? widget.taskTitle} :: ${_aiText(s['title']).isEmpty ? '小タスク${i + 1}' : _aiText(s['title'])}',
            'description': _buildSubtaskDescription(s),
            'instance': parent['instance'],
            'owner_instance': parent['owner_instance'],
            'priority': parent['priority'] ?? 'medium',
            'status': 'pending',
            'progress': 0,
            'milestone_code': parent['milestone_code'],
          },
        );
        success++;
      } catch (e) {
        failed++;
        errors.add('${i + 1}. ${_aiText(s['title'])}: $e');
      }
      if (mounted) setState(() => _registerProgress = i + 1);
    }

    if (!mounted) return;
    setState(() => _isRegistering = false);

    final messenger = ScaffoldMessenger.of(context);
    if (failed == 0) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('✅ $success 件のサブタスクを登録しました'),
          duration: const Duration(seconds: 3),
        ),
      );
      Navigator.pop(context);
      widget.onTasksRegistered();
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '⚠ $success 件成功 / $failed 件失敗\n${errors.join('\n')}',
          ),
          duration: const Duration(seconds: 8),
        ),
      );
    }
  }

  String _buildSubtaskDescription(Map<String, dynamic> s) {
    final parts = <String>[];
    final rawDesc = _aiText(s['description']);
    final desc = rawDesc.isNotEmpty ? rawDesc : _aiText(s['goal']);
    final criteria = _aiText(s['done_when'] ?? s['completion_criteria'] ?? '');
    final minutes = s['estimated_minutes'];

    if (desc.isNotEmpty) parts.add(desc);
    if (criteria.isNotEmpty) parts.add('完了条件: $criteria');
    if (minutes != null) parts.add('目安: $minutes 分');
    parts.add('---');
    parts.add('親タスク: ${widget.parentTask['title'] ?? widget.taskTitle}');
    parts.add(
      'AI分割で自動登録 (${DateTime.now().toIso8601String().substring(0, 16)})',
    );
    return parts.join('\n\n');
  }

  @override
  Widget build(BuildContext context) {
    final isBreakdown = widget.mode == 'breakdown';
    final summary = _aiText(widget.guidance['summary']);
    final subtasks = _aiMapList(widget.guidance['subtasks']);
    final steps = _aiMapList(widget.guidance['steps']);
    final prerequisites = _aiStringList(widget.guidance['prerequisites']);
    final blockers = _aiStringList(widget.guidance['blockers']);
    final checklist = _aiStringList(widget.guidance['checklist']);
    final source = widget.generatedBy.trim().isNotEmpty
        ? widget.generatedBy.trim()
        : _aiText(widget.guidance['generated_by']);

    return AlertDialog(
      title: Text(isBreakdown ? 'AIタスク分割' : 'AI実施手順'),
      content: SizedBox(
        width: 680,
        child: SingleChildScrollView(
          child: SelectionArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.taskTitle,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if (summary.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _assistCard(
                    context,
                    icon: Icons.auto_awesome,
                    title: 'AIの見立て',
                    child: Text(summary),
                  ),
                ],
                const SizedBox(height: 12),
                if (isBreakdown)
                  _subtasksSection(context, subtasks)
                else
                  _procedureSection(context, steps),
                _listSection(
                  context,
                  icon: Icons.fact_check_outlined,
                  title: '事前に確認すること',
                  items: prerequisites,
                ),
                _listSection(
                  context,
                  icon: Icons.warning_amber_outlined,
                  title: '詰まりやすい点',
                  items: blockers,
                ),
                _listSection(
                  context,
                  icon: Icons.checklist_outlined,
                  title: '完了前チェック',
                  items: checklist,
                ),
                if (source.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'generated by $source',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isRegistering ? null : () => Navigator.pop(context),
          child: const Text('閉じる'),
        ),
        OutlinedButton.icon(
          icon: _isSavingNote
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.bookmark_add_outlined, size: 16),
          label: const Text('ノートに保存'),
          onPressed: (_isRegistering || _isSavingNote)
              ? null
              : () => _saveToNote(
                    summary,
                    subtasks,
                    steps,
                    prerequisites,
                    blockers,
                    checklist,
                  ),
        ),
        if (isBreakdown && subtasks.isNotEmpty)
          FilledButton.icon(
            icon: _isRegistering
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.add_task, size: 16),
            label: Text(
              _isRegistering
                  ? '登録中... ($_registerProgress/${subtasks.length})'
                  : '全部登録 (${subtasks.length} 件)',
            ),
            onPressed:
                _isRegistering ? null : () => _registerAllSubtasks(subtasks),
          ),
      ],
    );
  }

  Widget _subtasksSection(
    BuildContext context,
    List<Map<String, dynamic>> subtasks,
  ) {
    if (subtasks.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(context, Icons.account_tree_outlined, '小さなタスク'),
        const SizedBox(height: 8),
        for (final entry in subtasks.asMap().entries) ...[
          _assistCard(
            context,
            title:
                '${entry.key + 1}. ${_aiText(entry.value['title']).isEmpty ? '小タスク' : _aiText(entry.value['title'])}',
            subtitle: _aiText(entry.value['goal']),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _inlineList(_aiStringList(entry.value['steps'])),
                if (_aiText(entry.value['done_when']).isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('完了条件: ${_aiText(entry.value['done_when'])}'),
                ],
                if (entry.value['estimated_minutes'] != null) ...[
                  const SizedBox(height: 4),
                  Text('目安: ${entry.value['estimated_minutes']}分'),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _procedureSection(
    BuildContext context,
    List<Map<String, dynamic>> steps,
  ) {
    if (steps.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(context, Icons.menu_book_outlined, '実施手順'),
        const SizedBox(height: 8),
        for (final entry in steps.asMap().entries) ...[
          _assistCard(
            context,
            title:
                '${entry.key + 1}. ${_aiText(entry.value['title']).isEmpty ? '手順' : _aiText(entry.value['title'])}',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_aiText(entry.value['detail']).isNotEmpty)
                  Text(_aiText(entry.value['detail'])),
                if (_aiText(entry.value['expected_result']).isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('到達状態: ${_aiText(entry.value['expected_result'])}'),
                ],
                if (_aiText(entry.value['caution']).isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('注意: ${_aiText(entry.value['caution'])}'),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _listSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required List<String> items,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(context, icon, title),
          const SizedBox(height: 6),
          _inlineList(items),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 6),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _inlineList(List<String> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('・$item'),
          ),
      ],
    );
  }

  Widget _assistCard(
    BuildContext context, {
    IconData? icon,
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(8),
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.45),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            if (subtitle != null && subtitle.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subtitle.trim(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

String _aiText(Object? value) => '${value ?? ''}'.trim();

List<String> _aiStringList(Object? value) {
  if (value is List) {
    return value
        .map((item) => _aiText(item))
        .where((item) => item.isNotEmpty)
        .toList();
  }
  final single = _aiText(value);
  return single.isEmpty ? const [] : [single];
}

List<Map<String, dynamic>> _aiMapList(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

class _ReportResult {
  final String reportStatus;
  final int progress;
  final String note;
  final String blockers;
  final String nextAction;

  const _ReportResult({
    required this.reportStatus,
    required this.progress,
    required this.note,
    required this.blockers,
    required this.nextAction,
  });
}
