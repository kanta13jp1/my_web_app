import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/kgi_csf_kpi.dart';
import '../widgets/kgi_csf_kpi_panel.dart';

class LifeGoalsKpiPage extends StatefulWidget {
  const LifeGoalsKpiPage({super.key});

  @override
  State<LifeGoalsKpiPage> createState() => _LifeGoalsKpiPageState();
}

class _LifeGoalsKpiPageState extends State<LifeGoalsKpiPage> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  List<Map<String, dynamic>> _goals = [];
  List<Map<String, dynamic>> _reviews = [];

  static const _levelOrder = ['dream', 'big', 'medium', 'small'];

  static const _levelColors = {
    'dream': Color(0xFF8B5CF6),
    'big': Color(0xFF6366F1),
    'medium': Color(0xFF3B82F6),
    'small': Color(0xFF10B981),
  };

  static const _levelKgi = {
    'dream': '人生の北極星 — 夢を実現する',
    'big': '年間ゴール — 着実な前進',
    'medium': '四半期マイルストン — 今月の前進',
    'small': '今月のアクション — 完了件数',
  };

  static const _levelDomain = {
    'dream': '夢レイヤー',
    'big': '年間目標',
    'medium': '四半期マイルストン',
    'small': '今月のアクション',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final now = DateTime.now();
      final monthStart =
          DateTime(now.year, now.month, 1).toUtc().toIso8601String();
      final results = await Future.wait([
        _supabase
            .from('life_goals')
            .select()
            .eq('user_id', userId)
            .neq('status', 'abandoned'),
        _supabase
            .from('life_goal_reviews')
            .select()
            .eq('user_id', userId)
            .gte('created_at', monthStart),
      ]);
      if (mounted) {
        setState(() {
          _goals = List<Map<String, dynamic>>.from(results[0] as List);
          _reviews = List<Map<String, dynamic>>.from(results[1] as List);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _goalsForLevel(String level) =>
      _goals.where((g) => g['level'] == level).toList();

  int _deltaForGoal(String goalId) {
    final reviews = _reviews.where((r) => r['goal_id'] == goalId).toList()
      ..sort(
        (a, b) =>
            (a['created_at'] as String).compareTo(b['created_at'] as String),
      );
    if (reviews.isEmpty) return 0;
    final first = (reviews.first['progress_before'] as int?) ?? 0;
    final last = (reviews.last['progress_after'] as int?) ?? 0;
    return (last - first).clamp(0, 100);
  }

  double _avgProgress(List<Map<String, dynamic>> goals) {
    if (goals.isEmpty) return 0;
    final total =
        goals.fold<int>(0, (sum, g) => sum + ((g['progress'] as int?) ?? 0));
    return total / goals.length;
  }

  double _avgDelta(List<Map<String, dynamic>> goals) {
    if (goals.isEmpty) return 0;
    final total =
        goals.fold<int>(0, (sum, g) => sum + _deltaForGoal(g['id'] as String));
    return total / goals.length;
  }

  KgiCsfKpiPlan _buildPlan(String level) {
    final goals = _goalsForLevel(level);

    if (goals.isEmpty) {
      return KgiCsfKpiPlan(
        domain: _levelDomain[level]!,
        kgi: _levelKgi[level]!,
        actualLabel: '—',
        targetLabel: level == 'small' || level == 'medium' ? '10pt/月' : '100%',
        metrics: [],
        progress: 0,
      );
    }

    final metrics = goals.map((g) {
      final progress = (g['progress'] as int?) ?? 0;
      final delta = _deltaForGoal(g['id'] as String);
      if (level == 'medium' || level == 'small') {
        return KgiCsfKpiMetric.number(
          csf: _truncate(g['title'] as String? ?? '(無題)', 30),
          kpi: '累計 $progress% / 今月 +${delta}pt',
          actual: delta,
          target: 10,
          unit: 'pt',
        );
      } else {
        return KgiCsfKpiMetric.number(
          csf: _truncate(g['title'] as String? ?? '(無題)', 30),
          kpi: '達成率',
          actual: progress,
          target: 100,
          unit: '%',
        );
      }
    }).toList();

    if (level == 'medium' || level == 'small') {
      final avg = _avgDelta(goals);
      return KgiCsfKpiPlan(
        domain: _levelDomain[level]!,
        kgi: _levelKgi[level]!,
        actualLabel: '+${avg.toStringAsFixed(1)}pt',
        targetLabel: '10pt/月',
        progress: (avg / 10).clamp(0, 1).toDouble(),
        metrics: metrics,
      );
    } else {
      final avg = _avgProgress(goals);
      return KgiCsfKpiPlan(
        domain: _levelDomain[level]!,
        kgi: _levelKgi[level]!,
        actualLabel: '${avg.toStringAsFixed(0)}%',
        targetLabel: '100%',
        progress: (avg / 100).clamp(0, 1).toDouble(),
        metrics: metrics,
      );
    }
  }

  String _truncate(String s, int max) =>
      s.length <= max ? s : '${s.substring(0, max)}…';

  List<Map<String, dynamic>> _atRiskGoals() {
    final now = DateTime.now();
    final threshold = now.add(const Duration(days: 30));
    return _goals.where((g) {
      final progress = (g['progress'] as int?) ?? 0;
      if (progress >= 80) return false;
      final rawDate = g['target_date'];
      if (rawDate == null) return false;
      try {
        final date = DateTime.parse(rawDate as String);
        return date.isAfter(now) && date.isBefore(threshold);
      } catch (_) {
        return false;
      }
    }).toList()
      ..sort((a, b) {
        final da = DateTime.tryParse(a['target_date'] as String? ?? '') ??
            DateTime(9999);
        final db = DateTime.tryParse(b['target_date'] as String? ?? '') ??
            DateTime(9999);
        return da.compareTo(db);
      });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.white70 : const Color(0xFF475569);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('月次 KPI 台帳')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final smallGoals = _goalsForLevel('small');
    final achievedSmall = smallGoals
        .where(
          (g) =>
              ((g['progress'] as int?) ?? 0) >= 100 ||
              g['status'] == 'completed',
        )
        .length;
    final allDeltas =
        _goals.map((g) => _deltaForGoal(g['id'] as String)).toList();
    final overallAvgDelta = allDeltas.isEmpty
        ? 0.0
        : allDeltas.fold<int>(0, (s, d) => s + d) / allDeltas.length;

    final atRisk = _atRiskGoals();
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: const Text('月次 KPI 台帳'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '再読み込み',
            onPressed: _load,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── 今月のサマリ ──
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.insights,
                        color: Color(0xFF6366F1),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '今月のサマリ',
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _StatChip(
                        label: '平均前進',
                        value: '+${overallAvgDelta.toStringAsFixed(1)}pt',
                        color: const Color(0xFF6366F1),
                        isDark: isDark,
                      ),
                      const SizedBox(width: 12),
                      _StatChip(
                        label: '小目標 達成',
                        value: '$achievedSmall / ${smallGoals.length}件',
                        color: const Color(0xFF10B981),
                        isDark: isDark,
                      ),
                      const SizedBox(width: 12),
                      _StatChip(
                        label: '全目標数',
                        value: '${_goals.length}件',
                        color: const Color(0xFF3B82F6),
                        isDark: isDark,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '今月の総合前進度',
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: (overallAvgDelta / 10).clamp(0, 1).toDouble(),
                      minHeight: 10,
                      backgroundColor:
                          const Color(0xFF6366F1).withValues(alpha: 0.14),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF6366F1),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '目安: 10pt/月 前進で順調',
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── CSF/KPI パネル (4階層) ──
            Text(
              'CSF / KPI 台帳',
              style: TextStyle(
                color: textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            for (final level in _levelOrder) ...[
              KgiCsfKpiPanel(
                plan: _buildPlan(level),
                accentColor: _levelColors[level]!,
                dark: isDark,
                initiallyExpanded: level == 'small',
              ),
              const SizedBox(height: 10),
            ],

            // ── 未達リスク ──
            if (atRisk.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFF59E0B),
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '未達リスク — 30日以内に期限 (progress < 80%)',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              for (final g in atRisk) ...[
                _AtRiskRow(goal: g, now: now, isDark: isDark),
                const SizedBox(height: 8),
              ],
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color.withValues(alpha: 0.75),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AtRiskRow extends StatelessWidget {
  final Map<String, dynamic> goal;
  final DateTime now;
  final bool isDark;

  const _AtRiskRow({
    required this.goal,
    required this.now,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (goal['progress'] as int?) ?? 0;
    final targetDate = DateTime.tryParse(goal['target_date'] as String? ?? '');
    final daysLeft = targetDate?.difference(now).inDays;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.white60 : const Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  goal['title'] as String? ?? '(無題)',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ),
              if (daysLeft != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'あと$daysLeft日',
                    style: const TextStyle(
                      color: Color(0xFFF59E0B),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress / 100,
                    minHeight: 7,
                    backgroundColor:
                        const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$progress%',
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
