import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── データモデル ──────────────────────────────────────────────────────────────

class WbsMilestone {
  final String code;
  final String name;
  final DateTime targetDate;
  final int goalUsers;
  final String description;
  final Color color;
  final DateTime? achievedAt;

  const WbsMilestone({
    required this.code,
    required this.name,
    required this.targetDate,
    required this.goalUsers,
    required this.description,
    required this.color,
    this.achievedAt,
  });

  factory WbsMilestone.fromMap(Map<String, dynamic> m) => WbsMilestone(
        code: m['code'] as String,
        name: m['name'] as String,
        targetDate: DateTime.parse(m['target_date'] as String),
        goalUsers: (m['goal_users'] as int?) ?? 0,
        description: m['description'] as String? ?? '',
        color: _hexColor(m['color'] as String? ?? '#FF6B35'),
        achievedAt: m['achieved_at'] != null
            ? DateTime.tryParse(m['achieved_at'] as String)
            : null,
      );

  bool get achieved => achievedAt != null;
  int daysLeft(DateTime now) => targetDate.difference(now).inDays;
}

class WbsTask {
  final String id;
  final String category;
  final String categoryIcon;
  final int categoryOrder;
  final String title;
  final String description;
  final String instance;
  final String status;
  final int progress;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? milestoneCode;
  final String priority;

  const WbsTask({
    required this.id,
    required this.category,
    required this.categoryIcon,
    required this.categoryOrder,
    required this.title,
    required this.description,
    required this.instance,
    required this.status,
    required this.progress,
    this.startDate,
    this.endDate,
    this.milestoneCode,
    required this.priority,
  });

  factory WbsTask.fromMap(Map<String, dynamic> m) => WbsTask(
        id: m['id'] as String,
        category: m['category'] as String,
        categoryIcon: m['category_icon'] as String? ?? '📋',
        categoryOrder: (m['category_order'] as int?) ?? 0,
        title: m['title'] as String,
        description: m['description'] as String? ?? '',
        instance: m['instance'] as String? ?? 'all',
        status: m['status'] as String? ?? 'pending',
        progress: (m['progress'] as int?) ?? 0,
        startDate: m['start_date'] != null
            ? DateTime.tryParse(m['start_date'] as String)
            : null,
        endDate: m['end_date'] != null
            ? DateTime.tryParse(m['end_date'] as String)
            : null,
        milestoneCode: m['milestone_code'] as String?,
        priority: m['priority'] as String? ?? 'medium',
      );

  Color get statusColor => switch (status) {
        'completed' => const Color(0xFF4CAF50),
        'in_progress' => const Color(0xFFFF6B35),
        'blocked' => const Color(0xFFE53935),
        _ => const Color(0xFF707070),
      };

  String get statusLabel => switch (status) {
        'completed' => '完了',
        'in_progress' => '進行中',
        'blocked' => 'ブロック',
        _ => '未着手',
      };

  String get instanceLabel => switch (instance) {
        'vscode' => 'VSCode版',
        'windows' => 'Windows版',
        'ps' => 'PowerShell版',
        _ => '全インスタンス',
      };

  Color get instanceColor => switch (instance) {
        'vscode' => const Color(0xFF007ACC),
        'windows' => const Color(0xFF00BCF2),
        'ps' => const Color(0xFF4B0082),
        _ => const Color(0xFF3D5AFE),
      };
}

Color _hexColor(String hex) {
  final s = hex.replaceAll('#', '');
  return Color(int.parse('FF$s', radix: 16));
}

// ── ページ本体 ────────────────────────────────────────────────────────────────

class ProjectGanttPage extends StatefulWidget {
  const ProjectGanttPage({super.key});

  @override
  State<ProjectGanttPage> createState() => _ProjectGanttPageState();
}

