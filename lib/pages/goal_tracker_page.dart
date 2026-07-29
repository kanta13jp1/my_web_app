import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_web_app/utils/tab_route_url_sync.dart';

/// 目標管理ページ
/// goal-tracker Edge Function と連携
/// Notion / Liven 競合 — 短期/中期/長期目標・マイルストーン・進捗追跡
class GoalTrackerPage extends StatefulWidget {
  const GoalTrackerPage({super.key});

  @override
  State<GoalTrackerPage> createState() => _GoalTrackerPageState();
}

class _GoalTrackerPageState extends State<GoalTrackerPage>
    with SingleTickerProviderStateMixin, TabRouteUrlSync {
  @override
  List<String> get tabUrlSlugs => const <String>['active', 'completed'];

  @override
  TabController get tabUrlController => _tabController;

  final _supabase = Supabase.instance.client;
  late final TabController _tabController;

  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _activeGoals = [];
  List<Map<String, dynamic>> _completedGoals = [];

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _milestoneCtrl = TextEditingController();
  String _selectedTimeframe = 'short';
  DateTime? _deadline;
  final List<String> _milestones = [];

  static const _timeframeLabels = {
    'short': '短期 (〜3ヶ月)',
    'mid': '中期 (3〜12ヶ月)',
    'long': '長期 (1〜3年)',
  };

  static const _timeframeColors = {
    'short': Color(0xFF4CAF50),
    'mid': Color(0xFF2196F3),
    'long': Color(0xFF9C27B0),
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchGoals();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _milestoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchGoals() async {
    if (_supabase.auth.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final res = await _supabase.functions.invoke(
        'tools-hub',
        body: {'action': 'goal.list'},
      );
      final data = res.data;
      final allGoals = data is Map && data['goals'] is List
          ? (data['goals'] as List).cast<Map<String, dynamic>>()
          : <Map<String, dynamic>>[];

      setState(() {
        _activeGoals = allGoals.where((g) {
          final meta = g['metadata'] is Map ? g['metadata'] as Map : const {};
          final status = meta['status']?.toString() ?? 'active';
          return status == 'active';
        }).toList();
        _completedGoals = allGoals.where((g) {
          final meta = g['metadata'] is Map ? g['metadata'] as Map : const {};
          final status = meta['status']?.toString() ?? 'active';
          return status == 'completed';
        }).toList();
      });
    } catch (e) {
      if (mounted) setState(() => _errorMessage = '目標の取得に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createGoal() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _supabase.functions.invoke(
        'tools-hub',
        body: {
          'action': 'goal.add',
          'title': title,
          'description': _descCtrl.text.trim(),
          'timeframe': _selectedTimeframe,
          'deadline': _deadline?.toIso8601String(),
          'milestones': [
            for (final m in _milestones)
              {
                'id': DateTime.now().microsecondsSinceEpoch.toString() + m,
                'title': m,
                'done': false,
              },
          ],
        },
      );
      if (!mounted) return;
      navigator.pop();
      _titleCtrl.clear();
      _descCtrl.clear();
      _milestoneCtrl.clear();
      setState(() {
        _milestones.clear();
        _selectedTimeframe = 'short';
        _deadline = null;
      });
      await _fetchGoals();
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('目標を作成しました')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('エラー: $e')));
    }
  }

  Map<String, dynamic>? _findGoalById(String goalId) {
    for (final g in [..._activeGoals, ..._completedGoals]) {
      if (g['id']?.toString() == goalId) return g;
    }
    return null;
  }

  Future<void> _toggleMilestone(
    String goalId,
    String milestoneId,
    bool done,
  ) async {
    try {
      final goal = _findGoalById(goalId);
      if (goal == null) return;
      final meta = goal['metadata'] is Map
          ? Map<String, dynamic>.from(goal['metadata'] as Map)
          : <String, dynamic>{};
      final milestones =
          (meta['milestones'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final updated = milestones.map((m) {
        if (m['id']?.toString() == milestoneId) {
          return {...m, 'done': done};
        }
        return m;
      }).toList();
      meta['milestones'] = updated;
      await _supabase.functions.invoke(
        'tools-hub',
        body: {'action': 'goal.update', 'id': goalId, ...meta},
      );
      await _fetchGoals();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('更新に失敗: $e')));
      }
    }
  }

  Future<void> _updateStatus(String goalId, String status) async {
    try {
      final goal = _findGoalById(goalId);
      if (goal == null) return;
      final meta = goal['metadata'] is Map
          ? Map<String, dynamic>.from(goal['metadata'] as Map)
          : <String, dynamic>{};
      meta['status'] = status;
      await _supabase.functions.invoke(
        'tools-hub',
        body: {'action': 'goal.update', 'id': goalId, ...meta},
      );
      await _fetchGoals();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('ステータス更新に失敗: $e')));
      }
    }
  }

  void _showCreateDialog() {
    _titleCtrl.clear();
    _descCtrl.clear();
    _milestoneCtrl.clear();
    setState(() {
      _milestones.clear();
      _selectedTimeframe = 'short';
      _deadline = null;
    });
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('新しい目標を設定'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(
                      labelText: '目標タイトル *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: '説明・背景',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedTimeframe,
                    decoration: const InputDecoration(
                      labelText: 'タイムフレーム',
                      border: OutlineInputBorder(),
                    ),
                    items: _timeframeLabels.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setDialogState(() => _selectedTimeframe = v);
                        setState(() => _selectedTimeframe = v);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(
                      _deadline == null
                          ? '期限を設定 (任意)'
                          : '期限: ${_deadline!.year}/${_deadline!.month}/${_deadline!.day}',
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate:
                            DateTime.now().add(const Duration(days: 30)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(
                          const Duration(days: 365 * 3),
                        ),
                      );
                      if (picked != null) {
                        setDialogState(() => _deadline = picked);
                        setState(() => _deadline = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'マイルストーン',
                    style: Theme.of(ctx)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ..._milestones.map(
                    (m) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            size: 16,
                            color: Color(0xFFB0B0B0),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(m)),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () => setDialogState(
                              () => _milestones.remove(m),
                            ),
                            tooltip: '削除',
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _milestoneCtrl,
                          decoration: const InputDecoration(
                            hintText: 'マイルストーンを追加...',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.add),
                        tooltip: '追加',
                        onPressed: () {
                          final text = _milestoneCtrl.text.trim();
                          if (text.isNotEmpty) {
                            setDialogState(() {
                              _milestones.add(text);
                              _milestoneCtrl.clear();
                            });
                          }
                        },
                      ),
                    ],
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
              onPressed: _createGoal,
              child: const Text('目標を設定'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalCard(Map<String, dynamic> goal, {bool isCompleted = false}) {
    final goalId = goal['id']?.toString() ?? '';
    final meta = goal['metadata'] is Map ? goal['metadata'] as Map : const {};
    final title = meta['title']?.toString() ?? '';
    final description = meta['description']?.toString() ?? '';
    final timeframe = meta['timeframe']?.toString() ?? 'short';
    final milestones =
        (meta['milestones'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final milestoneTotal = milestones.length;
    final milestoneDone =
        milestones.where((m) => m['done'] as bool? ?? false).length;
    final progress = milestoneTotal > 0
        ? ((milestoneDone / milestoneTotal) * 100).round()
        : 0;
    final deadline = meta['deadline']?.toString();

    final tfColor = _timeframeColors[timeframe] ?? const Color(0xFF607D8B);
    final tfLabel = _timeframeLabels[timeframe] ?? timeframe;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: tfColor.withValues(alpha: 0.15),
          child: Text(
            '$progress%',
            style: TextStyle(
              fontSize: 12,
              color: tfColor,
              fontWeight: FontWeight.bold,
              height: 1.5,
            ),
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: isCompleted ? TextDecoration.lineThrough : null,
            height: 1.5,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: tfColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: tfColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    tfLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: tfColor,
                      height: 1.5,
                    ),
                  ),
                ),
                if (deadline != null) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.calendar_today,
                    size: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    deadline.substring(0, 10),
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
            if (milestoneTotal > 0) ...[
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: milestoneTotal > 0 ? progress / 100 : 0,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isCompleted ? Colors.green : tfColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$milestoneDone / $milestoneTotal マイルストーン完了',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (description.isNotEmpty) ...[
                  Text(
                    description,
                    style: const TextStyle(
                      color: Color(0xFFB0B0B0),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (milestones.isNotEmpty) ...[
                  const Divider(),
                  Text(
                    'マイルストーン',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  ...milestones.map(
                    (m) => CheckboxListTile(
                      dense: true,
                      value: m['done'] as bool? ?? false,
                      title: Text(
                        m['title'] as String? ?? '',
                        style: TextStyle(
                          decoration: (m['done'] as bool? ?? false)
                              ? TextDecoration.lineThrough
                              : null,
                          height: 1.5,
                        ),
                      ),
                      onChanged: isCompleted
                          ? null
                          : (v) => _toggleMilestone(
                                goalId,
                                m['id'] as String? ?? '',
                                v ?? false,
                              ),
                    ),
                  ),
                ],
                const Divider(),
                if (!isCompleted)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.check_circle, size: 16),
                        label: const Text('完了にする'),
                        onPressed: () => _updateStatus(goalId, 'completed'),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        icon: const Icon(
                          Icons.cancel,
                          size: 16,
                          color: Colors.red,
                        ),
                        label: const Text(
                          'キャンセル',
                          style: TextStyle(
                            color: Colors.red,
                            height: 1.5,
                          ),
                        ),
                        onPressed: () => _updateStatus(goalId, 'cancelled'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('目標管理'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'アクティブ (${_activeGoals.length})'),
            Tab(text: '完了 (${_completedGoals.length})'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '更新',
            onPressed: _fetchGoals,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        icon: const Icon(Icons.add),
        label: const Text('目標を設定'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red[300],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Colors.red,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchGoals,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildGoalList(_activeGoals, isCompleted: false),
                    _buildGoalList(_completedGoals, isCompleted: true),
                  ],
                ),
    );
  }

  Widget _buildGoalList(
    List<Map<String, dynamic>> goals, {
    required bool isCompleted,
  }) {
    if (goals.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isCompleted ? Icons.emoji_events_outlined : Icons.flag_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            const SizedBox(height: 12),
            Text(
              isCompleted ? '完了した目標はありません' : 'アクティブな目標がありません',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            if (!isCompleted) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('最初の目標を設定'),
                onPressed: _showCreateDialog,
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchGoals,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: goals
            .map((g) => _buildGoalCard(g, isCompleted: isCompleted))
            .toList(),
      ),
    );
  }
}
