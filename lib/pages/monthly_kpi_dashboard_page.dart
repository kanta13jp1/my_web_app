import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/kgi_csf_kpi.dart';
import '../services/monthly_kpi_service.dart';
import '../widgets/kgi_csf_kpi_panel.dart';

const _monthlyKpiLevelColors = {
  'dream': Color(0xFF7C3AED),
  'big': Color(0xFF2563EB),
  'medium': Color(0xFF0891B2),
  'small': Color(0xFF16A34A),
};
const _monthlyKpiLevelLabels = {
  'dream': '人生の夢',
  'big': '年間目標',
  'medium': '四半期目標',
  'small': '今月の行動',
};
const _monthlyKpiLevelKgi = {
  'dream': '人生の北極星を実現する',
  'big': '年間ゴールを前進させる',
  'medium': '四半期マイルストンを今月進める',
  'small': '今月の実行を積み上げる',
};

class MonthlyKpiDashboardPage extends StatefulWidget {
  const MonthlyKpiDashboardPage({super.key});

  @override
  State<MonthlyKpiDashboardPage> createState() =>
      _MonthlyKpiDashboardPageState();
}

class _MonthlyKpiDashboardPageState extends State<MonthlyKpiDashboardPage> {
  final _supabase = Supabase.instance.client;
  final _kpiService = const MonthlyKpiService();
  final _monthFormat = DateFormat('yyyy年M月', 'ja_JP');

  bool _loading = true;
  bool _adviceLoading = false;
  String? _error;
  MonthlyKpiLedger? _ledger;
  List<String> _advice = const [];

