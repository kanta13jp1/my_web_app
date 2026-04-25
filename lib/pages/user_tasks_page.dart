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
  bool _showCompleted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
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
  }) async {
    setState(() => _saving = true);
    try {
      final response = await _supabase.functions.invoke(
        'tools-hub',
        body: {
          'action': 'wbs.update_user_task_report',
          'id': task['id'],
          'user_report_status': reportStatus,
          'progress': progress,
          if (status != null) 'status': status,
          if (note != null) 'note': note,
        },
      );
      final data = response.data;
      if (data is Map && data['error'] != null) {
        throw Exception(data['error']);
      }
      await _loadTasks();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ユーザータスクを更新しました')),
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
    var reportStatus = '${task['user_report_status'] ?? 'in_progress'}';
    if (reportStatus == 'not_reported') reportStatus = 'in_progress';
    var progress = (task['progress'] as num?)?.round() ?? 0;
    final noteController = TextEditingController(
      text: '${task['user_report_note'] ?? ''}',
    );

    final result = await showDialog<_ReportResult>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('実施状況を報告'),
            content: SizedBox(
              width: 420,
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
                      labelText: '報告メモ',
                      hintText: '実施内容、相手待ち、次に必要な操作など',
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
              FilledButton.icon(
                onPressed: () => Navigator.pop(
                  context,
                  _ReportResult(
                    reportStatus: reportStatus,
                    progress: progress,
                    note: noteController.text.trim(),
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
    if (result == null) return;

    await _submitReport(
      task,
      reportStatus: result.reportStatus,
      progress: result.progress,
      note: result.note,
    );
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
              saving: _saving,
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
  final VoidCallback onStart;
  final VoidCallback onReport;
  final VoidCallback onComplete;

  const _UserTaskCard({
    required this.task,
    required this.dateFormat,
    required this.urgent,
    required this.saving,
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
    final note = '${task['user_report_note'] ?? ''}'.trim();
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
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: saving || completed ? null : onStart,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('着手'),
                ),
                FilledButton.icon(
                  onPressed: saving || completed ? null : onReport,
                  icon: const Icon(Icons.edit_note),
                  label: const Text('状況報告'),
                ),
                OutlinedButton.icon(
                  onPressed: saving || completed ? null : onComplete,
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

class _ReportResult {
  final String reportStatus;
  final int progress;
  final String note;

  const _ReportResult({
    required this.reportStatus,
    required this.progress,
    required this.note,
  });
}