class _ProjectGanttPageState extends State<ProjectGanttPage>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late final TabController _tabs;

  // WBS data
  List<WbsMilestone> _milestones = [];
  List<WbsTask> _tasks = [];
  bool _loadingWbs = true;

  // Filter
  String? _filterInstance;
  String? _filterMilestone;

  // My projects (tab 2)
  List<Map<String, dynamic>> _projects = [];
  bool _loadingProjects = false;
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _newStatus = '進行中';
  bool _saving = false;

  static const _statuses = ['計画中', '進行中', '完了', '保留'];
  static const _statusColors = {
    '計画中': Color(0xFF3D5AFE),
    '進行中': Color(0xFFFF6B35),
    '完了': Color(0xFF4CAF50),
    '保留': Color(0xFFFFC107),
  };

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadWbs();
    _loadProjects();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadWbs() async {
    setState(() => _loadingWbs = true);
    try {
      final mData =
          await _supabase.from('wbs_milestones').select().order('target_date');
      final tData = await _supabase
          .from('wbs_tasks')
          .select()
          .order('category_order')
          .order('status');
      if (mounted) {
        setState(() {
          _milestones = (mData as List)
              .map((e) => WbsMilestone.fromMap(e as Map<String, dynamic>))
              .toList();
          _tasks = (tData as List)
              .map((e) => WbsTask.fromMap(e as Map<String, dynamic>))
              .toList();
        });
      }
    } catch (_) {
      // テーブル未作成時はフォールバック表示
    } finally {
      if (mounted) setState(() => _loadingWbs = false);
    }
  }

  Future<void> _loadProjects() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    setState(() => _loadingProjects = true);
    try {
      final data = await _supabase
          .from('projects')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(50);
      if (mounted) {
        setState(
          () => _projects = List<Map<String, dynamic>>.from(data as List),
        );
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingProjects = false);
    }
  }

  Future<void> _saveProject() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      await _supabase.from('projects').insert({
        'user_id': user.id,
        'name': name,
        'description': _descCtrl.text.trim(),
        'status': _newStatus,
      });
      _nameCtrl.clear();
      _descCtrl.clear();
      await _loadProjects();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('保存失敗: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _updateProjectStatus(String id, String s) async {
    await _supabase.from('projects').update({'status': s}).eq('id', id);
    await _loadProjects();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        title: const Text(
          '開発ロードマップ & WBS',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '更新',
            onPressed: () {
              _loadWbs();
              _loadProjects();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: const Color(0xFFFF6B35),
          labelColor: const Color(0xFFFF6B35),
          unselectedLabelColor: const Color(0xFF707070),
          tabs: const [
            Tab(icon: Icon(Icons.account_tree_outlined), text: '開発WBS'),
            Tab(icon: Icon(Icons.folder_outlined), text: 'マイプロジェクト'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _WbsTab(
            milestones: _milestones,
            tasks: _tasks,
            loading: _loadingWbs,
            filterInstance: _filterInstance,
            filterMilestone: _filterMilestone,
            onFilterInstance: (v) => setState(() => _filterInstance = v),
            onFilterMilestone: (v) => setState(() => _filterMilestone = v),
          ),
          _MyProjectsTab(
            projects: _projects,
            loading: _loadingProjects,
            nameCtrl: _nameCtrl,
            descCtrl: _descCtrl,
            status: _newStatus,
            saving: _saving,
            statuses: _statuses,
            statusColors: _statusColors,
            onStatusChanged: (v) => setState(() => _newStatus = v),
            onSave: _saveProject,
            onUpdateStatus: _updateProjectStatus,
          ),
        ],
      ),
    );
  }
}

// ── WBS タブ ─────────────────────────────────────────────────────────────────

class _WbsTab extends StatelessWidget {
  final List<WbsMilestone> milestones;
  final List<WbsTask> tasks;
  final bool loading;
  final String? filterInstance;
  final String? filterMilestone;
  final ValueChanged<String?> onFilterInstance;
  final ValueChanged<String?> onFilterMilestone;

