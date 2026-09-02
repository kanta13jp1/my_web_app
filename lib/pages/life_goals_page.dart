import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_web_app/utils/tab_route_url_sync.dart';

/// 人生目標管理ページ。
/// 夢 → 大目標 → 中目標 → 小目標（日常行動）の4階層ツリーで
/// ユーザーの目標を管理し進捗を可視化する。
class LifeGoalsPage extends StatefulWidget {
  const LifeGoalsPage({super.key});

  @override
  State<LifeGoalsPage> createState() => _LifeGoalsPageState();
}

class _LifeGoalsPageState extends State<LifeGoalsPage>
    with SingleTickerProviderStateMixin, TabRouteUrlSync {
  @override
  List<String> get tabUrlSlugs =>
      const <String>['dream', 'big', 'medium', 'small'];

  @override
  TabController get tabUrlController => _tabs;

  final _supabase = Supabase.instance.client;
  late TabController _tabs;
  bool _loading = true;
  List<Map<String, dynamic>> _goals = [];

  static const _levels = ['dream', 'big', 'medium', 'small'];
  static const _levelLabels = ['🌟 夢', '🎯 大目標', '📌 中目標', '⚡ 小目標(行動)'];
  static const _categories = {
    'career': '💼 キャリア',
    'finance': '💰 財務',
    'relationship': '❤️ 人間関係',
    'health': '💪 健康',
    'education': '📚 学習',
    'lifestyle': '🏠 ライフスタイル',
    'creative': '🎨 創造',
    'social': '🌍 社会貢献',
    'spiritual': '🧘 精神',
    'other': '📎 その他',
  };

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _loadGoals();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadGoals() async {
    setState(() => _loading = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final data = await _supabase
          .from('life_goals')
          .select()
          .eq('user_id', userId)
          .neq('status', 'abandoned')
          .order('priority', ascending: false)
          .order('sort_order');
      if (mounted) {
        setState(() {
          _goals = List<Map<String, dynamic>>.from(data as List);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _goalsForLevel(String level) =>
      _goals.where((g) => g['level'] == level).toList();

  List<Map<String, dynamic>> _childrenOf(String parentId) =>
      _goals.where((g) => g['parent_id'] == parentId).toList();

  Color _levelColor(String level) {
    switch (level) {
      case 'dream':
        return const Color(0xFF8B5CF6);
      case 'big':
        return const Color(0xFF6366F1);
      case 'medium':
        return const Color(0xFF3B82F6);
      case 'small':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF6366F1);
    }
  }

  Future<void> _showAddGoalDialog({
    required String level,
    String? parentId,
  }) async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String selectedCategory = 'career';
    String selectedRecurrence = 'once';
    int selectedPriority = 3;
    DateTime? targetDate;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            '${_levelLabels[_levels.indexOf(level)]} を追加',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'タイトル *',
                      border: OutlineInputBorder(),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                      labelText: '詳細（任意）',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'カテゴリ',
                      border: OutlineInputBorder(),
                    ),
                    items: _categories.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setS(() => selectedCategory = v!),
                  ),
                  if (level == 'small') ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedRecurrence,
                      decoration: const InputDecoration(
                        labelText: '繰り返し',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'daily', child: Text('毎日')),
                        DropdownMenuItem(value: 'weekly', child: Text('毎週')),
                        DropdownMenuItem(
                          value: 'monthly',
                          child: Text('毎月'),
                        ),
                        DropdownMenuItem(value: 'once', child: Text('一度だけ')),
                      ],
                      onChanged: (v) => setS(() => selectedRecurrence = v!),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text(
                        '優先度: ',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                      ...List.generate(
                        5,
                        (i) => GestureDetector(
                          onTap: () => setS(() => selectedPriority = i + 1),
                          child: Icon(
                            i < selectedPriority
                                ? Icons.star
                                : Icons.star_border,
                            size: 22,
                            color: const Color(0xFFF59E0B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(
                      targetDate != null
                          ? '期限: ${DateFormat('yyyy/MM/dd').format(targetDate!)}'
                          : '期限を設定（任意）',
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate:
                            DateTime.now().add(const Duration(days: 30)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2040),
                      );
                      if (d != null) setS(() => targetDate = d);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('追加'),
            ),
          ],
        ),
      ),
    );

    if (saved != true || !mounted) return;
    final title = titleCtrl.text.trim();
    if (title.isEmpty) return;

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _supabase.from('life_goals').insert({
        'user_id': userId,
        'parent_id': parentId,
        'level': level,
        'title': title,
        'description':
            descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
        'category': selectedCategory,
        'priority': selectedPriority,
        'recurrence': selectedRecurrence,
        'target_date': targetDate?.toIso8601String().substring(0, 10),
      });
      await _loadGoals();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラー: $e'),
            backgroundColor: const Color(0xFFE53935),
          ),
        );
      }
    }
  }

  Future<void> _updateProgress(String goalId, int progress) async {
    try {
      await _supabase.from('life_goals').update({
        'progress': progress,
        'status': progress >= 100 ? 'completed' : 'active',
        if (progress >= 100) 'completed_at': DateTime.now().toIso8601String(),
      }).eq('id', goalId);
      setState(() {
        final idx = _goals.indexWhere((g) => g['id'] == goalId);
        if (idx >= 0) {
          _goals[idx] = Map.from(_goals[idx])
            ..['progress'] = progress
            ..['status'] = progress >= 100 ? 'completed' : 'active';
        }
      });
    } catch (_) {}
  }

  Future<void> _deleteGoal(String goalId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('目標を削除'),
        content: const Text('この目標と子目標をすべて削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _supabase.from('life_goals').update({
      'status': 'abandoned',
    }).eq('id', goalId);
    await _loadGoals();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('人生目標管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.insights),
            tooltip: '月次 KPI 台帳',
            onPressed: () => Navigator.of(context).pushNamed('/life-goals-kpi'),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: _levelLabels.map((l) => Tab(text: l)).toList(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddGoalDialog(level: _levels[_tabs.index]),
        icon: const Icon(Icons.add),
        label: const Text('追加'),
        backgroundColor: const Color(0xFF6366F1),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: _levels.asMap().entries.map((entry) {
                final level = entry.value;
                final levelGoals = _goalsForLevel(level);

                if (levelGoals.isEmpty) {
                  return _buildEmptyState(level, isDark);
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: levelGoals.length,
                  itemBuilder: (ctx, i) => _GoalCard(
                    goal: levelGoals[i],
                    children: _childrenOf(levelGoals[i]['id'] as String),
                    isDark: isDark,
                    levelColor: _levelColor(level),
                    categoryLabel:
                        _categories[levelGoals[i]['category']] ?? '📎 その他',
                    onAddChild: level != 'small'
                        ? () => _showAddGoalDialog(
                              level: _levels[_levels.indexOf(level) + 1],
                              parentId: levelGoals[i]['id'] as String,
                            )
                        : null,
                    onProgressChanged: level == 'small'
                        ? (v) => _updateProgress(
                              levelGoals[i]['id'] as String,
                              v,
                            )
                        : null,
                    onDelete: () => _deleteGoal(levelGoals[i]['id'] as String),
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildEmptyState(String level, bool isDark) {
    final idx = _levels.indexOf(level);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _levelLabels[idx],
              style: const TextStyle(
                fontSize: 40,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${_levelLabels[idx]}がまだありません',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _levelHint(level),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color:
                    isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: Text('${_levelLabels[idx]}を追加'),
              style: FilledButton.styleFrom(
                backgroundColor: _levelColor(level),
              ),
              onPressed: () => _showAddGoalDialog(level: level),
            ),
          ],
        ),
      ),
    );
  }

  String _levelHint(String level) {
    switch (level) {
      case 'dream':
        return '人生で達成したい大きな夢を追加してみましょう。\n例: 「起業して社会を変える」「世界一周旅行」';
      case 'big':
        return '夢に向けた大きな目標を設定しましょう。\n例: 「副業で月10万円」「英語をビジネスレベルに」';
      case 'medium':
        return '大目標を達成するための中間目標です。\n例: 「3ヶ月でWebアプリをリリース」';
      case 'small':
        return '毎日・毎週の具体的な行動を設定しましょう。\n例: 「毎朝30分英語学習」「週3回筋トレ」';
      default:
        return '';
    }
  }
}

// ---------------------------------------------------------------------------
// Goal Card Widget
// ---------------------------------------------------------------------------

class _GoalCard extends StatelessWidget {
  final Map<String, dynamic> goal;
  final List<Map<String, dynamic>> children;
  final bool isDark;
  final Color levelColor;
  final String categoryLabel;
  final VoidCallback? onAddChild;
  final void Function(int)? onProgressChanged;
  final VoidCallback onDelete;

  const _GoalCard({
    required this.goal,
    required this.children,
    required this.isDark,
    required this.levelColor,
    required this.categoryLabel,
    required this.onDelete,
    this.onAddChild,
    this.onProgressChanged,
  });

  @override
  Widget build(BuildContext context) {
    final title = goal['title']?.toString() ?? '';
    final description = goal['description']?.toString();
    final progress = (goal['progress'] as num?)?.toInt() ?? 0;
    final status = goal['status']?.toString() ?? 'active';
    final priority = (goal['priority'] as num?)?.toInt() ?? 3;
    final targetDateStr = goal['target_date']?.toString();
    final recurrence = goal['recurrence']?.toString() ?? 'once';
    final isCompleted = status == 'completed';

    DateTime? targetDate;
    if (targetDateStr != null) targetDate = DateTime.tryParse(targetDateStr);

    final bgColor = isDark ? const Color(0xFF1A2233) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF2A3A55) : const Color(0xFFE2E8F0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isCompleted ? const Color(0xFF4CAF50) : levelColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isCompleted
                              ? const Color(0xFF4CAF50)
                              : (isDark
                                  ? Colors.white
                                  : const Color(0xFF1E293B)),
                          decoration:
                              isCompleted ? TextDecoration.lineThrough : null,
                          height: 1.5,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            categoryLabel,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? const Color(0xFF9CA3AF)
                                  : const Color(0xFF4B5563),
                              height: 1.5,
                            ),
                          ),
                          if (targetDate != null) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.calendar_today,
                              size: 10,
                              color: isDark
                                  ? const Color(0xFF9CA3AF)
                                  : const Color(0xFF4B5563),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              DateFormat('yyyy/MM/dd').format(targetDate),
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? const Color(0xFF9CA3AF)
                                    : const Color(0xFF4B5563),
                                height: 1.5,
                              ),
                            ),
                          ],
                          if (recurrence != 'once') ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: levelColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                recurrence == 'daily'
                                    ? '毎日'
                                    : recurrence == 'weekly'
                                        ? '毎週'
                                        : '毎月',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: levelColor,
                                  fontWeight: FontWeight.w600,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Priority stars
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    priority,
                    (_) => const Icon(
                      Icons.star,
                      size: 12,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18),
                  itemBuilder: (_) => [
                    if (onAddChild != null)
                      const PopupMenuItem(
                        value: 'add_child',
                        child: Text('子目標を追加'),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        '削除',
                        style: TextStyle(
                          color: Color(0xFFE53935),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                  onSelected: (v) {
                    if (v == 'add_child') onAddChild?.call();
                    if (v == 'delete') onDelete();
                  },
                ),
              ],
            ),

            // Description
            if (description != null && description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? const Color(0xFF9CA3AF)
                      : const Color(0xFF4B5563),
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            // Progress
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '進捗 $progress%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isCompleted
                                  ? const Color(0xFF4CAF50)
                                  : levelColor,
                              height: 1.5,
                            ),
                          ),
                          if (isCompleted)
                            const Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: 14,
                                  color: Color(0xFF4CAF50),
                                ),
                                SizedBox(width: 3),
                                Text(
                                  '完了',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF4CAF50),
                                    fontWeight: FontWeight.w600,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (onProgressChanged != null)
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: isCompleted
                                ? const Color(0xFF4CAF50)
                                : levelColor,
                            inactiveTrackColor:
                                levelColor.withValues(alpha: 0.2),
                            thumbColor: isCompleted
                                ? const Color(0xFF4CAF50)
                                : levelColor,
                            overlayColor: levelColor.withValues(alpha: 0.1),
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 8,
                            ),
                          ),
                          child: Slider(
                            value: progress.toDouble(),
                            min: 0,
                            max: 100,
                            divisions: 10,
                            onChanged: (v) => onProgressChanged!(v.toInt()),
                          ),
                        )
                      else
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress / 100,
                            minHeight: 6,
                            backgroundColor: levelColor.withValues(alpha: 0.15),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isCompleted
                                  ? const Color(0xFF4CAF50)
                                  : levelColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            // Child goals count
            if (children.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.account_tree_outlined,
                    size: 13,
                    color: isDark
                        ? const Color(0xFF9CA3AF)
                        : const Color(0xFF4B5563),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '子目標: ${children.length}件 (完了: ${children.where((c) => c['status'] == 'completed').length}件)',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? const Color(0xFF9CA3AF)
                          : const Color(0xFF4B5563),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ],

            // Add child button
            if (onAddChild != null && !isCompleted) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onAddChild,
                  icon: Icon(Icons.add, size: 14, color: levelColor),
                  label: Text(
                    '子目標を追加',
                    style: TextStyle(
                      fontSize: 12,
                      color: levelColor,
                      height: 1.5,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
