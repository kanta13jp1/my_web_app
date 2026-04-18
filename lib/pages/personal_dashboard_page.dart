import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

/// パーソナルダッシュボードページ
/// ノート数・タスク・習慣・集中時間をチャートで可視化。
/// Notion 3.4 ダッシュボードビュー対抗。
/// personal-dashboard Edge Function と連携。
class PersonalDashboardPage extends StatefulWidget {
  const PersonalDashboardPage({super.key});

  @override
  State<PersonalDashboardPage> createState() => _PersonalDashboardPageState();
}

class _PersonalDashboardPageState extends State<PersonalDashboardPage>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late final TabController _tabController;

  bool _isLoading = false;
  String? _errorMessage;

  // KPI データ
  Map<String, dynamic> _kpiData = {};
  List<Map<String, dynamic>> _weeklyActivity = [];
  List<Map<String, dynamic>> _habitStats = [];
  List<Map<String, dynamic>> _recentNotes = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchDashboardData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchDashboardData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        setState(() {
          _errorMessage = 'ログインが必要です';
          _isLoading = false;
        });
        return;
      }

      // Edge Function 呼び出し
      final res = await _supabase.functions.invoke(
        'personal-dashboard',
        body: {'action': 'get_overview', 'user_id': userId},
      );

      if (!mounted) return;

      final data = res.data as Map<String, dynamic>? ?? {};
      setState(() {
        _kpiData = data['kpi'] as Map<String, dynamic>? ?? _buildFallbackKpi();
        _weeklyActivity =
            List<Map<String, dynamic>>.from(data['weekly_activity'] ?? []);
        _habitStats =
            List<Map<String, dynamic>>.from(data['habit_stats'] ?? []);
        _recentNotes =
            List<Map<String, dynamic>>.from(data['recent_notes'] ?? []);
        if (_weeklyActivity.isEmpty) _weeklyActivity = _buildFallbackWeekly();
        if (_habitStats.isEmpty) _habitStats = _buildFallbackHabits();
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _kpiData = _buildFallbackKpi();
        _weeklyActivity = _buildFallbackWeekly();
        _habitStats = _buildFallbackHabits();
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic> _buildFallbackKpi() => {
        'total_notes': 0,
        'tasks_completed': 0,
        'focus_minutes': 0,
        'habit_streak': 0,
        'note_growth': 0,
        'task_rate': 0.0,
      };

  List<Map<String, dynamic>> _buildFallbackWeekly() {
    final now = DateTime.now();
    return List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      return {
        'date': DateFormat('MM/dd').format(day),
        'notes': 0,
        'tasks': 0,
        'focus_min': 0,
      };
    });
  }

  List<Map<String, dynamic>> _buildFallbackHabits() => [
        {'name': '朝の記録', 'streak': 0, 'completed_today': false},
        {'name': '集中タイマー', 'streak': 0, 'completed_today': false},
        {'name': '振り返りメモ', 'streak': 0, 'completed_today': false},
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('パーソナルダッシュボード'),
        backgroundColor: Color(0xFF0891B2),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchDashboardData,
            tooltip: '更新',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'KPI概要'),
            Tab(icon: Icon(Icons.show_chart), text: '週次推移'),
            Tab(icon: Icon(Icons.loop), text: '習慣トラッキング'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildKpiTab(),
                    _buildWeeklyTab(),
                    _buildHabitsTab(),
                  ],
                ),
    );
  }

  Widget _buildKpiTab() {
    final totalNotes = _kpiData['total_notes'] as int? ?? 0;
    final tasksCompleted = _kpiData['tasks_completed'] as int? ?? 0;
    final focusMinutes = _kpiData['focus_minutes'] as int? ?? 0;
    final habitStreak = _kpiData['habit_streak'] as int? ?? 0;
    final noteGrowth = _kpiData['note_growth'] as int? ?? 0;
    final taskRate = (_kpiData['task_rate'] as num?)?.toDouble() ?? 0.0;

    final focusHours = '${(focusMinutes / 60).toStringAsFixed(1)}h';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'あなたの生産性スコア',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '更新: ${DateFormat('MM/dd HH:mm').format(DateTime.now())}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 16),
          // KPI グリッド
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _kpiCard(
                '総ノート数',
                totalNotes.toString(),
                Icons.note_alt,
                Color(0xFF7C3AED),
                noteGrowth > 0 ? '+$noteGrowth 今週' : null,
              ),
              _kpiCard(
                'タスク完了',
                tasksCompleted.toString(),
                Icons.task_alt,
                Color(0xFF059669),
                taskRate > 0
                    ? '達成率 ${(taskRate * 100).toStringAsFixed(0)}%'
                    : null,
              ),
              _kpiCard(
                '集中時間',
                focusHours,
                Icons.timer,
                Color(0xFFDC2626),
                focusMinutes > 0 ? '合計 $focusMinutes分' : null,
              ),
              _kpiCard(
                '習慣ストリーク',
                '$habitStreak日',
                Icons.local_fire_department,
                Color(0xFFF59E0B),
                habitStreak >= 7 ? '🔥 週間達成！' : null,
              ),
            ],
          ),
          const SizedBox(height: 24),
          // タスク達成率バー
          if (taskRate > 0) ...[
            const Text(
              'タスク達成率',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: taskRate.clamp(0.0, 1.0),
                backgroundColor: Color(0xFFE2E8F0),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Color(0xFF059669)),
                minHeight: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${(taskRate * 100).toStringAsFixed(1)}% 完了',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 24),
          ],
          // 最近のノート
          if (_recentNotes.isNotEmpty) ...[
            const Text(
              '最近のノート',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            ..._recentNotes.take(5).map((note) {
              final title = note['title'] as String? ?? '(無題)';
              final updatedAt = note['updated_at'] as String?;
              final dateStr = updatedAt != null
                  ? DateFormat('MM/dd HH:mm')
                      .format(DateTime.parse(updatedAt).toLocal())
                  : '';
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.note,
                  size: 18,
                  color: Color(0xFF7C3AED),
                ),
                title: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  dateStr,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              );
            }),
          ],
          if (_recentNotes.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'ノートを作成するとここに表示されます',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _kpiCard(
    String label,
    String value,
    IconData icon,
    Color color,
    String? subtitle,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF94A3B8),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWeeklyTab() {
    if (_weeklyActivity.isEmpty) {
      return const Center(
        child: Text(
          'データがありません',
          style: TextStyle(color: Color(0xFF94A3B8)),
        ),
      );
    }

    // バーの最大値を計算
    int maxNotes = 1;
    int maxTasks = 1;
    for (final day in _weeklyActivity) {
      final n = (day['notes'] as num?)?.toInt() ?? 0;
      final t = (day['tasks'] as num?)?.toInt() ?? 0;
      if (n > maxNotes) maxNotes = n;
      if (t > maxTasks) maxTasks = t;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '過去7日間の活動推移',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 20),
          // ノート数バーチャート
          _barChartSection(
            'ノート作成数',
            Icons.note_alt,
            Color(0xFF7C3AED),
            _weeklyActivity,
            'notes',
            maxNotes,
          ),
          const SizedBox(height: 24),
          // タスク完了数バーチャート
          _barChartSection(
            'タスク完了数',
            Icons.task_alt,
            Color(0xFF059669),
            _weeklyActivity,
            'tasks',
            maxTasks,
          ),
          const SizedBox(height: 24),
          // 集中時間棒グラフ
          _buildFocusChart(),
        ],
      ),
    );
  }

  Widget _barChartSection(
    String title,
    IconData icon,
    Color color,
    List<Map<String, dynamic>> data,
    String key,
    int maxVal,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: data.map((day) {
              final val = (day[key] as num?)?.toInt() ?? 0;
              final heightRatio = maxVal > 0 ? val / maxVal : 0.0;
              final dateLabel = day['date'] as String? ?? '';
              return Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (val > 0)
                      Text(
                        val.toString(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: heightRatio.clamp(0.02, 1.0),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: val > 0
                                  ? color
                                  : color.withValues(alpha: 0.15),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateLabel,
                      style: const TextStyle(
                        fontSize: 9,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildFocusChart() {
    int maxFocus = 1;
    for (final day in _weeklyActivity) {
      final f = (day['focus_min'] as num?)?.toInt() ?? 0;
      if (f > maxFocus) maxFocus = f;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.timer, size: 16, color: Color(0xFFDC2626)),
            SizedBox(width: 6),
            Text(
              '集中時間 (分)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFFDC2626),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: _weeklyActivity.map((day) {
              final val = (day['focus_min'] as num?)?.toInt() ?? 0;
              final heightRatio = maxFocus > 0 ? val / maxFocus : 0.0;
              final dateLabel = day['date'] as String? ?? '';
              return Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (val > 0)
                      Text(
                        val.toString(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    const SizedBox(height: 2),
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: heightRatio.clamp(0.02, 1.0),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: val > 0
                                  ? Color(0xFFDC2626)
                                  : Color(0xFFDC2626)
                                      .withValues(alpha: 0.15),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateLabel,
                      style: const TextStyle(
                        fontSize: 9,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildHabitsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '習慣トラッキング',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '毎日の習慣状況を把握してストリークを維持しよう',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          if (_habitStats.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Column(
                  children: [
                    Icon(Icons.loop, size: 48, color: Color(0xFF94A3B8)),
                    SizedBox(height: 12),
                    Text(
                      '習慣を登録するとここに表示されます',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._habitStats.map((habit) => _habitCard(habit)),
          const SizedBox(height: 24),
          // 習慣ヒント
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Color(0xFFBBF7D0)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 16,
                      color: Color(0xFF059669),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'AIコーチのヒント',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  '習慣は21日間続けると定着すると言われています。まず3つの小さな習慣から始めて、徐々にルーティンを広げていきましょう。ストリークが7日を超えると達成感が高まります。',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF065F46),
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _habitCard(Map<String, dynamic> habit) {
    final name = habit['name'] as String? ?? '習慣';
    final streak = (habit['streak'] as num?)?.toInt() ?? 0;
    final completedToday = habit['completed_today'] as bool? ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: completedToday
              ? Color(0xFF059669)
              : Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: completedToday
                  ? Color(0xFF059669)
                  : Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: Icon(
              completedToday ? Icons.check : Icons.radio_button_unchecked,
              size: 20,
              color: completedToday ? Colors.white : Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  completedToday ? '今日完了 ✓' : '今日未完了',
                  style: TextStyle(
                    fontSize: 11,
                    color: completedToday
                        ? Color(0xFF059669)
                        : Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '🔥 $streak日',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFF59E0B),
                ),
              ),
              const Text(
                'ストリーク',
                style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