  const _WbsTab({
    required this.milestones,
    required this.tasks,
    required this.loading,
    required this.filterInstance,
    required this.filterMilestone,
    required this.onFilterInstance,
    required this.onFilterMilestone,
  });

  List<WbsTask> get _filtered => tasks.where((t) {
        if (filterInstance != null && t.instance != filterInstance) {
          return false;
        }
        if (filterMilestone != null && t.milestoneCode != filterMilestone) {
          return false;
        }
        return true;
      }).toList();

  Map<String, List<WbsTask>> get _grouped {
    final result = <String, List<WbsTask>>{};
    for (final t in _filtered) {
      (result[t.category] ??= []).add(t);
    }
    return result;
  }

  double _overallProgress(List<WbsTask> taskList) {
    if (taskList.isEmpty) return 0;
    return taskList.map((t) => t.progress).reduce((a, b) => a + b) /
        taskList.length;
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF6B35)),
      );
    }

    final now = DateTime.now();
    final grouped = _grouped;
    final overallProgress = _overallProgress(tasks);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── 全体進捗 ──────────────────────────────────────────────────────
        _OverallProgressCard(
          progress: overallProgress,
          taskCount: tasks.length,
        ),
        const SizedBox(height: 16),

        // ── マイルストーン ─────────────────────────────────────────────────
        const _SectionHeader(label: 'リリースマイルストーン', icon: Icons.flag_outlined),
        const SizedBox(height: 8),
        if (milestones.isEmpty)
          const _EmptyCard(
            message: 'マイルストーンデータを読み込み中...\n(DBマイグレーション適用後に表示されます)',
          )
        else
          SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: milestones.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _MilestoneCard(
                milestone: milestones[i],
                now: now,
                tasks: tasks,
              ),
            ),
          ),
        const SizedBox(height: 20),

        // ── フィルター ────────────────────────────────────────────────────
        const _SectionHeader(
          label: 'WBSタスク',
          icon: Icons.account_tree_outlined,
        ),
        const SizedBox(height: 8),
        _FilterRow(
          filterInstance: filterInstance,
          filterMilestone: filterMilestone,
          milestones: milestones,
          onFilterInstance: onFilterInstance,
          onFilterMilestone: onFilterMilestone,
        ),
        const SizedBox(height: 12),

        // ── カテゴリ別タスク ───────────────────────────────────────────────
        if (grouped.isEmpty)
          const _EmptyCard(message: 'WBSデータを読み込み中...\n(DBマイグレーション適用後に表示されます)')
        else
          ...grouped.entries.map(
            (entry) => _CategorySection(
              category: entry.key,
              tasks: entry.value,
              categoryIcon: entry.value.isNotEmpty
                  ? entry.value.first.categoryIcon
                  : '📋',
            ),
          ),
      ],
    );
  }
}

class _OverallProgressCard extends StatelessWidget {
  final double progress;
  final int taskCount;

