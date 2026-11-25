import 'package:flutter/material.dart';

import '../application/prompt_evolution_controller.dart';
import '../domain/prompt_evolution_models.dart';

class PromptEvolutionView extends StatefulWidget {
  const PromptEvolutionView({
    super.key,
    required this.controller,
  });

  final PromptEvolutionController controller;

  @override
  State<PromptEvolutionView> createState() => _PromptEvolutionViewState();
}

class _PromptEvolutionViewState extends State<PromptEvolutionView> {
  static const List<Map<String, Object?>> _sampleHighVarianceTraces =
      <Map<String, Object?>>[
    <String, Object?>{
      'source_type': 'secretary_action',
      'source_id': '11111111-1111-4111-8111-111111111111',
      'goal': 'Reconcile monthly cashflow',
      'plan': <String>['Load ledger', 'Check variance', 'Emit summary'],
      'actions': <String>['load_ledger', 'format_json'],
      'latency_ms': 950,
      'retry_count': 0,
      'output_chars': 520,
      'success': true,
      'status': 'completed',
    },
    <String, Object?>{
      'source_type': 'executive_chat',
      'source_id': '22222222-2222-4222-8222-222222222222',
      'goal': '',
      'plan': <String>[],
      'actions': <String>[],
      'latency_ms': 9400,
      'retry_count': 3,
      'output_chars': 280,
      'success': false,
      'status': 'failed',
    },
  ];

  static const List<Map<String, Object?>> _sampleLowVarianceTraces =
      <Map<String, Object?>>[
    <String, Object?>{
      'source_type': 'secretary_action',
      'source_id': '33333333-3333-4333-8333-333333333333',
      'goal': 'Summarize daily KPI',
      'plan': <String>['Fetch KPI', 'Format table'],
      'actions': <String>['fetch_kpi', 'write_summary'],
      'latency_ms': 850,
      'retry_count': 0,
      'output_chars': 400,
      'success': true,
      'status': 'completed',
    },
    <String, Object?>{
      'source_type': 'secretary_action',
      'source_id': '44444444-4444-4444-8444-444444444444',
      'goal': 'Summarize weekly KPI',
      'plan': <String>['Fetch KPI', 'Format table'],
      'actions': <String>['fetch_kpi', 'write_summary'],
      'latency_ms': 900,
      'retry_count': 0,
      'output_chars': 420,
      'success': true,
      'status': 'completed',
    },
  ];

  late final TextEditingController _thresholdController;
  late final TextEditingController _titleController;
  late final TextEditingController _roleController;
  late final TextEditingController _contextController;
  late final TextEditingController _deliverableController;
  late final TextEditingController _constraintsController;
  late final TextEditingController _thinkingController;
  bool _useHighVarianceSample = true;

  @override
  void initState() {
    super.initState();
    _thresholdController = TextEditingController(text: '0.15');
    _titleController = TextEditingController(
      text: 'Executive Agent Goal-Plan-Action Baseline',
    );
    _roleController = TextEditingController(
      text: 'Autonomous execution planner prioritizing consistency.',
    );
    _contextController = TextEditingController(
      text: 'Use verified Supabase telemetry and workspace state.',
    );
    _deliverableController = TextEditingController(
      text: 'Return an explicit Goal, ordered Plan, and Action trace.',
    );
    _constraintsController = TextEditingController(
      text: 'Fail closed on missing preconditions and schema errors.',
    );
    _thinkingController = TextEditingController(
      text: '1) Clarify goal. 2) Formulate plan. 3) Verify actions.',
    );
  }

  @override
  void dispose() {
    _thresholdController.dispose();
    _titleController.dispose();
    _roleController.dispose();
    _contextController.dispose();
    _deliverableController.dispose();
    _constraintsController.dispose();
    _thinkingController.dispose();
    super.dispose();
  }

  double _parsedThreshold() {
    final parsed = double.tryParse(_thresholdController.text.trim()) ?? 0.15;
    if (parsed <= 0.0) {
      return 0.01;
    }
    if (parsed > 2.0) {
      return 2.0;
    }
    return parsed;
  }

