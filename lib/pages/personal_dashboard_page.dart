import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../models/kgi_csf_kpi.dart';
import '../widgets/kgi_csf_kpi_panel.dart';
import '../widgets/personal_dashboard_kpi_card.dart';
import 'package:my_web_app/utils/tab_route_url_sync.dart';

enum PersonalDashboardDataMode { live, fallback }

class PersonalDashboardGridSpec {
  const PersonalDashboardGridSpec({
    required this.crossAxisCount,
    required this.childAspectRatio,
  });

  final int crossAxisCount;
  final double childAspectRatio;
}

@visibleForTesting
PersonalDashboardGridSpec personalDashboardGridSpec(double maxWidth) {
  if (maxWidth >= 1180) {
    return const PersonalDashboardGridSpec(
      crossAxisCount: 4,
      childAspectRatio: 1.38,
    );
  }
  if (maxWidth >= 720) {
    return const PersonalDashboardGridSpec(
      crossAxisCount: 2,
      childAspectRatio: 1.28,
    );
  }
  return const PersonalDashboardGridSpec(
    crossAxisCount: 1,
    childAspectRatio: 2.2,
  );
}

@visibleForTesting
double personalDashboardBarHeightFactor({
  required int value,
  required int maxValue,
}) {
  if (value <= 0 || maxValue <= 0) return 0.02;
  return (value / maxValue).clamp(0.02, 1.0).toDouble();
}