  static const _levelOrder = ['dream', 'big', 'medium', 'small'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'ログイン後に月次 KPI レポートを表示できます。';
        });
        return;
      }

      final now = DateTime.now();
      final previousMonthStart = DateTime(now.year, now.month - 1);
      final nextMonthStart = DateTime(now.year, now.month + 1);
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
            .gte('created_at', previousMonthStart.toUtc().toIso8601String())
            .lt('created_at', nextMonthStart.toUtc().toIso8601String()),
      ]);

      final ledger = _kpiService.buildLedger(
        goals: List<Map<String, dynamic>>.from(results[0] as List),
        reviews: List<Map<String, dynamic>>.from(results[1] as List),
        now: now,
      );
      final fallback = _kpiService.fallbackAdvice(ledger, now);

      if (!mounted) return;
      setState(() {
        _ledger = ledger;
        _advice = fallback;
        _loading = false;
      });
      unawaited(_loadAiAdvice(ledger, now));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '月次 KPI の読み込みに失敗しました: $error';
      });
    }
  }

  Future<void> _loadAiAdvice(MonthlyKpiLedger ledger, DateTime now) async {
    if (!mounted) return;
    setState(() => _adviceLoading = true);
    try {
      final response = await _supabase.functions.invoke(
        'ai-hub',
        body: {
          'action': 'kpi.monthly_summary',
          'ledger': ledger.toJson(),
          'goals': ledger.metrics.take(12).map((metric) => metric.toJson()).toList(),
        },
      );
      final advice = _extractAdvice(response.data);
      if (!mounted) return;
      setState(() {
        _advice = advice.isEmpty ? _kpiService.fallbackAdvice(ledger, now) : advice;
        _adviceLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _advice = _kpiService.fallbackAdvice(ledger, now);
        _adviceLoading = false;
      });
    }
  }

  List<String> _extractAdvice(Object? data) {
    final map = data is Map<String, dynamic>
        ? data
        : data is Map
            ? Map<String, dynamic>.from(data)
            : null;
    if (map == null || map['success'] != true) return const [];
    final actions = map['actions'];
    if (actions is List) {
      return actions
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .take(4)
          .toList();
    }
    final advice = map['advice']?.toString().trim();
    if (advice == null || advice.isEmpty) return const [];
    return advice
        .split(RegExp(r'\n+'))
        .map((line) => line.replaceFirst(RegExp(r'^[-*0-9.、\s]+'), '').trim())
        .where((line) => line.isNotEmpty)
        .take(4)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final ledger = _ledger;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('月次 KPI レポート'),
        actions: [
          IconButton(
            tooltip: '再読み込み',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      _EmptyState(message: _error!),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _HeaderBand(
                        title: _monthFormat.format(ledger!.monthStart),
                        subtitle: '${ledger.goalCount} 件の LifeGoals から月次 KPI を自動集計',
                      ),
                      const SizedBox(height: 12),
                      _SummaryGrid(ledger: ledger),
                      const SizedBox(height: 16),
                      _AdvicePanel(
                        advice: _advice,
                        loading: _adviceLoading,
                        onRefresh: () => _loadAiAdvice(ledger, DateTime.now()),
                      ),
                      const SizedBox(height: 16),
                      for (final level in _levelOrder) ...[
                        KgiCsfKpiPanel(
                          plan: _buildPlan(ledger, level),
                          accentColor: _monthlyKpiLevelColors[level]!,
                          dark: isDark,
                          initiallyExpanded: level == 'small',
                        ),
                        const SizedBox(height: 10),
                      ],
                      _AtRiskSection(
                        metrics: ledger.atRiskGoals(DateTime.now()),
                      ),
                      const SizedBox(height: 16),
                      _MetricLedger(metrics: ledger.metrics),
                      const SizedBox(height: 32),
                    ],
                  ),
      ),
    );
  }

  KgiCsfKpiPlan _buildPlan(MonthlyKpiLedger ledger, String level) {
    final metrics =
        ledger.metrics.where((metric) => metric.goal.level == level).toList();
    final averageProgress = metrics.isEmpty
        ? 0.0
        : metrics
                .map((metric) => metric.goal.progress)
                .reduce((sum, value) => sum + value) /
            metrics.length;
    return KgiCsfKpiPlan(
      domain: _monthlyKpiLevelLabels[level]!,
      kgi: _monthlyKpiLevelKgi[level]!,
      actualLabel: '${averageProgress.toStringAsFixed(0)}%',
      targetLabel: '100%',
      progress: averageProgress / 100,
      metrics: metrics
          .map(
            (metric) => KgiCsfKpiMetric.number(
              csf: _truncate(metric.goal.title, 32),
              kpi:
                  '今月 ${_formatSigned(metric.currentMonthDelta)}pt / 前月比 ${_formatSigned(metric.monthOverMonthDelta)}pt',
              actual: metric.goal.progress,
              target: 100,
              unit: '%',
              remainingUnit: '%',
            ),
          )
          .toList(),
    );
  }

  String _truncate(String value, int max) =>
      value.length <= max ? value : '${value.substring(0, max)}...';

  String _formatSigned(double value) {
    if (value > 0) return '+${value.toStringAsFixed(1)}';
    return value.toStringAsFixed(1);
  }
}

class _HeaderBand extends StatelessWidget {
  final String title;
  final String subtitle;

  const _HeaderBand({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final muted = isDark ? Colors.white70 : const Color(0xFF64748B);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.insights, color: Color(0xFF0F766E)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  final MonthlyKpiLedger ledger;

  const _SummaryGrid({required this.ledger});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth >= 720
            ? (constraints.maxWidth - 36) / 4
            : constraints.maxWidth >= 420
                ? (constraints.maxWidth - 12) / 2
                : constraints.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _SummaryCard(
              width: width,
              icon: Icons.flag_outlined,
              label: '目標値',
              value: '100%',
              detail: '各 LifeGoal の月次到達目標',
              color: const Color(0xFF2563EB),
            ),
            _SummaryCard(
              width: width,
              icon: Icons.trending_up,
              label: '実績値',
              value: '${ledger.averageProgress.toStringAsFixed(1)}%',
              detail: '${ledger.completedCount}/${ledger.goalCount} 件完了',
              color: const Color(0xFF16A34A),
            ),
            _SummaryCard(
              width: width,
              icon: Icons.speed,
              label: '進捗率',
              value: '${(ledger.progressRate * 100).toStringAsFixed(0)}%',
              detail: '平均進捗ベース',
              color: const Color(0xFF0F766E),
            ),
            _SummaryCard(
              width: width,
              icon: Icons.compare_arrows,
              label: '前月比',
              value: _formatSigned(ledger.monthOverMonthDelta, suffix: 'pt'),
              detail:
                  '今月 ${_formatSigned(ledger.currentMonthDeltaAverage, suffix: 'pt')} / 前月 ${_formatSigned(ledger.previousMonthDeltaAverage, suffix: 'pt')}',
              color: ledger.monthOverMonthDelta >= 0
                  ? const Color(0xFF16A34A)
                  : const Color(0xFFDC2626),
            ),
          ],
        );
      },
    );
  }

  String _formatSigned(double value, {String suffix = ''}) {
    final text = value > 0 ? '+${value.toStringAsFixed(1)}' : value.toStringAsFixed(1);
    return '$text$suffix';
  }
}