  const _OverallProgressCard({required this.progress, required this.taskCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A4A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🚀', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '自分株式会社 開発WBS',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '$taskCount タスク',
                      style: const TextStyle(
                        color: Color(0xFF707070),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B35).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFFF6B35).withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  '${progress.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Color(0xFFFF6B35),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress / 100,
              backgroundColor: const Color(0xFF2A2A2A),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Flutter Web + Supabase + 3インスタンス並行開発',
            style: TextStyle(color: Color(0xFF707070), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _MilestoneCard extends StatelessWidget {
  final WbsMilestone milestone;
  final DateTime now;
  final List<WbsTask> tasks;

  const _MilestoneCard({
    required this.milestone,
    required this.now,
    required this.tasks,
  });

  @override
  Widget build(BuildContext context) {
    final days = milestone.daysLeft(now);
    final milestoneTasks =
        tasks.where((t) => t.milestoneCode == milestone.code).toList();
    final completedCount =
        milestoneTasks.where((t) => t.status == 'completed').length;
    final totalCount = milestoneTasks.length;
    final taskProgress = totalCount > 0 ? completedCount / totalCount : 0.0;

    return Container(
      width: 200,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: milestone.color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                milestone.achieved ? Icons.check_circle : Icons.flag_outlined,
                color: milestone.color,
                size: 18,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  milestone.name,
                  style: TextStyle(
                    color: milestone.color,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            milestone.achieved
                ? '🎉 達成済み'
                : days > 0
                    ? 'あと $days 日'
                    : '⚠️ 期限超過',
            style: TextStyle(
              color: milestone.achieved
                  ? const Color(0xFF4CAF50)
                  : days < 14
                      ? const Color(0xFFE53935)
                      : const Color(0xFFB0B0B0),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '目標: ${milestone.goalUsers}ユーザー',
            style: const TextStyle(color: Color(0xFF707070), fontSize: 11),
          ),
          const Spacer(),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: taskProgress,
              backgroundColor: const Color(0xFF2A2A2A),
              valueColor: AlwaysStoppedAnimation<Color>(milestone.color),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$completedCount / $totalCount タスク完了',
            style: const TextStyle(color: Color(0xFF707070), fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  final String? filterInstance;
  final String? filterMilestone;
  final List<WbsMilestone> milestones;
  final ValueChanged<String?> onFilterInstance;
  final ValueChanged<String?> onFilterMilestone;

  const _FilterRow({
    required this.filterInstance,
    required this.filterMilestone,
    required this.milestones,
    required this.onFilterInstance,
    required this.onFilterMilestone,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip(
            '全て',
            null,
            filterInstance,
            onFilterInstance,
            const Color(0xFFFF6B35),
          ),
          const SizedBox(width: 6),
          _chip(
            'VSCode',
            'vscode',
            filterInstance,
            onFilterInstance,
            const Color(0xFF007ACC),
          ),
          const SizedBox(width: 6),
          _chip(
            'Windows',
            'windows',
            filterInstance,
            onFilterInstance,
            const Color(0xFF00BCF2),
          ),
          const SizedBox(width: 6),
          _chip(
            'PowerShell',
            'ps',
            filterInstance,
            onFilterInstance,
            const Color(0xFF4B0082),
          ),
          const SizedBox(width: 12),
          const Text('│', style: TextStyle(color: Color(0xFF333333))),
          const SizedBox(width: 12),
          _chip(
            '全版',
            null,
            filterMilestone,
            onFilterMilestone,
            const Color(0xFF707070),
          ),
          ...milestones.map((m) {
            return Padding(
              padding: const EdgeInsets.only(left: 6),
              child: _chip(
                m.name,
                m.code,
                filterMilestone,
                onFilterMilestone,
                m.color,
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _chip(
    String label,
    String? value,
    String? current,
    ValueChanged<String?> onTap,
    Color color,
  ) {
    final selected = current == value;
    return GestureDetector(
      onTap: () => onTap(selected ? null : value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color:
              selected ? color.withValues(alpha: 0.2) : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? color : const Color(0xFF333333)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : const Color(0xFF707070),
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  final String category;
  final String categoryIcon;
  final List<WbsTask> tasks;

  const _CategorySection({
    required this.category,
    required this.categoryIcon,
    required this.tasks,
  });

  double get _avgProgress {
    if (tasks.isEmpty) return 0;
    return tasks.map((t) => t.progress).reduce((a, b) => a + b) / tasks.length;
  }

  @override
  Widget build(BuildContext context) {
    final avg = _avgProgress;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Text(categoryIcon, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  category,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: avg / 100,
                    backgroundColor: const Color(0xFF2A2A2A),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${avg.toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: Color(0xFFFF6B35),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        ...tasks.map((t) => _TaskRow(task: t)),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _TaskRow extends StatelessWidget {
  final WbsTask task;

  const _TaskRow({required this.task});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6, left: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF222222)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  task.title,
                  style: TextStyle(
                    color: task.status == 'completed'
                        ? const Color(0xFF707070)
                        : Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    decoration: task.status == 'completed'
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: task.instanceColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  task.instanceLabel,
                  style: TextStyle(
                    color: task.instanceColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: task.statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  task.statusLabel,
                  style: TextStyle(
                    color: task.statusColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (task.progress > 0 && task.progress < 100) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: task.progress / 100,
                      backgroundColor: const Color(0xFF2A2A2A),
                      valueColor:
                          AlwaysStoppedAnimation<Color>(task.statusColor),
                      minHeight: 4,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${task.progress}%',
                  style: TextStyle(color: task.statusColor, fontSize: 10),
                ),
              ],
            ),
          ],
          if (task.endDate != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 10,
                  color: Color(0xFF505050),
                ),
                const SizedBox(width: 4),
                Text(
                  '期限: ${task.endDate!.year}/${task.endDate!.month.toString().padLeft(2, '0')}/${task.endDate!.day.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    color: Color(0xFF505050),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── マイプロジェクト タブ ─────────────────────────────────────────────────────

class _MyProjectsTab extends StatelessWidget {
  final List<Map<String, dynamic>> projects;
  final bool loading;
  final TextEditingController nameCtrl;
  final TextEditingController descCtrl;
  final String status;
  final bool saving;
  final List<String> statuses;
  final Map<String, Color> statusColors;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onSave;
  final Future<void> Function(String, String) onUpdateStatus;

  const _MyProjectsTab({
    required this.projects,
    required this.loading,
    required this.nameCtrl,
    required this.descCtrl,
    required this.status,
    required this.saving,
    required this.statuses,
    required this.statusColors,
    required this.onStatusChanged,
    required this.onSave,
    required this.onUpdateStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            color: const Color(0xFF1E1E1E),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '新規プロジェクト',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDec('プロジェクト名'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDec('説明 (任意)'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFF333333)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButton<String>(
                            value: status,
                            dropdownColor: const Color(0xFF1E1E1E),
                            style: const TextStyle(color: Colors.white),
                            underline: const SizedBox.shrink(),
                            isExpanded: true,
                            items: statuses
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(s),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => onStatusChanged(v!),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: saving ? null : onSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6B35),
                          foregroundColor: Colors.white,
                        ),
                        child: saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('作成'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFF6B35)),
                  )
                : projects.isEmpty
                    ? const Center(
                        child: Text(
                          'プロジェクトはまだありません',
                          style: TextStyle(color: Colors.white38),
                        ),
                      )
                    : ListView.builder(
                        itemCount: projects.length,
                        itemBuilder: (_, i) {
                          final p = projects[i];
                          final s = p['status'] as String? ?? '進行中';
                          final c = statusColors[s] ?? const Color(0xFFFF6B35);
                          return Card(
                            color: const Color(0xFF1E1E1E),
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: c.withValues(alpha: 0.2),
                                child: Icon(
                                  Icons.folder_outlined,
                                  color: c,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                p['name'] as String? ?? '',
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: Text(
                                p['description'] as String? ?? '',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: PopupMenuButton<String>(
                                color: const Color(0xFF1E1E1E),
                                icon: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: c.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    s,
                                    style: TextStyle(color: c, fontSize: 12),
                                  ),
                                ),
                                itemBuilder: (_) => statuses
                                    .map(
                                      (st) => PopupMenuItem(
                                        value: st,
                                        child: Text(
                                          st,
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onSelected: (st) =>
                                    onUpdateStatus(p['id'].toString(), st),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF333333)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF333333)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFFF6B35)),
        ),
      );
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SectionHeader({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, color: const Color(0xFFFF6B35), size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      );
}

class _EmptyCard extends StatelessWidget {
  final String message;
  const _EmptyCard({required this.message});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2A2A2A)),
        ),
        child: Text(
          message,
          style: const TextStyle(color: Color(0xFF707070), fontSize: 13),
          textAlign: TextAlign.center,
        ),
      );
}
