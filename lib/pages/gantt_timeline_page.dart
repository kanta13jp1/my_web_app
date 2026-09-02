import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_web_app/utils/tab_route_url_sync.dart';

/// ガントチャート・タイムラインページ
/// gantt-timeline-manager Edge Function と連携
/// Notion Timeline / Microsoft Project 競合機能を自前実装
class GanttTimelinePage extends StatefulWidget {
  const GanttTimelinePage({super.key});

  @override
  State<GanttTimelinePage> createState() => _GanttTimelinePageState();
}

class _GanttTimelinePageState extends State<GanttTimelinePage>
    with SingleTickerProviderStateMixin, TabRouteUrlSync {
  @override
  List<String> get tabUrlSlugs =>
      const <String>['projects', 'timeline', 'critical-path'];

  @override
  TabController get tabUrlController => _tabController;

  final _supabase = Supabase.instance.client;
  late TabController _tabController;

  bool _isLoading = false;
  String? _errorMessage;
  List<dynamic> _projects = [];
  String? _selectedProjectId;
  List<dynamic> _tasks = [];
  List<dynamic> _milestones = [];
  Map<String, dynamic>? _criticalPath;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchProjects();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchProjects() async {
    if (_supabase.auth.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final res = await _supabase.functions
          .invoke('enterprise-hub', body: {'action': 'gantt.list'});
      final data = res.data;
      if (data is Map<String, dynamic> && data['tasks'] is List) {
        setState(() => _projects = data['tasks'] as List);
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'プロジェクト取得に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchProjectDetails(String projectId) async {
    setState(() {
      _isLoading = true;
      _selectedProjectId = projectId;
    });
    try {
      final taskRes = await _supabase.functions.invoke(
        'enterprise-hub',
        body: {'action': 'gantt.list'},
      );
      if (mounted) {
        final taskData = taskRes.data as Map<String, dynamic>?;
        setState(() {
          _tasks = (taskData?['tasks'] as List?) ?? [];
          _milestones = [];
          _criticalPath = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = '詳細取得に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createProject() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    DateTime? startDate;
    DateTime? endDate;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('新規プロジェクト'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'プロジェクト名'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: '説明'),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        icon: const Icon(Icons.date_range),
                        label: Text(
                          startDate == null
                              ? '開始日'
                              : '${startDate!.year}/${startDate!.month}/${startDate!.day}',
                        ),
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: ctx,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (d != null) setDlgState(() => startDate = d);
                        },
                      ),
                    ),
                    const Text('〜'),
                    Expanded(
                      child: TextButton.icon(
                        icon: const Icon(Icons.date_range),
                        label: Text(
                          endDate == null
                              ? '終了日'
                              : '${endDate!.year}/${endDate!.month}/${endDate!.day}',
                        ),
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: ctx,
                            initialDate:
                                DateTime.now().add(const Duration(days: 30)),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (d != null) setDlgState(() => endDate = d);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                await _supabase.functions.invoke(
                  'enterprise-hub',
                  body: {
                    'action': 'gantt.create_task',
                    'name': nameCtrl.text.trim(),
                    'description': descCtrl.text.trim(),
                    'start_date': startDate?.toIso8601String(),
                    'end_date': endDate?.toIso8601String(),
                    'is_project': true,
                  },
                );
                await _fetchProjects();
              },
              child: const Text('作成'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addTask() async {
    if (_selectedProjectId == null) return;
    final nameCtrl = TextEditingController();
    final durationCtrl = TextEditingController(text: '3');
    DateTime? startDate;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('タスク追加'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'タスク名'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: durationCtrl,
                  decoration: const InputDecoration(
                    labelText: '期間（日数）',
                    suffixText: '日',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  icon: const Icon(Icons.date_range),
                  label: Text(
                    startDate == null
                        ? '開始日を選択'
                        : '${startDate!.year}/${startDate!.month}/${startDate!.day}',
                  ),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (d != null) setDlgState(() => startDate = d);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                await _supabase.functions.invoke(
                  'enterprise-hub',
                  body: {
                    'action': 'gantt.create_task',
                    'project_id': _selectedProjectId,
                    'name': nameCtrl.text.trim(),
                    'duration_days': int.tryParse(durationCtrl.text) ?? 3,
                    'start_date':
                        (startDate ?? DateTime.now()).toIso8601String(),
                  },
                );
                await _fetchProjectDetails(_selectedProjectId!);
              },
              child: const Text('追加'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addMilestone() async {
    if (_selectedProjectId == null) return;
    final nameCtrl = TextEditingController();
    DateTime? dueDate;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('マイルストーン追加'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'マイルストーン名'),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  icon: const Icon(Icons.flag),
                  label: Text(
                    dueDate == null
                        ? '期限日を選択'
                        : '${dueDate!.year}/${dueDate!.month}/${dueDate!.day}',
                  ),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.now().add(const Duration(days: 14)),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (d != null) setDlgState(() => dueDate = d);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                await _supabase.functions.invoke(
                  'enterprise-hub',
                  body: {
                    'action': 'gantt.create_task',
                    'project_id': _selectedProjectId,
                    'is_milestone': true,
                    'name': nameCtrl.text.trim(),
                    'due_date': (dueDate ??
                            DateTime.now().add(const Duration(days: 14)))
                        .toIso8601String(),
                  },
                );
                await _fetchProjectDetails(_selectedProjectId!);
              },
              child: const Text('追加'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ガントチャート'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.folder_open), text: 'プロジェクト'),
            Tab(icon: Icon(Icons.view_timeline), text: 'タイムライン'),
            Tab(icon: Icon(Icons.account_tree), text: 'クリティカルパス'),
          ],
        ),
        actions: [
          if (_selectedProjectId != null && _tabController.index == 1)
            IconButton(
              icon: const Icon(Icons.add_task),
              tooltip: 'タスク追加',
              onPressed: _addTask,
            ),
          if (_selectedProjectId != null && _tabController.index == 1)
            IconButton(
              icon: const Icon(Icons.flag),
              tooltip: 'マイルストーン追加',
              onPressed: _addMilestone,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '更新',
            onPressed: _selectedProjectId != null
                ? () => _fetchProjectDetails(_selectedProjectId!)
                : _fetchProjects,
          ),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: _createProject,
              icon: const Icon(Icons.add),
              label: const Text('プロジェクト作成'),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Color(0xFFE53935),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Color(0xFFE53935),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _fetchProjects,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildProjectsTab(),
                    _buildTimelineTab(),
                    _buildCriticalPathTab(),
                  ],
                ),
    );
  }

  Widget _buildProjectsTab() {
    if (_projects.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.view_timeline_outlined,
              size: 64,
              color: Color(0xFF9CA3AF),
            ),
            const SizedBox(height: 16),
            const Text(
              'プロジェクトがありません',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF9CA3AF),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'ガントチャートで進捗を可視化しましょう',
              style: TextStyle(
                color: Color(0xFF9CA3AF),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _createProject,
              icon: const Icon(Icons.add),
              label: const Text('プロジェクトを作成'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _projects.length,
      itemBuilder: (context, index) {
        final project = _projects[index] as Map<String, dynamic>;
        final name = project['name'] as String? ?? '無名プロジェクト';
        final description = project['description'] as String? ?? '';
        final startDate = project['start_date'] as String?;
        final endDate = project['end_date'] as String?;
        final taskCount = (project['task_count'] as int?) ?? 0;
        final isSelected = _selectedProjectId == project['project_id'];

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : null,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : const Color(0xFF607D8B),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'P',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  height: 1.5,
                ),
              ),
            ),
            title: Text(
              name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : null,
                height: 1.5,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (description.isNotEmpty)
                  Text(
                    description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (startDate != null || endDate != null)
                  Text(
                    '${startDate != null ? _formatDate(startDate) : "?"} 〜 ${endDate != null ? _formatDate(endDate) : "?"}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9CA3AF),
                      height: 1.5,
                    ),
                  ),
                Text(
                  'タスク: $taskCount件',
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
            trailing: isSelected
                ? const Icon(Icons.check_circle, color: Color(0xFF4CAF50))
                : const Icon(Icons.chevron_right),
            onTap: () {
              _tabController.animateTo(1);
              _fetchProjectDetails(project['project_id'] as String);
            },
          ),
        );
      },
    );
  }

  Widget _buildTimelineTab() {
    if (_selectedProjectId == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.view_timeline_outlined,
              size: 64,
              color: Color(0xFF9CA3AF),
            ),
            SizedBox(height: 16),
            Text(
              'プロジェクトを選択してください',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF9CA3AF),
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _fetchProjectDetails(_selectedProjectId!),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Milestones section
            if (_milestones.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(
                    Icons.flag,
                    color: Color(0xFFFFC107),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'マイルストーン (${_milestones.length}件)',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ..._milestones
                  .map((ms) => _buildMilestoneRow(ms as Map<String, dynamic>)),
              const Divider(height: 24),
            ],

            // Tasks section
            Row(
              children: [
                const Icon(
                  Icons.task,
                  color: Color(0xFF3D5AFE),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'タスク (${_tasks.length}件)',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    height: 1.5,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('タスク追加'),
                  onPressed: _addTask,
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (_tasks.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    'タスクがありません\n右上の＋ボタンから追加してください',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF9CA3AF),
                      height: 1.5,
                    ),
                  ),
                ),
              )
            else
              ..._tasks.map(
                (task) => _buildGanttTaskRow(task as Map<String, dynamic>),
              ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildMilestoneRow(Map<String, dynamic> ms) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = ms['name'] as String? ?? '';
    final dueDate = ms['due_date'] as String?;
    final isPast = dueDate != null
        ? DateTime.tryParse(dueDate)?.isBefore(DateTime.now()) ?? false
        : false;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isPast
          ? (isDark ? const Color(0xFF3A1010) : const Color(0xFFFFEBEE))
          : (isDark ? const Color(0xFF1A1400) : const Color(0xFFFFF8E1)),
      child: ListTile(
        dense: true,
        leading: Icon(
          Icons.flag,
          color: isPast ? const Color(0xFFE53935) : const Color(0xFFFFA000),
        ),
        title: Text(
          name,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            height: 1.5,
          ),
        ),
        trailing: dueDate != null
            ? Chip(
                label: Text(
                  _formatDate(dueDate),
                  style: TextStyle(
                    fontSize: 12,
                    color: isPast
                        ? const Color(0xFFE53935)
                        : const Color(0xFFFF8F00),
                    height: 1.5,
                  ),
                ),
                backgroundColor: isPast
                    ? (isDark
                        ? const Color(0xFF3A1010)
                        : const Color(0xFFFFCDD2))
                    : (isDark
                        ? const Color(0xFF2A1800)
                        : const Color(0xFFFFECB3)),
              )
            : null,
      ),
    );
  }

  Widget _buildGanttTaskRow(Map<String, dynamic> task) {
    final name = task['name'] as String? ?? '';
    final startDate = task['start_date'] as String?;
    final durationDays = (task['duration_days'] as num?)?.toInt() ?? 1;
    final progress = (task['progress'] as num?)?.toDouble() ?? 0.0;
    final status = task['status'] as String? ?? 'pending';

    Color statusColor;
    switch (status) {
      case 'done':
        statusColor = const Color(0xFF4CAF50);
      case 'in_progress':
        statusColor = const Color(0xFF3D5AFE);
      case 'blocked':
        statusColor = const Color(0xFFE53935);
      default:
        statusColor = const Color(0xFF9CA3AF);
    }

    String statusLabel;
    switch (status) {
      case 'done':
        statusLabel = '完了';
      case 'in_progress':
        statusLabel = '進行中';
      case 'blocked':
        statusLabel = 'ブロック';
      default:
        statusLabel = '未着手';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Gantt bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 12,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHigh,
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  startDate != null ? _formatDate(startDate) : '未設定',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9CA3AF),
                    height: 1.5,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.timer,
                  size: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  '$durationDays日間',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9CA3AF),
                    height: 1.5,
                  ),
                ),
                const Spacer(),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCriticalPathTab() {
    if (_selectedProjectId == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_tree_outlined,
              size: 64,
              color: Color(0xFF9CA3AF),
            ),
            SizedBox(height: 16),
            Text(
              'プロジェクトを選択してください',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF9CA3AF),
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }

    if (_criticalPath == null) {
      return const Center(child: Text('クリティカルパスデータがありません'));
    }

    final items = (_criticalPath!['criticalPath'] as List?) ?? [];
    final totalTasks = _criticalPath!['totalTasks'] as int? ?? 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: const Color(0xFFFBE9E7),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(
                  Icons.account_tree,
                  color: Color(0xFFFF6B35),
                  size: 32,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'クリティカルパス分析',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFF6B35),
                        height: 1.5,
                      ),
                    ),
                    Text(
                      '全タスク $totalTasks件 | 遅延リスク上位 ${items.length}件',
                      style: const TextStyle(
                        color: Color(0xFFE64A19),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (items.isEmpty)
          const Center(
            child: Text(
              'タスクが登録されていません\nタイムラインタブからタスクを追加してください',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF9CA3AF),
                height: 1.5,
              ),
            ),
          )
        else
          ...items.asMap().entries.map((entry) {
            final rank = entry.key + 1;
            final item = entry.value as Map<String, dynamic>;
            final taskName = item['name'] as String? ?? '';
            final endDate = item['endDate'] as String?;
            final duration = item['duration'] as int? ?? 0;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: rank == 1
                      ? const Color(0xFFE53935)
                      : rank <= 3
                          ? const Color(0xFFFF6B35)
                          : const Color(0xFF607D8B),
                  child: Text(
                    '$rank',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      height: 1.5,
                    ),
                  ),
                ),
                title: Text(
                  taskName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
                subtitle: Text(
                  '期間: $duration日 | 最遅完了: ${endDate != null ? _formatDate(endDate) : "未設定"}',
                ),
                trailing: rank == 1
                    ? const Chip(
                        label: Text(
                          '最重要',
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.5,
                          ),
                        ),
                        backgroundColor: Color(0xFFFFEBEE),
                      )
                    : null,
              ),
            );
          }),
      ],
    );
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate;
    }
  }
}