class _SummaryCard extends StatelessWidget {
  final double width;
  final IconData icon;
  final String label;
  final String value;
  final String detail;
  final Color color;

  const _SummaryCard({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final muted = isDark ? Colors.white70 : const Color(0xFF64748B);
    return SizedBox(
      width: width,
      child: Container(
        constraints: const BoxConstraints(minHeight: 122),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF111827) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.26)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                color: textColor,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              detail,
              style: TextStyle(
                color: muted,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdvicePanel extends StatelessWidget {
  final List<String> advice;
  final bool loading;
  final VoidCallback onRefresh;

  const _AdvicePanel({
    required this.advice,
    required this.loading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF7C3AED).withValues(alpha: 0.24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Color(0xFF7C3AED)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'AI KPI 達成アドバイス',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    height: 1.35,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'AI アドバイス更新',
                onPressed: loading ? null : onRefresh,
                icon: loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final item in advice) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 7),
                  child: Icon(Icons.check_circle, size: 14, color: Color(0xFF7C3AED)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

class _AtRiskSection extends StatelessWidget {
  final List<MonthlyKpiMetric> metrics;

  const _AtRiskSection({required this.metrics});

  @override
  Widget build(BuildContext context) {
    if (metrics.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          '期限リスク',
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 8),
        for (final metric in metrics.take(4)) ...[
          _MetricRow(metric: metric, compact: true),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _MetricLedger extends StatelessWidget {
  final List<MonthlyKpiMetric> metrics;

  const _MetricLedger({required this.metrics});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    if (metrics.isEmpty) {
      return const _EmptyState(
        message: 'LifeGoals がまだありません。目標管理ページで今月の KPI 候補を作成してください。',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'KPI 明細',
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 8),
        for (final metric in metrics) ...[
          _MetricRow(metric: metric),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  final MonthlyKpiMetric metric;
  final bool compact;

  const _MetricRow({
    required this.metric,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final muted = isDark ? Colors.white70 : const Color(0xFF64748B);
    final color =
        _monthlyKpiLevelColors[metric.goal.level] ?? const Color(0xFF0F766E);
    final targetDate = metric.goal.targetDate;
    final targetLabel = targetDate == null
        ? '期限なし'
        : DateFormat('yyyy/MM/dd').format(targetDate);

    return Container(
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: compact
              ? const Color(0xFFF59E0B).withValues(alpha: 0.45)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 32,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      metric.goal.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_monthlyKpiLevelLabels[metric.goal.level] ?? metric.goal.level} / $targetLabel',
                      style: TextStyle(
                        color: muted,
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${metric.goal.progress}%',
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: metric.progressRate.clamp(0, 1).toDouble(),
              minHeight: 7,
              backgroundColor: color.withValues(alpha: 0.14),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          if (!compact) ...[
            const SizedBox(height: 8),
            Text(
              '今月 ${_formatSigned(metric.currentMonthDelta)}pt / 前月 ${_formatSigned(metric.previousMonthDelta)}pt / 前月比 ${_formatSigned(metric.monthOverMonthDelta)}pt',
              style: TextStyle(
                color: muted,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatSigned(double value) {
    if (value > 0) return '+${value.toStringAsFixed(1)}';
    return value.toStringAsFixed(1);
  }
}

class _EmptyState extends StatelessWidget {
  final String message;

  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF0F172A),
          fontSize: 13,
          height: 1.5,
        ),
      ),
    );
  }
}