@visibleForTesting
bool personalDashboardHasRecordedData({
  required Map<String, dynamic> kpiData,
  required List<Map<String, dynamic>> weeklyActivity,
  required List<Map<String, dynamic>> habitStats,
  required List<Map<String, dynamic>> recentNotes,
}) {
  if (recentNotes.isNotEmpty) return true;
  if (habitStats.any((habit) {
    final streak = (habit['streak'] as num?)?.toInt() ?? 0;
    final completedToday = habit['completed_today'] as bool? ?? false;
    return streak > 0 || completedToday;
  })) {
    return true;
  }
  if (weeklyActivity.any((day) {
    final notes = (day['notes'] as num?)?.toInt() ?? 0;
    final tasks = (day['tasks'] as num?)?.toInt() ?? 0;
    final focusMinutes = (day['focus_min'] as num?)?.toInt() ?? 0;
    return notes > 0 || tasks > 0 || focusMinutes > 0;
  })) {
    return true;
  }
  return kpiData.entries.any((entry) {
    final value = entry.value;
    return value is num && value > 0;
  });
}

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
    with SingleTickerProviderStateMixin, TabRouteUrlSync {
  @override
  List<String> get tabUrlSlugs => const <String>['kpi', 'weekly', 'habits'];

  @override
  TabController get tabUrlController => _tabController;

  final _supabase = Supabase.instance.client;
  late final TabController _tabController;

  bool _isLoading = false;
  String? _errorMessage;
  PersonalDashboardDataMode _dataMode = PersonalDashboardDataMode.fallback;
  bool _hasRecordedData = false;
  DateTime? _lastLoadedAt;

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
    if (_supabase.auth.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
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
        'core-hub',
        body: {'action': 'personal.dashboard'},
      );

      if (!mounted) return;

      final data = res.data as Map<String, dynamic>? ?? {};
      final kpiData = _normalizeKpi(data['kpi']);
      final weeklyActivity = _normalizeWeeklyActivity(data['weekly_activity']);
      final habitStats = _normalizeHabitStats(data['habit_stats']);
      final recentNotes = _normalizeRecentNotes(data['recent_notes']);
      final hasRecordedData = personalDashboardHasRecordedData(
        kpiData: kpiData,
        weeklyActivity: weeklyActivity,
        habitStats: habitStats,
        recentNotes: recentNotes,
      );
      setState(() {
        _dataMode = PersonalDashboardDataMode.live;
        _hasRecordedData = hasRecordedData;
        _lastLoadedAt = DateTime.now();
        _kpiData = kpiData;
        _weeklyActivity =
            weeklyActivity.isEmpty ? _buildFallbackWeekly() : weeklyActivity;
        _habitStats = habitStats;
        _recentNotes = recentNotes;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _dataMode = PersonalDashboardDataMode.fallback;
        _hasRecordedData = false;
        _lastLoadedAt = DateTime.now();
        _kpiData = _buildFallbackKpi();
        _weeklyActivity = _buildFallbackWeekly();
        _habitStats = _buildFallbackHabits();
        _recentNotes = const [];
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

  List<Map<String, dynamic>> _buildFallbackHabits() => const [];

  Map<String, dynamic> _normalizeKpi(Object? raw) {
    if (raw is! Map<String, dynamic>) return _buildFallbackKpi();
    return {
      'total_notes': (raw['total_notes'] as num?)?.toInt() ?? 0,
      'tasks_completed': (raw['tasks_completed'] as num?)?.toInt() ?? 0,
      'focus_minutes': (raw['focus_minutes'] as num?)?.toInt() ?? 0,
      'habit_streak': (raw['habit_streak'] as num?)?.toInt() ?? 0,
      'note_growth': (raw['note_growth'] as num?)?.toInt() ?? 0,
      'task_rate': (raw['task_rate'] as num?)?.toDouble() ?? 0.0,
    };
  }

  List<Map<String, dynamic>> _normalizeWeeklyActivity(Object? raw) {
    if (raw is! List) return const [];
    return raw.whereType<Map<String, dynamic>>().map((day) {
      final dateLabel = '${day['date'] ?? ''}'.trim();
      return {
        'date': dateLabel.isEmpty ? '--/--' : dateLabel,
        'notes': (day['notes'] as num?)?.toInt() ?? 0,
        'tasks': (day['tasks'] as num?)?.toInt() ?? 0,
        'focus_min': (day['focus_min'] as num?)?.toInt() ?? 0,
      };
    }).toList();
  }

  List<Map<String, dynamic>> _normalizeHabitStats(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map((habit) {
          final name = '${habit['name'] ?? ''}'.trim();
          if (name.isEmpty) return <String, dynamic>{};
          return {
            'name': name,
            'streak': (habit['streak'] as num?)?.toInt() ?? 0,
            'completed_today': habit['completed_today'] as bool? ?? false,
          };
        })
        .where((habit) => habit.isNotEmpty)
        .toList();
  }

  List<Map<String, dynamic>> _normalizeRecentNotes(Object? raw) {
    if (raw is! List) return const [];
    return raw.whereType<Map<String, dynamic>>().map((note) {
      return {
        'title': '${note['title'] ?? ''}'.trim(),
        'updated_at': note['updated_at'],
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('パーソナルダッシュボード'),
        backgroundColor: const Color(0xFF0891B2),
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
                        color: Color(0xFFB0B0B0),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Color(0xFFB0B0B0),
                          height: 1.5,
                        ),
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

  Widget _buildDashboardStatusCard({bool compact = false}) {
    final isFallback = _dataMode == PersonalDashboardDataMode.fallback;
    final statusColor =
        isFallback ? const Color(0xFFF59E0B) : const Color(0xFF0891B2);
    final backgroundColor =
        isFallback ? const Color(0xFFFFFBEB) : const Color(0xFFF0F9FF);
    final borderColor =
        isFallback ? const Color(0xFFFCD34D) : const Color(0xFFBAE6FD);
    final statusLabel = isFallback ? 'FALLBACK 0データ' : 'LIVEデータ';
    final recordLabel = _hasRecordedData ? '記録あり' : 'まだ記録前';
    final timestamp = _lastLoadedAt == null
        ? null
        : DateFormat('MM/dd HH:mm').format(_lastLoadedAt!);
    final description = isFallback
        ? 'personal-dashboard Edge Function に接続できなかったため、安全な 0 データで表示しています。接続が戻ると自動で実データに置き換わります。'
        : _hasRecordedData
            ? 'Supabase から取得した実データを表示しています。ノート、タスク、集中、習慣を週次のKPIとして確認できます。'
            : 'Supabase には接続できています。まだ実績が少ないため 0 中心ですが、棒グラフは空白にならないよう最小表示しています。';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _statusChip(statusLabel, statusColor),
              _statusChip(recordLabel, const Color(0xFF475569)),
              if (timestamp != null)
                _statusChip('最終取得 $timestamp', const Color(0xFF64748B)),
            ],
          ),
          SizedBox(height: compact ? 8 : 10),
          Text(
            description,
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              color: const Color(0xFF334155),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          height: 1.4,
        ),
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
    final noteSubtitle = noteGrowth > 0 ? '+$noteGrowth 今週' : '記録が増えると週次差分を表示';
    final taskSubtitle = taskRate > 0
        ? '達成率 ${(taskRate * 100).toStringAsFixed(0)}%'
        : '記録前でも達成率バーを表示';
    final focusSubtitle =
        focusMinutes > 0 ? '合計 $focusMinutes分' : 'ポモドーロや集中ログを待機中';
    final habitSubtitle = habitStreak >= 7 ? '🔥 週間達成！' : '習慣が入ると継続日数を追跡';

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
              height: 1.4,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '更新: ${DateFormat('MM/dd HH:mm').format(DateTime.now())}',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF94A3B8),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          _buildDashboardStatusCard(),
          const SizedBox(height: 16),
          KgiCsfKpiPanel(
            plan: _buildPersonalKgiPlan(
              totalNotes: totalNotes,
              tasksCompleted: tasksCompleted,
              focusMinutes: focusMinutes,
              habitStreak: habitStreak,
              taskRate: taskRate,
            ),
            accentColor: const Color(0xFF0891B2),
            initiallyExpanded: true,
          ),
          const SizedBox(height: 16),
          // KPI グリッド
          LayoutBuilder(
            builder: (context, constraints) {
              final gridSpec = personalDashboardGridSpec(constraints.maxWidth);
              return GridView.count(
                crossAxisCount: gridSpec.crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: gridSpec.childAspectRatio,
                children: [
                  PersonalDashboardKpiCard(
                    label: '総ノート数',
                    value: totalNotes.toString(),
                    icon: Icons.note_alt,
                    color: const Color(0xFF7C3AED),
                    subtitle: noteSubtitle,
                  ),
                  PersonalDashboardKpiCard(
                    label: 'タスク完了',
                    value: tasksCompleted.toString(),
                    icon: Icons.task_alt,
                    color: const Color(0xFF059669),
                    subtitle: taskSubtitle,
                  ),
                  PersonalDashboardKpiCard(
                    label: '集中時間',
                    value: focusHours,
                    icon: Icons.timer,
                    color: const Color(0xFFDC2626),
                    subtitle: focusSubtitle,
                  ),
                  PersonalDashboardKpiCard(
                    label: '習慣ストリーク',
                    value: '$habitStreak日',
                    icon: Icons.local_fire_department,
                    color: const Color(0xFFF59E0B),
                    subtitle: habitSubtitle,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          // タスク達成率バー
          const Text(
            'タスク達成率',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: taskRate.clamp(0.0, 1.0),
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF059669)),
              minHeight: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            taskRate > 0
                ? '${(taskRate * 100).toStringAsFixed(1)}% 完了'
                : 'まだ実績がありません。タスクを完了するとここが伸びます。',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          // 最近のノート
          if (_recentNotes.isNotEmpty) ...[
            const Text(
              '最近のノート',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
                height: 1.5,
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
                    height: 1.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  dateStr,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                    height: 1.5,
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
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  KgiCsfKpiPlan _buildPersonalKgiPlan({
    required int totalNotes,
    required int tasksCompleted,
    required int focusMinutes,
    required int habitStreak,
    required double taskRate,
  }) {
    final taskRatePercent = (taskRate * 100).clamp(0, 100).toDouble();
    final metrics = <KgiCsfKpiMetric>[
      KgiCsfKpiMetric.number(
        csf: '知識資産化',
        kpi: '総ノート数',
        actual: totalNotes,
        target: 30,
        unit: '件',
      ),
      KgiCsfKpiMetric.number(
        csf: '実行完了',
        kpi: 'タスク完了数',
        actual: tasksCompleted,
        target: 10,
        unit: '件',
      ),
      KgiCsfKpiMetric.number(
        csf: '集中投資',
        kpi: '集中時間',
        actual: focusMinutes,
        target: 240,
        unit: '分',
      ),
      KgiCsfKpiMetric.number(
        csf: '習慣継続',
        kpi: 'ストリーク',
        actual: habitStreak,
        target: 7,
        unit: '日',
      ),
    ];
    return KgiCsfKpiPlan(
      domain: '個人生産性',
      kgi: '週次の自己生産性を前週より高く保つ',
      actualLabel: 'タスク達成率 ${taskRatePercent.toStringAsFixed(0)}%',
      targetLabel: '70%以上',
      progress: (taskRatePercent / 70).clamp(0, 1).toDouble(),
      metrics: metrics,
    );
  }

  Widget _buildWeeklyTab() {
    if (_weeklyActivity.isEmpty) {
      return const Center(
        child: Text(
          'データがありません',
          style: TextStyle(
            color: Color(0xFF94A3B8),
            height: 1.5,
          ),
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
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          _buildDashboardStatusCard(compact: true),
          const SizedBox(height: 20),
          // ノート数バーチャート
          _barChartSection(
            'ノート作成数',
            Icons.note_alt,
            const Color(0xFF7C3AED),
            _weeklyActivity,
            'notes',
            maxNotes,
          ),
          const SizedBox(height: 24),
          // タスク完了数バーチャート
          _barChartSection(
            'タスク完了数',
            Icons.task_alt,
            const Color(0xFF059669),
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
    final total = data.fold<int>(0, (sum, day) {
      return sum + ((day[key] as num?)?.toInt() ?? 0);
    });
    final allZero = total == 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                    height: 1.5,
                  ),
                ),
              ],
            ),
            Text(
              allZero ? '記録前' : '合計 $total',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF64748B),
                height: 1.5,
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
                          height: 1.5,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: personalDashboardBarHeightFactor(
                            value: val,
                            maxValue: maxVal,
                          ),
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
                        fontSize: 10,
                        height: 1.5,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        if (allZero) ...[
          const SizedBox(height: 8),
          const Text(
            '0の日でも棒を細く残しています。記録が入り始めると高さが伸びて、空白の週になりません。',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF64748B),
              height: 1.5,
            ),
          ),
        ],
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
                height: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _weeklyActivity.every(
            (day) => ((day['focus_min'] as num?)?.toInt() ?? 0) == 0,
          )
              ? '集中ログがまだ無いので、最小バーで7日分の枠だけ見せています。'
              : '集中セッションが増えると、この棒グラフで日ごとの差が追えます。',
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF64748B),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: _weeklyActivity.map((day) {
              final val = (day['focus_min'] as num?)?.toInt() ?? 0;
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
                          height: 1.5,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: personalDashboardBarHeightFactor(
                            value: val,
                            maxValue: maxFocus,
                          ),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: val > 0
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFFDC2626)
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
                        fontSize: 10,
                        height: 1.5,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
              height: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '毎日の習慣状況を把握してストリークを維持しよう',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          _buildDashboardStatusCard(compact: true),
          const SizedBox(height: 16),
          if (_habitStats.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Column(
                  children: [
                    const Icon(Icons.loop, size: 48, color: Color(0xFF94A3B8)),
                    const SizedBox(height: 12),
                    Text(
                      _dataMode == PersonalDashboardDataMode.fallback
                          ? '習慣データを取得できなかったため、いまは空の状態で表示しています'
                          : '習慣を登録するとここに表示されます',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 13,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'まずはハードルの低い習慣を1つだけ登録して、継続日数を伸ばしていくのがおすすめです。',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                        height: 1.6,
                      ),
                      textAlign: TextAlign.center,
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
              color: isDark ? const Color(0xFF0A1A0A) : const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    isDark ? const Color(0xFF1A3A1A) : const Color(0xFFBBF7D0),
              ),
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
                        height: 1.5,
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

    final isDarkHabit = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkHabit ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: completedToday
              ? const Color(0xFF059669)
              : (isDarkHabit
                  ? const Color(0xFF2A2A2A)
                  : const Color(0xFFE2E8F0)),
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
                  ? const Color(0xFF059669)
                  : const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: Icon(
              completedToday ? Icons.check : Icons.radio_button_unchecked,
              size: 20,
              color: completedToday ? Colors.white : const Color(0xFF94A3B8),
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
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  completedToday ? '今日完了 ✓' : '今日未完了',
                  style: TextStyle(
                    fontSize: 11,
                    color: completedToday
                        ? const Color(0xFF059669)
                        : const Color(0xFF94A3B8),
                    height: 1.5,
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
                  height: 1.5,
                ),
              ),
              const Text(
                'ストリーク',
                style: TextStyle(
                  fontSize: 10,
                  height: 1.5,
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
