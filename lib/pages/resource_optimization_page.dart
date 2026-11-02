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
  bool _loading = false;
  bool _requestingAi = false;
  String? _error;
  String _aiStatus = 'not_requested';
  int _days = 90;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? const ResourceOptimizationService();
    _load();
  }

  Future<void> _load() async {
    if (_loading || _requestingAi) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final report = await _service.analyze(days: _days);
      if (!mounted) return;
      setState(() {
        _report = report;
        _aiStatus = 'not_requested';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadAi() async {
    if (_loading || _requestingAi) return;
    setState(() {
      _requestingAi = true;
      _error = null;
    });
    try {
      final analysis = await _service.analyzeWithAiConsent(days: _days);
      if (!mounted) return;
      setState(() {
        _report = analysis.report;
        _aiStatus = analysis.aiStatus;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _aiStatus = 'request_failed');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('AI提案を取得できませんでした。現在の統計分析を継続表示します。'),
        ),
      );
    } finally {
      if (mounted) setState(() => _requestingAi = false);
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
            onPressed: _loading || _requestingAi ? null : _load,
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
                onSelectionChanged: _loading || _requestingAi
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
          children: [
            const SizedBox(height: 80),
            const Icon(Icons.insights_outlined, size: 56),
            const SizedBox(height: 16),
            const Text(
              '分析できる実績がまだありません',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              '習慣完了後に「実績を修正」から所要時間・疲労度・目標貢献度を自己申告で保存してください。'
              '分析には各習慣7件以上かつ値の分散が必要です。',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            _buildMeasurementNotice(),
            if (report != null) ...[
              const SizedBox(height: 12),
              _buildAiStatus(report),
            ],
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
          const SizedBox(height: 12),
          _buildMeasurementNotice(),
          const SizedBox(height: 12),
          _buildAiStatus(report),
          const SizedBox(height: 12),
          _buildAiConsentCard(report),
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
            title: 'メンター提案',
            trailing: report.generatedBy == 'gemini' ? 'Gemini生成' : '統計分析',
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

  Widget _buildMeasurementNotice() {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '目標貢献度は実際の目標達成率ではなく、習慣完了時の自己申告proxyです。'
              '分析には習慣ごとに最低7件、かつ目標貢献度と時間または疲労度の値に分散が必要です。',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiStatus(ResourceOptimizationReport report) {
    final colors = Theme.of(context).colorScheme;
    final generated =
        report.generatedBy == 'gemini' && _aiStatus == 'generated';
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const Key('resource_optimization_ai_status'),
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:
              generated ? colors.primaryContainer : colors.secondaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(_aiStatusMessage(_aiStatus)),
      ),
    );
  }

  Widget _buildAiConsentCard(ResourceOptimizationReport report) {
    final colors = Theme.of(context).colorScheme;
    final generated =
        report.generatedBy == 'gemini' && _aiStatus == 'generated';
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
            'Geminiへの外部送信',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            '下のボタンを押した場合のみ、Google Geminiに集計済みデータを外部送信します。'
            '通常表示・期間変更・再分析では外部AIを使いません。',
          ),
          const SizedBox(height: 8),
          const Text(
            '送信項目: 分析期間、習慣ID・習慣名・目標名、記録件数、'
            '時間・疲労度・自己申告目標貢献度の平均、'
            '貢献度の測定元・proxy判定・分散・十分性と不足理由、'
            '資源コスト・効率・相関・パレート判定（最大50習慣）。'
            '個々の完了記録は送信しません。',
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('resource_optimization_ai_generate'),
            onPressed: _requestingAi ? null : _loadAi,
            icon: _requestingAi
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text(
              _requestingAi
                  ? 'AI提案を生成中'
                  : generated
                      ? '同意してAI提案を再生成'
                      : '同意してAI提案を生成',
            ),
          ),
        ],
      ),
    );
  }

  String _aiStatusMessage(String status) {
    return switch (status) {
      'generated' => 'Google Geminiで生成したAI提案を表示しています。',
      'cooldown' => 'AIの連続利用を防ぐ待機時間中のため、統計分析を表示しています。',
      'daily_limit' => '本日のAI利用上限に達したため、統計分析を表示しています。',
      'quota_unavailable' => 'AI利用枠を確認できなかったため、外部送信せず統計分析を表示しています。',
      'upstream_unavailable' => 'Geminiから提案を取得できなかったため、統計分析を表示しています。',
      'not_configured' => 'AI機能が未設定のため、統計分析を表示しています。',
      'no_data' => '分析できる記録がないため、AIへ送信していません。',
      'insufficient_data' => '7件以上・分散ありの条件を満たす習慣がないため、AIへ送信していません。',
      'request_failed' => 'AI提案の通信に失敗したため、現在の統計分析を表示しています。',
      'not_requested' => 'この結果は統計分析です。第三者AIへは送信していません。',
      _ => 'AI提案は生成されていません。統計分析を表示しています。',
    };
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
