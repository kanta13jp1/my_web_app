import 'package:flutter/material.dart';

import '../models/resource_optimization.dart';
import '../services/resource_optimization_service.dart';
import '../widgets/habit_pareto_chart.dart';

class ResourceOptimizationPage extends StatefulWidget {
  const ResourceOptimizationPage({super.key, this.service});

  final ResourceOptimizationService? service;

  @override
  State<ResourceOptimizationPage> createState() =>
      _ResourceOptimizationPageState();
}

class _ResourceOptimizationPageState extends State<ResourceOptimizationPage> {
  late final ResourceOptimizationService _service;
  ResourceOptimizationReport? _report;
  bool _loading = true;
  String? _error;
  int _days = 90;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? const ResourceOptimizationService();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final report = await _service.analyze(days: _days);
      if (!mounted) return;
      setState(() => _report = report);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('リソース最適化'),
        actions: [
          IconButton(
            tooltip: '再分析',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 30, label: Text('30日')),
                  ButtonSegment(value: 90, label: Text('90日')),
                  ButtonSegment(value: 180, label: Text('180日')),
                ],
                selected: {_days},
                onSelectionChanged: _loading
                    ? null
                    : (selection) {
                        setState(() => _days = selection.first);
                        _load();
                      },
              ),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 40),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('再試行'),
              ),
            ],
          ),
        ),
      );
    }
    final report = _report;
    if (report == null || !report.hasData) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: const [
            SizedBox(height: 100),
            Icon(Icons.insights_outlined, size: 56),
            SizedBox(height: 16),
            Text(
              '分析できる実績がまだありません',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 8),
            Text(
              '習慣の完了時に所要時間・疲労度・目標貢献度を記録すると、ここに結果が表示されます。',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _buildSummary(report),
          const SizedBox(height: 24),
          _SectionTitle(
            icon: Icons.scatter_plot,
            title: 'パレート境界',
            trailing: '${report.paretoFrontier.length}件',
          ),
          const SizedBox(height: 8),
          HabitParetoChart(metrics: report.metrics),
          const SizedBox(height: 8),
          _buildLegend(),
          const SizedBox(height: 12),
          ...report.paretoFrontier.map(_buildFrontierItem),
          const SizedBox(height: 24),
          _SectionTitle(
            icon: Icons.psychology_outlined,
            title: 'AIメンター提案',
            trailing: report.generatedBy == 'gemini' ? 'AI分析' : '統計分析',
          ),
          const SizedBox(height: 10),
          Text(report.mentorSummary),
          const SizedBox(height: 12),
          ...report.recommendations.map(_buildRecommendation),
          if (report.scalingPlan.isNotEmpty) ...[
            const SizedBox(height: 24),
            const _SectionTitle(icon: Icons.stairs_outlined, title: '段階的な負荷計画'),
            const SizedBox(height: 12),
            ...report.scalingPlan.map(_buildScalingStep),
          ],
        ],
      ),
    );
  }

  Widget _buildSummary(ResourceOptimizationReport report) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${report.windowDays}日間・${report.sampleCount}件の実績',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _CorrelationMetric(
                label: '時間 ↔ 成果',
                value: report.timePerformanceCorrelation,
              ),
              _CorrelationMetric(
                label: '疲労 ↔ 成果',
                value: report.fatiguePerformanceCorrelation,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return const Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        _LegendDot(color: Color(0xFF168C5A), label: 'パレート最適'),
        _LegendDot(color: Color(0xFF9AA0A6), label: '比較対象'),
      ],
    );
  }

  Widget _buildFrontierItem(HabitResourceMetric metric) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(
        radius: 18,
        backgroundColor: Color(0xFFE3F4EB),
        child: Icon(Icons.trending_up, color: Color(0xFF168C5A), size: 20),
      ),
      title: Text(metric.habitTitle),
      subtitle: Text(
        '${metric.averageTimeMinutes.round()}分 / 疲労${metric.averageFatigueScore.toStringAsFixed(1)} / '
        '貢献${metric.averageGoalContributionScore.round()}% / ${metric.sampleCount}件',
      ),
      trailing: Text(
        metric.efficiencyScore.toStringAsFixed(2),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildRecommendation(ResourceRecommendation recommendation) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF9ED4B9)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF168C5A), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recommendation.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(recommendation.reason),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScalingStep(ResourceScalingStep step) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(radius: 18, child: Text('${step.stage}')),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${step.durationDays}日・負荷 ${(step.loadMultiplier * 100).round()}%',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(step.target),
                const SizedBox(height: 3),
                Text(
                  step.guardrail,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title, this.trailing});

  final IconData icon;
  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 21),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        if (trailing != null) Text(trailing!),
      ],
    );
  }
}

class _CorrelationMetric extends StatelessWidget {
  const _CorrelationMetric({required this.label, required this.value});

  final String label;
  final double? value;

  @override
  Widget build(BuildContext context) {
    final display = value == null ? 'データ不足' : value!.toStringAsFixed(2);
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 3),
          Text(
            display,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}