  List<Map<String, Object?>> _selectedTraces() => _useHighVarianceSample
      ? _sampleHighVarianceTraces
      : _sampleLowVarianceTraces;

  PromptEvolutionDraft _currentDraft() => PromptEvolutionDraft(
        title: _titleController.text,
        roleSetting: _roleController.text,
        contextInfo: _contextController.text,
        deliverableDefinition: _deliverableController.text,
        constraintsText: _constraintsController.text,
        thinkingProcess: _thinkingController.text,
      );

  Future<void> _onScoreBatch() async {
    await widget.controller.scoreBatch(
      varianceThreshold: _parsedThreshold(),
      traces: _selectedTraces(),
    );
  }

  Future<void> _onRunEvolution() async {
    final bool ok = await widget.controller.runEvolution(
      varianceThreshold: _parsedThreshold(),
      traces: _selectedTraces(),
      basePrompt: _currentDraft(),
    );
    if (!mounted || !ok) {
      return;
    }
    final PromptEvolutionRunResult? result = widget.controller.runResult;
    if (result != null && result.evolutionTriggered) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '進化的プロンプト候補 (${result.candidates.length}件) を検証しました。',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('進化的プロンプト最適化 (GEPA)'),
        actions: [
          IconButton(
            tooltip: 'GPA 履歴を再読込',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: const Icon(Icons.refresh),
            onPressed: () {
              widget.controller.loadRecentEvaluations();
            },
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final GpaBatchEvaluationReport? batch = widget.controller.batchReport;
          final PromptEvolutionRunResult? runResult =
              widget.controller.runResult;
          final String? errorMessage = widget.controller.errorMessage;
          final List<Map<String, Object?>> recent =
              widget.controller.recentEvaluations;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                  if (errorMessage != null)
                    _EvolutionBanner(
                      backgroundColor: colors.errorContainer,
                      foregroundColor: colors.onErrorContainer,
                      icon: Icons.error_outline,
                      title: '実行エラー / 安全ブロック',
                      body: errorMessage,
                      actionLabel: '再試行',
                      onAction: widget.controller.isLoading
                          ? null
                          : () {
                              widget.controller.loadRecentEvaluations();
                            },
                    ),
                  if (errorMessage != null) const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '1. GPA トレース一貫性・効率性バッチ評価',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'スコア分散がしきい値を超えた場合のみ進化的アルゴリズムでプロンプト候補を生成します。',
                            style: textTheme.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SwitchListTile(
                            key: const ValueKey<String>(
                              'variance_sample_switch',
                            ),
                            contentPadding: EdgeInsets.zero,
                            title: const Text('高分散トレースサンプルを使用'),
                            subtitle: Text(
                              _useHighVarianceSample
                                  ? '失敗トレースを含む高分散データ (進化トリガー対象)'
                                  : '安定した低分散トレース (進化スキップ対象)',
                            ),
                            value: _useHighVarianceSample,
                            onChanged: (value) {
                              setState(() {
                                _useHighVarianceSample = value;
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            key: const ValueKey<String>(
                              'variance_threshold_field',
                            ),
                            controller: _thresholdController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: '分散しきい値 (variance_threshold)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                key: const ValueKey<String>(
                                  'score_batch_button',
                                ),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(48, 48),
                                ),
                                onPressed: widget.controller.isRunning
                                    ? null
                                    : _onScoreBatch,
                                icon: const Icon(Icons.analytics_outlined),
                                label: const Text('GPA バッチ評価'),
                              ),
                              FilledButton.icon(
                                key: const ValueKey<String>(
                                  'run_evolution_button',
                                ),
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(48, 48),
                                ),
                                onPressed: widget.controller.isRunning
                                    ? null
                                    : _onRunEvolution,
                                icon: const Icon(Icons.auto_fix_high),
                                label: const Text('進化候補を生成・検証'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (batch != null) ...[
                    const SizedBox(height: 12),
                    _BatchSummaryCard(batch: batch),
                  ],
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '2. ベースライン 5要素プロンプト定義',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            key: const ValueKey<String>('prompt_title_field'),
                            controller: _titleController,
                            decoration: const InputDecoration(
                              labelText: 'テンプレートタイトル',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            key: const ValueKey<String>('prompt_role_field'),
                            controller: _roleController,
                            decoration: const InputDecoration(
                              labelText: '役割設定 (role_setting)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _constraintsController,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: '制約条件 (constraints_text)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (runResult != null) ...[
                    const SizedBox(height: 12),
                    _CandidatesCard(runResult: runResult),
                  ],
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '3. Supabase GPA 履歴 (${recent.length}件)',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (widget.controller.isLoading)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else if (recent.isEmpty)
                            Text(
                              '記録済みの GPA 評価はまだありません。',
                              style: textTheme.bodyMedium?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            )
                          else
                            Column(
                              children: recent.take(5).map((row) {
                                final Object? gpa = row['gpa'];
                                final Object? src = row['source_type'];
                                final Object? reason = row['rationale_short'];
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(
                                    child: Text('${gpa ?? '-'}'),
                                  ),
                                  title: Text('${src ?? 'trace'}'),
                                  subtitle: Text('${reason ?? ''}'),
                                );
                              }).toList(growable: false),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EvolutionBanner extends StatelessWidget {
  const _EvolutionBanner({
    required this.backgroundColor,
    required this.foregroundColor,
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final Color backgroundColor;
  final Color foregroundColor;
  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: foregroundColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: foregroundColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: TextStyle(color: foregroundColor),
                  ),
                ],
              ),
            ),
            if (actionLabel != null && onAction != null)
              TextButton(
                onPressed: onAction,
                child: Text(
                  actionLabel!,
                  style: TextStyle(color: foregroundColor),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BatchSummaryCard extends StatelessWidget {
  const _BatchSummaryCard({required this.batch});

  final GpaBatchEvaluationReport batch;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Card(
      color: batch.evolutionTriggered
          ? colors.tertiaryContainer
          : colors.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              batch.evolutionTriggered
                  ? '分散しきい値超過: 進化的最適化をトリガー (${batch.scoreVariance.toStringAsFixed(3)} > ${batch.varianceThreshold})'
                  : '分散安定: 進化的最適化をスキップ (${batch.scoreVariance.toStringAsFixed(3)} <= ${batch.varianceThreshold})',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text('Samples: ${batch.sampleCount}')),
                Chip(
                  label: Text(
                    'Mean GPA: ${batch.meanGpa.toStringAsFixed(2)}',
                  ),
                ),
                Chip(
                  label: Text(
                    'Consistency: ${batch.meanConsistency.toStringAsFixed(2)}',
                  ),
                ),
                Chip(
                  label: Text(
                    'Efficiency: ${batch.meanEfficiency.toStringAsFixed(2)}',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CandidatesCard extends StatelessWidget {
  const _CandidatesCard({required this.runResult});

  final PromptEvolutionRunResult runResult;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              runResult.candidates.isEmpty
                  ? '進化候補: 分散が規定値内のため生成なし'
                  : '進化候補ランキング (${runResult.candidates.length}案)',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (runResult.savedTemplateId != null) ...[
              const SizedBox(height: 6),
              Text(
                '保存先 prompt_templates ID: ${runResult.savedTemplateId}',
                style: textTheme.bodySmall?.copyWith(color: colors.primary),
              ),
            ],
            const SizedBox(height: 8),
            ...runResult.candidates.map((cand) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  cand.safetyValid
                      ? Icons.verified_outlined
                      : Icons.gpp_bad_outlined,
                  color: cand.safetyValid ? colors.primary : colors.error,
                ),
                title: Text('${cand.strategy} (Fitness ${cand.fitnessScore})'),
                subtitle: Text(
                  'Projected GPA: ${cand.projectedGpa} | ${cand.reflectionSummary}',
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
