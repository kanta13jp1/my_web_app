import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ユーザータスクページ — WBS の owner_instance='user' タスク一覧 + 進捗報告
/// Route: /user-tasks
class UserTasksPage extends StatefulWidget {
  const UserTasksPage({super.key});

  @override
  State<UserTasksPage> createState() => _UserTasksPageState();
}

class _UserTasksPageState extends State<UserTasksPage>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late final TabController _tabController;

  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _activeTasks = [];
  List<Map<String, dynamic>> _completedTasks = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTasks();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // Active tasks
      final activeRes = await _supabase.functions.invoke(
        'tools-hub',
        body: {'action': 'wbs.get_user_tasks', 'include_completed': false},
      );
      // Completed tasks (recent 20)
      final completedRes = await _supabase.functions.invoke(
        'tools-hub',
        body: {
          'action': 'wbs.get_user_tasks',
          'include_completed': true,
          'limit': 20,
        },
      );

      final activeData = activeRes.data;
      final completedData = completedRes.data;

      if (activeData is Map && activeData['success'] == true) {
        final all = List<Map<String, dynamic>>.from(
          (activeData['tasks'] as List? ?? []).cast<Map<String, dynamic>>(),
        );
        final completed = List<Map<String, dynamic>>.from(
          (completedData is Map
                  ? (completedData['tasks'] as List? ?? [])
                  : <dynamic>[])
              .cast<Map<String, dynamic>>()
              .where((t) => t['status'] == 'completed'),
        );
        setState(() {
          _activeTasks = all.where((t) => t['status'] != 'completed').toList();
          _completedTasks = completed;
        });
      } else {
        setState(() => _error = '取得に失敗しました');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showReportDialog(Map<String, dynamic> task) async {
    final progressCtrl = TextEditingController(
      text: '${task['progress'] ?? 0}',
    );
    final reportCtrl = TextEditingController(
      text: (task['latest_report'] as Map?)?['report_text'] ?? '',
    );
    final nextCtrl = TextEditingController(
      text: (task['latest_report'] as Map?)?['next_action'] ?? '',
    );
    final blockerCtrl = TextEditingController(
      text: (task['latest_report'] as Map?)?['blockers'] ?? '',
    );
    String selectedStatus = task['status'] ?? 'in_progress';

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            task['title'] ?? '',
            style: const TextStyle(fontSize: 16),
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '[${task['category'] ?? ''}]',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  if (task['notebooklm_note'] != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.blue.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.auto_awesome,
                                size: 14,
                                color: Colors.blue,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'AI 手順メモ (NotebookLM)',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.blue[700],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            task['notebooklm_note'],
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  // Status selector
                  DropdownButtonFormField<String>(
                    value: selectedStatus,
                    decoration: const InputDecoration(
                      labelText: 'ステータス',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'not_started',
                        child: Text('未着手'),
                      ),
                      DropdownMenuItem(
                        value: 'in_progress',
                        child: Text('進行中'),
                      ),
                      DropdownMenuItem(
                        value: 'blocked',
                        child: Text('ブロック中'),
                      ),
                      DropdownMenuItem(
                        value: 'completed',
                        child: Text('完了'),
                      ),
                    ],
                    onChanged: (v) {
                      setDialogState(() {
                        selectedStatus = v ?? selectedStatus;
                        if (v == 'completed') {
                          progressCtrl.text = '100';
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  // Progress
                  TextFormField(
                    controller: progressCtrl,
                    decoration: const InputDecoration(
                      labelText: '進捗 (%)',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  // Report text
                  TextFormField(
                    controller: reportCtrl,
                    decoration: const InputDecoration(
                      labelText: '実施状況・報告コメント',
                      border: OutlineInputBorder(),
                      hintText: '何を実施したか、結果は？',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  // Next action
                  TextFormField(
                    controller: nextCtrl,
                    decoration: const InputDecoration(
                      labelText: '次のアクション',
                      border: OutlineInputBorder(),
                      hintText: '次に何をするか？',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  // Blockers
                  TextFormField(
                    controller: blockerCtrl,
                    decoration: const InputDecoration(
                      labelText: 'ブロッカー・障害',
                      border: OutlineInputBorder(),
                      hintText: '進捗を妨げているものは？',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _submitReport(
                  taskId: task['id'] as String,
                  status: selectedStatus,
                  progress: int.tryParse(progressCtrl.text) ?? 0,
                  reportText: reportCtrl.text,
                  nextAction: nextCtrl.text,
                  blockers: blockerCtrl.text,
                );
              },
              child: const Text('報告する'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitReport({
    required String taskId,
    required String status,
    required int progress,
    required String reportText,
    required String nextAction,
    required String blockers,
  }) async {
    try {
      final res = await _supabase.functions.invoke(
        'tools-hub',
        body: {
          'action': 'wbs.submit_user_task_report',
          'task_id': taskId,
          'status': status,
          'progress': progress,
          'report_text':
              reportText.trim().isNotEmpty ? reportText.trim() : null,
          'next_action':
              nextAction.trim().isNotEmpty ? nextAction.trim() : null,
          'blockers': blockers.trim().isNotEmpty ? blockers.trim() : null,
        },
      );
      final data = res.data;
      if (data is Map && data['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                status == 'completed' ? '✅ タスクを完了しました！' : '📝 進捗を報告しました',
              ),
              backgroundColor:
                  status == 'completed' ? Colors.green : Colors.blue,
            ),
          );
          _loadTasks();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('エラー: ${data?['error'] ?? '不明なエラー'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラー: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _priorityColor(String? priority) {
    switch (priority) {
      case 'high':
        return Colors.red;
      case 'low':
        return Colors.green;
      default:
        return Colors.orange;
    }
  }

  String _priorityLabel(String? priority) {
    switch (priority) {
      case 'high':
        return '高';
      case 'low':
        return '低';
      default:
        return '中';
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'not_started':
        return '未着手';
      case 'in_progress':
        return '進行中';
      case 'blocked':
        return '停止中';
      case 'completed':
        return '完了';
      default:
        return status ?? '';
    }
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final progress = (task['progress'] as num?)?.toInt() ?? 0;
    final priority = task['priority'] as String?;
    final endDate = task['end_date'] as String?;
    final latestReport = task['latest_report'] as Map?;
    final daysLeft = endDate != null
        ? DateTime.parse(endDate).difference(DateTime.now()).inDays
        : null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 1,
      child: InkWell(
        onTap: () => _showReportDialog(task),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _priorityColor(priority).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _priorityLabel(priority),
                      style: TextStyle(
                        fontSize: 11,
                        color: _priorityColor(priority),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      task['title'] ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (daysLeft != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: daysLeft <= 7
                            ? Colors.red.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        daysLeft < 0
                            ? '期限超過'
                            : daysLeft == 0
                                ? '今日期限'
                                : '残${daysLeft}日',
                        style: TextStyle(
                          fontSize: 11,
                          color: daysLeft <= 7 ? Colors.red : Colors.grey[600],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              // Category + status
              Row(
                children: [
                  Text(
                    '[${task['category'] ?? ''}]',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _statusLabel(task['status'] as String?),
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ],
              ),
              // Progress bar
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: progress / 100,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        progress >= 100
                            ? Colors.green
                            : progress >= 50
                                ? Colors.blue
                                : Colors.orange,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$progress%',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
              // Latest report
              if (latestReport != null &&
                  latestReport['report_text'] != null) ...[
                const SizedBox(height: 6),
                Text(
                  '最新報告: ${latestReport['report_text']}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              // NotebookLM note indicator
              if (task['notebooklm_note'] != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      size: 12,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'AI 手順メモあり',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue[600],
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 4),
              // Tap hint
              Text(
                'タップして進捗を報告する →',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.primary,
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
      appBar: AppBar(
        title: const Text('ユーザータスク'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '更新',
            onPressed: _loadTasks,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              text: '未完了 (${_activeTasks.length})',
              icon: const Icon(Icons.pending_actions),
            ),
            Tab(
              text: '完了済み (${_completedTasks.length})',
              icon: const Icon(Icons.check_circle_outline),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(_error!),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _loadTasks,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: 未完了タスク
                    _activeTasks.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: 48,
                                  color: Colors.green,
                                ),
                                SizedBox(height: 16),
                                Text('手動対応が必要なタスクはありません 🎉'),
                              ],
                            ),
                          )
                        : Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                color: Colors.amber.withOpacity(0.1),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.person,
                                      size: 16,
                                      color: Colors.amber,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'あなたの手動操作が必要なタスクが ${_activeTasks.length} 件あります。タスクをタップして進捗を報告してください。',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: ListView.builder(
                                  itemCount: _activeTasks.length,
                                  itemBuilder: (ctx, i) =>
                                      _buildTaskCard(_activeTasks[i]),
                                ),
                              ),
                            ],
                          ),
                    // Tab 2: 完了済み
                    _completedTasks.isEmpty
                        ? const Center(child: Text('完了済みタスクはありません'))
                        : ListView.builder(
                            itemCount: _completedTasks.length,
                            itemBuilder: (ctx, i) =>
                                _buildTaskCard(_completedTasks[i]),
                          ),
                  ],
                ),
    );
  }
}
