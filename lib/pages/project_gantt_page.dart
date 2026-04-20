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
  // Win版#131 part 10: 遅延リカバリー対応
  final String recoveryPlan;
  final int rescheduledCount;

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
    this.recoveryPlan = '',
    this.rescheduledCount = 0,
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
        recoveryPlan: (m['recovery_plan'] as String?) ?? '',
        rescheduledCount: (m['rescheduled_count'] as int?) ?? 0,
      );

  /// 遅延日数 (今日 - end_date / 完了済 or 期限なし は 0)
  int get delayDays {
    if (status == 'completed' || endDate == null) return 0;
    final now = DateTime.now();
    final end = endDate!;
    final today = DateTime(now.year, now.month, now.day);
    final endDay = DateTime(end.year, end.month, end.day);
    final diff = today.difference(endDay).inDays;
    return diff > 0 ? diff : 0;
  }

  /// 遅延中かつ recovery_plan 未記入 = 警告対象
  bool get isDelayedNoPlan => delayDays > 0 && recoveryPlan.trim().isEmpty;

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
        'win' => 'Win版',
        'windows' => 'Win版',
        'ps1' => 'PS版#1',
        'ps2' => 'PS版#2',
        'ps3' => 'PS版#3',
        'ps4' => 'PS版#4',
        'ps5' => 'PS版#5',
        'ps6' => 'PS版#6',
        'ps' => 'PS版',
        'web' => 'WEB版',
        'mobile' => '📱スマホ版',
        _ => '全インスタンス',
      };

  Color get instanceColor => switch (instance) {
        'vscode' => const Color(0xFF007ACC),
        'win' => const Color(0xFF00BCF2),
        'windows' => const Color(0xFF00BCF2),
        'ps1' => const Color(0xFF4B0082),
        'ps2' => const Color(0xFF6A0DAD),
        'ps3' => const Color(0xFF8B5CF6),
        'ps4' => const Color(0xFFA855F7),
        'ps5' => const Color(0xFFC084FC),
        'ps6' => const Color(0xFFDAB6FC),
        'ps' => const Color(0xFF4B0082),
        'web' => const Color(0xFF22C55E),
        'mobile' => const Color(0xFFF97316),
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
    _tabs = TabController(length: 3, vsync: this);
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
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            height: 1.5,
          ),
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
            Tab(icon: Icon(Icons.timeline), text: 'タイムライン'),
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
          _GanttTimelineTab(
            milestones: _milestones,
            tasks: _tasks,
            loading: _loadingWbs,
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
              const Text(
                '🚀',
                style: TextStyle(
                  fontSize: 24,
                  height: 1.5,
                ),
              ),
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
                        height: 1.5,
                      ),
                    ),
                    Text(
                      '$taskCount タスク',
                      style: const TextStyle(
                        color: Color(0xFF707070),
                        fontSize: 12,
                        height: 1.5,
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
                    height: 1.5,
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
            style: TextStyle(
              color: Color(0xFF707070),
              fontSize: 11,
              height: 1.5,
            ),
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
                    height: 1.5,
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
              height: 1.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '目標: ${milestone.goalUsers}ユーザー',
            style: const TextStyle(
              color: Color(0xFF707070),
              fontSize: 11,
              height: 1.5,
            ),
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
            style: const TextStyle(
              color: Color(0xFF707070),
              fontSize: 10,
              height: 1.5,
            ),
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
            'Win',
            'win',
            filterInstance,
            onFilterInstance,
            const Color(0xFF00BCF2),
          ),
          const SizedBox(width: 6),
          _chip(
            'PS#1',
            'ps1',
            filterInstance,
            onFilterInstance,
            const Color(0xFF4B0082),
          ),
          const SizedBox(width: 6),
          _chip(
            'PS#2',
            'ps2',
            filterInstance,
            onFilterInstance,
            const Color(0xFF6A0DAD),
          ),
          const SizedBox(width: 6),
          _chip(
            'PS#3',
            'ps3',
            filterInstance,
            onFilterInstance,
            const Color(0xFF8B5CF6),
          ),
          const SizedBox(width: 6),
          _chip(
            'PS#4',
            'ps4',
            filterInstance,
            onFilterInstance,
            const Color(0xFFA855F7),
          ),
          const SizedBox(width: 6),
          _chip(
            'PS#5',
            'ps5',
            filterInstance,
            onFilterInstance,
            const Color(0xFFC084FC),
          ),
          const SizedBox(width: 6),
          _chip(
            'PS#6',
            'ps6',
            filterInstance,
            onFilterInstance,
            const Color(0xFFDAB6FC),
          ),
          const SizedBox(width: 6),
          _chip(
            'WEB',
            'web',
            filterInstance,
            onFilterInstance,
            const Color(0xFF22C55E),
          ),
          const SizedBox(width: 6),
          _chip(
            '📱',
            'mobile',
            filterInstance,
            onFilterInstance,
            const Color(0xFFF97316),
          ),
          const SizedBox(width: 12),
          const Text(
            '│',
            style: TextStyle(
              color: Color(0xFF333333),
              height: 1.5,
            ),
          ),
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
            height: 1.5,
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
              Text(
                categoryIcon,
                style: const TextStyle(
                  fontSize: 18,
                  height: 1.5,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  category,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    height: 1.5,
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
                  height: 1.5,
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
                    height: 1.5,
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
                    height: 1.5,
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
                    height: 1.5,
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
                  style: TextStyle(
                    color: task.statusColor,
                    fontSize: 10,
                    height: 1.5,
                  ),
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
                    height: 1.5,
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
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(
                      color: Colors.white,
                      height: 1.5,
                    ),
                    decoration: _inputDec('プロジェクト名'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descCtrl,
                    style: const TextStyle(
                      color: Colors.white,
                      height: 1.5,
                    ),
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
                            style: const TextStyle(
                              color: Colors.white,
                              height: 1.5,
                            ),
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
                          style: TextStyle(
                            color: Colors.white38,
                            height: 1.5,
                          ),
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
                                style: const TextStyle(
                                  color: Colors.white,
                                  height: 1.5,
                                ),
                              ),
                              subtitle: Text(
                                p['description'] as String? ?? '',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                  height: 1.5,
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
                                    style: TextStyle(
                                      color: c,
                                      fontSize: 12,
                                      height: 1.5,
                                    ),
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
                                            height: 1.5,
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
        hintStyle: const TextStyle(
          color: Colors.white38,
          height: 1.5,
        ),
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

// ── MS Project 風ガントチャートタイムライン ─────────────────────────────────

class _GanttTimelineTab extends StatefulWidget {
  final List<WbsMilestone> milestones;
  final List<WbsTask> tasks;
  final bool loading;

  const _GanttTimelineTab({
    required this.milestones,
    required this.tasks,
    required this.loading,
  });

  @override
  State<_GanttTimelineTab> createState() => _GanttTimelineTabState();
}

class _GanttTimelineTabState extends State<_GanttTimelineTab> {
  static const _leftPanelWidth = 340.0;
  static const _rowHeight = 32.0;
  static const _headerHeight = 56.0;
  static const _dayWidth = 6.0;
  static const _bgColor = Color(0xFF0F0F14);
  static const _panelColor = Color(0xFF1A1A24);
  static const _gridLine = Color(0xFF2A2A36);
  static const _todayColor = Color(0xFFFF6B35);

  final _leftScroll = ScrollController();
  final _rightScroll = ScrollController();
  final _timelineHScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    // 左右の垂直スクロールを同期
    _leftScroll.addListener(() {
      if (_rightScroll.hasClients &&
          _rightScroll.offset != _leftScroll.offset) {
        _rightScroll.jumpTo(_leftScroll.offset);
      }
    });
    _rightScroll.addListener(() {
      if (_leftScroll.hasClients && _leftScroll.offset != _rightScroll.offset) {
        _leftScroll.jumpTo(_rightScroll.offset);
      }
    });
  }

  @override
  void dispose() {
    _leftScroll.dispose();
    _rightScroll.dispose();
    _timelineHScroll.dispose();
    super.dispose();
  }

  DateTime get _timelineStart {
    // 今日の 30日前 を起点 (過去タスクも若干見える)
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1).subtract(const Duration(days: 30));
  }

  DateTime get _timelineEnd {
    if (widget.milestones.isEmpty) {
      return DateTime.now().add(const Duration(days: 210));
    }
    final latest = widget.milestones
        .map((m) => m.targetDate)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    // 最終マイルストーン +30日
    return latest.add(const Duration(days: 30));
  }

  int get _totalDays => _timelineEnd.difference(_timelineStart).inDays;
  double get _timelineWidth => _totalDays * _dayWidth;

  /// 指定日付のタイムライン上の X 座標
  double _dateToX(DateTime date) {
    final days = date.difference(_timelineStart).inDays;
    return days * _dayWidth;
  }

  List<WbsTask> get _orderedTasks {
    final list = [...widget.tasks];
    list.sort((a, b) {
      // カテゴリ順 → 開始日順
      final catCmp = a.categoryOrder.compareTo(b.categoryOrder);
      if (catCmp != 0) return catCmp;
      final aStart = a.startDate ?? _timelineStart;
      final bStart = b.startDate ?? _timelineStart;
      return aStart.compareTo(bStart);
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF6B35)),
      );
    }
    final tasks = _orderedTasks;
    if (tasks.isEmpty) {
      return const _EmptyCard(
        message: 'タスクデータがありません\n(WBS migration 適用後に表示されます)',
      );
    }

    return Container(
      color: _bgColor,
      child: Column(
        children: [
          _buildHeader(tasks.length),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 左パネル (# / タスク名 / 担当)
                SizedBox(
                  width: _leftPanelWidth,
                  child: Column(
                    children: [
                      _buildLeftColumnHeader(),
                      Expanded(
                        child: ListView.builder(
                          controller: _leftScroll,
                          itemCount: tasks.length,
                          itemExtent: _rowHeight,
                          itemBuilder: (_, i) => _buildLeftRow(i, tasks[i]),
                        ),
                      ),
                    ],
                  ),
                ),
                // 右タイムライン (横スクロール)
                Expanded(
                  child: Scrollbar(
                    controller: _timelineHScroll,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _timelineHScroll,
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: _timelineWidth,
                        child: Column(
                          children: [
                            _buildMonthHeader(),
                            Expanded(
                              child: Stack(
                                children: [
                                  // グリッド + Today ライン
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: _GanttGridPainter(
                                        start: _timelineStart,
                                        end: _timelineEnd,
                                        dayWidth: _dayWidth,
                                        todayX: _dateToX(DateTime.now()),
                                      ),
                                    ),
                                  ),
                                  // タスクバー行
                                  ListView.builder(
                                    controller: _rightScroll,
                                    itemCount: tasks.length,
                                    itemExtent: _rowHeight,
                                    itemBuilder: (_, i) =>
                                        _buildTimelineRow(i, tasks[i]),
                                  ),
                                  // Win版#131 part 10: イナズマ線 (lightning line)
                                  // 今日時点での進捗実態を zigzag で可視化
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: CustomPaint(
                                        painter: _LightningLinePainter(
                                          tasks: tasks,
                                          dayWidth: _dayWidth,
                                          rowHeight: _rowHeight,
                                          timelineStart: _timelineStart,
                                          today: DateTime.now(),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // マイルストーンの縦線 + 菱形
                                  ...widget.milestones.map(_buildMilestoneMark),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(int taskCount) {
    return Container(
      color: _panelColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(
            Icons.table_chart_outlined,
            color: Color(0xFFFF6B35),
            size: 20,
          ),
          const SizedBox(width: 8),
          const Text(
            'プロジェクトタイムライン',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$taskCount タスク',
            style: const TextStyle(
              color: Color(0xFF808090),
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const Spacer(),
          Container(
            width: 10,
            height: 10,
            color: _todayColor,
          ),
          const SizedBox(width: 6),
          const Text(
            '今日',
            style: TextStyle(
              color: Color(0xFFB0B0C0),
              fontSize: 11,
              height: 1.5,
            ),
          ),
          const SizedBox(width: 16),
          _legendSwatch(const Color(0xFF4CAF50), '完了'),
          const SizedBox(width: 8),
          _legendSwatch(const Color(0xFFFF6B35), '進行中'),
          const SizedBox(width: 8),
          _legendSwatch(const Color(0xFF707080), '未着手'),
        ],
      ),
    );
  }

  Widget _legendSwatch(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFB0B0C0),
            fontSize: 11,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildLeftColumnHeader() {
    return Container(
      height: _headerHeight,
      color: _panelColor,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: const Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '#',
              style: TextStyle(
                color: Color(0xFFB0B0C0),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              'タスク名',
              style: TextStyle(
                color: Color(0xFFB0B0C0),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
          ),
          SizedBox(
            width: 70,
            child: Text(
              '担当',
              style: TextStyle(
                color: Color(0xFFB0B0C0),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftRow(int index, WbsTask task) {
    final isEven = index % 2 == 0;
    final isDelayedNoPlan = task.isDelayedNoPlan;
    final isDelayed = task.delayDays > 0;
    return Tooltip(
      message: isDelayedNoPlan
          ? '⚠ ${task.delayDays}日遅延・リカバリー案未記入 (要対処)'
          : isDelayed
              ? '${task.delayDays}日遅延 — リカバリー案: ${task.recoveryPlan}'
              : task.recoveryPlan.isNotEmpty
                  ? 'リカバリー案: ${task.recoveryPlan}'
                  : task.title,
      child: Container(
        decoration: BoxDecoration(
          color: isEven ? const Color(0xFF14141C) : const Color(0xFF1A1A24),
          border: Border(
            bottom: const BorderSide(color: _gridLine, width: 0.5),
            left: isDelayedNoPlan
                ? const BorderSide(color: Color(0xFFEF4444), width: 3)
                : isDelayed
                    ? const BorderSide(color: Color(0xFFF97316), width: 3)
                    : BorderSide.none,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Color(0xFF808090),
                  fontSize: 11,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            // チェックボックス (完了状態)
            Icon(
              task.status == 'completed'
                  ? Icons.check_box
                  : Icons.check_box_outline_blank,
              size: 14,
              color: task.status == 'completed'
                  ? const Color(0xFF4CAF50)
                  : const Color(0xFF606070),
            ),
            const SizedBox(width: 6),
            // カテゴリ絵文字
            Text(
              task.categoryIcon,
              style: const TextStyle(
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      task.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        height: 1.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isDelayedNoPlan) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '⚠${task.delayDays}d',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ] else if (isDelayed) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF97316),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${task.delayDays}d',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(
              width: 70,
              child: _instanceBadge(task),
            ),
          ],
        ),
      ),
    );
  }

  Widget _instanceBadge(WbsTask task) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: task.instanceColor.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: Text(
        _shortInstance(task.instance),
        style: TextStyle(
          color: task.instanceColor,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          height: 1.5,
        ),
      ),
    );
  }

  String _shortInstance(String i) => switch (i) {
        'vscode' => 'VSCode',
        'windows' => 'Windows',
        'ps' => 'PowerShell',
        _ => 'ALL',
      };

  Widget _buildMonthHeader() {
    return Container(
      height: _headerHeight,
      color: _panelColor,
      child: CustomPaint(
        painter: _MonthHeaderPainter(
          start: _timelineStart,
          end: _timelineEnd,
          dayWidth: _dayWidth,
        ),
      ),
    );
  }

  Widget _buildTimelineRow(int index, WbsTask task) {
    final start = task.startDate;
    final end = task.endDate;
    if (start == null || end == null) {
      return const SizedBox.shrink();
    }
    final x = _dateToX(start);
    final w = (_dateToX(end) - x).clamp(_dayWidth, double.infinity);
    final progressW = w * (task.progress / 100.0);

    return Container(
      decoration: BoxDecoration(
        color:
            index % 2 == 0 ? const Color(0xFF14141C) : const Color(0xFF1A1A24),
      ),
      child: Stack(
        children: [
          Positioned(
            left: x,
            top: 8,
            child: Container(
              width: w.toDouble(),
              height: _rowHeight - 16,
              decoration: BoxDecoration(
                color: task.statusColor.withValues(alpha: 0.25),
                border: Border.all(color: task.statusColor, width: 1),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Stack(
                children: [
                  // 進捗塗り
                  Container(
                    width: progressW.toDouble(),
                    decoration: BoxDecoration(
                      color: task.statusColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(2),
                        bottomLeft: Radius.circular(2),
                      ),
                    ),
                  ),
                  if (w > 40)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${task.progress}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMilestoneMark(WbsMilestone m) {
    final x = _dateToX(m.targetDate);
    return Positioned(
      left: x - 6,
      top: 0,
      bottom: 0,
      child: IgnorePointer(
        child: Column(
          children: [
            Transform.rotate(
              angle: 0.785,
              child: Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 2),
                color: m.color,
              ),
            ),
            Expanded(
              child: Container(
                width: 1,
                color: m.color.withValues(alpha: 0.35),
                margin: const EdgeInsets.only(left: 4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GanttGridPainter extends CustomPainter {
  final DateTime start;
  final DateTime end;
  final double dayWidth;
  final double todayX;

  _GanttGridPainter({
    required this.start,
    required this.end,
    required this.dayWidth,
    required this.todayX,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final weekend = Paint()..color = const Color(0xFF181822);
    final weekLine = Paint()..color = const Color(0xFF22222E);
    final monthLine = Paint()..color = const Color(0xFF3A3A48);

    var day = start;
    var x = 0.0;
    while (day.isBefore(end)) {
      // 週末ハイライト
      if (day.weekday == DateTime.saturday || day.weekday == DateTime.sunday) {
        canvas.drawRect(
          Rect.fromLTWH(x, 0, dayWidth, size.height),
          weekend,
        );
      }
      // 月の切り替わりで太線
      if (day.day == 1) {
        canvas.drawLine(
          Offset(x, 0),
          Offset(x, size.height),
          monthLine,
        );
      } else if (day.weekday == DateTime.monday) {
        canvas.drawLine(
          Offset(x, 0),
          Offset(x, size.height),
          weekLine,
        );
      }
      day = day.add(const Duration(days: 1));
      x += dayWidth;
    }
    // Today ライン
    final todayPaint = Paint()
      ..color = const Color(0xFFFF6B35)
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(todayX, 0),
      Offset(todayX, size.height),
      todayPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GanttGridPainter oldDelegate) =>
      oldDelegate.todayX != todayX ||
      oldDelegate.start != start ||
      oldDelegate.end != end;
}

class _MonthHeaderPainter extends CustomPainter {
  final DateTime start;
  final DateTime end;
  final double dayWidth;

  _MonthHeaderPainter({
    required this.start,
    required this.end,
    required this.dayWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()..color = const Color(0xFF3A3A48);

    // 月ヘッダー (上段)
    DateTime monthCursor = DateTime(start.year, start.month, 1);
    while (monthCursor.isBefore(end)) {
      final monthStart = monthCursor.isAfter(start) ? monthCursor : start;
      final nextMonth = DateTime(monthCursor.year, monthCursor.month + 1, 1);
      final monthEnd = nextMonth.isBefore(end) ? nextMonth : end;
      final xStart = monthStart.difference(start).inDays * dayWidth;
      final xEnd = monthEnd.difference(start).inDays * dayWidth;
      final width = xEnd - xStart;

      // 月ラベル
      final tp = TextPainter(
        text: TextSpan(
          text:
              '${monthCursor.year}/${monthCursor.month.toString().padLeft(2, '0')}',
          style: const TextStyle(
            color: Color(0xFFE0E0EA),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            height: 1.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(minWidth: 0, maxWidth: width);
      if (width > 40) {
        tp.paint(canvas, Offset(xStart + 6, 8));
      }

      // 月境界線
      canvas.drawLine(
        Offset(xEnd, 0),
        Offset(xEnd, size.height),
        line,
      );

      monthCursor = nextMonth;
    }

    // 日/週ヘッダー (下段)
    const weekLabelStyle = TextStyle(
      color: Color(0xFF909098),
      fontSize: 9,
      height: 1.5,
    );
    DateTime day = start;
    double x = 0;
    while (day.isBefore(end)) {
      if (day.weekday == DateTime.monday && dayWidth >= 5) {
        final tp = TextPainter(
          text: TextSpan(
            text: '${day.day}',
            style: weekLabelStyle,
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x + 1, 30));
      }
      day = day.add(const Duration(days: 1));
      x += dayWidth;
    }

    // ヘッダー下の太線
    final bottomLinePaint = Paint()..color = const Color(0xFF3A3A48);
    canvas.drawLine(
      Offset(0, size.height - 1),
      Offset(size.width, size.height - 1),
      bottomLinePaint,
    );
    // 月/日セクション境界
    final midLinePaint = Paint()..color = const Color(0xFF2A2A36);
    canvas.drawLine(
      const Offset(0, 26),
      Offset(size.width, 26),
      midLinePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _MonthHeaderPainter oldDelegate) =>
      oldDelegate.start != start || oldDelegate.end != end;
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
              height: 1.5,
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
          style: const TextStyle(
            color: Color(0xFF707070),
            fontSize: 13,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      );
}

/// Win版#131 part 10: イナズマ線 (Lightning Line / 進捗実態線)
///
/// PM 古典の zigzag 進捗線を Gantt に重ねる。
/// 各タスク行で:
///   - 期待進捗 (今日 - start) / (end - start)
///   - 実進捗 task.progress / 100
///   - actual >= expected → 今日 X より右 (進んでいる)
///   - actual <  expected → 今日 X より左 (遅れている)
/// 全タスク行をポリラインで縦に結ぶ。色:
///   - 全体 順調 → Green
///   - 1 タスクでも遅延 → Orange
///   - 遅延 + recovery_plan 未記入 → Red
class _LightningLinePainter extends CustomPainter {
  final List<WbsTask> tasks;
  final double dayWidth;
  final double rowHeight;
  final DateTime timelineStart;
  final DateTime today;

  _LightningLinePainter({
    required this.tasks,
    required this.dayWidth,
    required this.rowHeight,
    required this.timelineStart,
    required this.today,
  });

  double _dateToX(DateTime date) {
    final s = DateTime(
      timelineStart.year,
      timelineStart.month,
      timelineStart.day,
    );
    final dt = DateTime(date.year, date.month, date.day);
    return dt.difference(s).inDays * dayWidth;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (tasks.isEmpty) return;
    final todayX = _dateToX(today);
    if (todayX < 0 || todayX > size.width) return;

    final points = <Offset>[];
    bool anyDelay = false;
    bool anyDelayNoPlan = false;

    for (var i = 0; i < tasks.length; i++) {
      final t = tasks[i];
      final y = i * rowHeight + rowHeight / 2;
      double x = todayX;

      if (t.startDate != null && t.endDate != null && t.status != 'completed') {
        final startX = _dateToX(t.startDate!);
        final endX = _dateToX(t.endDate!);
        final barWidth = endX - startX;
        if (barWidth > 0) {
          // 期待進捗
          final totalDays = t.endDate!.difference(t.startDate!).inDays;
          final passedDays =
              today.difference(t.startDate!).inDays.clamp(0, totalDays);
          final expected = totalDays > 0 ? passedDays / totalDays : 0.0;
          final actual = t.progress / 100.0;

          // 実進捗位置 = bar 内での actual position
          final actualX = startX + barWidth * actual;
          x = actualX;

          // 遅延判定
          if (actual < expected - 0.05) {
            anyDelay = true;
            if (t.recoveryPlan.trim().isEmpty) {
              anyDelayNoPlan = true;
            }
          }
        }
      } else if (t.status == 'completed' || t.endDate == null) {
        // 完了済 or 期限なし → 今日 X 維持
        x = todayX;
      }

      // overdue 強制左折れ
      if (t.delayDays > 0) {
        anyDelay = true;
        if (t.recoveryPlan.trim().isEmpty) {
          anyDelayNoPlan = true;
        }
      }

      points.add(Offset(x.clamp(0.0, size.width), y));
    }

    // 線色決定
    Color lineColor;
    if (anyDelayNoPlan) {
      lineColor = const Color(0xFFEF4444); // Red — 遅延 + 未記入
    } else if (anyDelay) {
      lineColor = const Color(0xFFF97316); // Orange — 遅延あり (recovery 記入済)
    } else {
      lineColor = const Color(0xFF22C55E); // Green — 順調
    }

    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    final path = Path()..moveTo(points.first.dx, 0);
    for (final p in points) {
      path.lineTo(p.dx, p.dy);
    }
    path.lineTo(points.last.dx, size.height);
    canvas.drawPath(path, paint);

    // 各 anchor に小さな○
    final dotPaint = Paint()..color = lineColor;
    for (final p in points) {
      canvas.drawCircle(p, 2.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LightningLinePainter oldDelegate) =>
      oldDelegate.tasks != tasks ||
      oldDelegate.today != today ||
      oldDelegate.dayWidth != dayWidth;
}
