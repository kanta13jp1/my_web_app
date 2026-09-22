import 'package:flutter/material.dart';

import '../models/process_quality_metric.dart';
import '../services/process_quality_metric_service.dart';

class ProcessQualityDashboardPage extends StatefulWidget {
  final ProcessQualityMetricRepository? repository;

  const ProcessQualityDashboardPage({
    super.key,
    this.repository,
  });

  @override
  State<ProcessQualityDashboardPage> createState() =>
      _ProcessQualityDashboardPageState();
}

class _ProcessQualityDashboardPageState
    extends State<ProcessQualityDashboardPage> {
  final _formKey = GlobalKey<FormState>();
  final _projectController = TextEditingController();
  final _featureController = TextEditingController();
  final _scopeController = TextEditingController(text: '1');
  final _minutesController = TextEditingController(text: '30');
  final _findingsController = TextEditingController(text: '0');
  final _reviewThresholdController = TextEditingController(text: '5');
  final _findingThresholdController = TextEditingController(text: '0.5');

  late final ProcessQualityMetricRepository _repository;
  List<ProcessQualityMetric> _metrics = const <ProcessQualityMetric>[];
  String _scopeUnit = 'features';
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? SupabaseProcessQualityMetricRepository();
    _reload();
  }

  @override
  void dispose() {
    _projectController.dispose();
    _featureController.dispose();
    _scopeController.dispose();
    _minutesController.dispose();
    _findingsController.dispose();
    _reviewThresholdController.dispose();
    _findingThresholdController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final metrics = await _repository.list();
      if (!mounted) return;
      setState(() => _metrics = metrics);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '品質指標を読み込めませんでした: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final metric = await _repository.add(
        ProcessQualityMetricDraft(
          projectName: _projectController.text,
          featureName: _featureController.text,
          scopeUnit: _scopeUnit,
          scopeSize: double.parse(_scopeController.text),
          reviewMinutes: int.parse(_minutesController.text),
          findingCount: int.parse(_findingsController.text),
          minimumReviewDensity: double.parse(_reviewThresholdController.text),
          minimumFindingDensity: double.parse(_findingThresholdController.text),
          reviewedAt: DateTime.now(),
        ),
      );
      if (!mounted) return;
      setState(() {
        _metrics = <ProcessQualityMetric>[metric, ..._metrics];
        _featureController.clear();
        _findingsController.text = '0';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('レビュー記録を保存しました。')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '保存できませんでした: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('プロセス品質ダッシュボード'),
        actions: <Widget>[
          IconButton(
            tooltip: '再読み込み',
            onPressed: _loading ? null : _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              _buildIntro(theme),
              const SizedBox(height: 16),
              _buildInputCard(theme),
              if (_error != null) ...<Widget>[
                const SizedBox(height: 12),
                _buildError(theme),
              ],
              const SizedBox(height: 16),
              if (_loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                )
              else ...<Widget>[
                _buildSummary(theme),
                const SizedBox(height: 16),
                _buildDensityChart(theme),
                const SizedBox(height: 16),
                _buildHistory(theme),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntro(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'レビューの深さを、規模あたりで比較',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'レビュー時間 ÷ 対象規模と、指摘件数 ÷ 対象規模を自動計算します。'
              '低密度はレビュー不足の確認サインであり、成果物の品質を断定する指標ではありません。',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'レビュー記録を追加',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final fieldWidth = constraints.maxWidth >= 760
                      ? (constraints.maxWidth - 24) / 3
                      : constraints.maxWidth >= 480
                          ? (constraints.maxWidth - 12) / 2
                          : constraints.maxWidth;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: <Widget>[
                      _field(
                        width: fieldWidth,
                        key: const ValueKey<String>('quality-project'),
                        controller: _projectController,
                        label: 'プロジェクト',
                        validator: _requiredText,
                      ),
                      _field(
                        width: fieldWidth,
                        key: const ValueKey<String>('quality-feature'),
                        controller: _featureController,
                        label: '機能・レビュー対象（任意）',
                      ),
                      SizedBox(
                        width: fieldWidth,
                        child: DropdownButtonFormField<String>(
                          key: const ValueKey<String>('quality-scope-unit'),
                          initialValue: _scopeUnit,
                          decoration: const InputDecoration(
                            labelText: '規模の単位',
                            border: OutlineInputBorder(),
                          ),
                          items: const <DropdownMenuItem<String>>[
                            DropdownMenuItem(
                              value: 'features',
                              child: Text('機能数'),
                            ),
                            DropdownMenuItem(
                              value: 'pages',
                              child: Text('ページ数'),
                            ),
                            DropdownMenuItem(
                              value: 'test_cases',
                              child: Text('テストケース数'),
                            ),
                            DropdownMenuItem(
                              value: 'documents',
                              child: Text('文書数'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _scopeUnit = value);
                            }
                          },
                        ),
                      ),
                      _numberField(
                        width: fieldWidth,
                        key: const ValueKey<String>('quality-scope-size'),
                        controller: _scopeController,
                        label: '対象規模',
                        allowDecimal: true,
                        strictlyPositive: true,
                      ),
                      _numberField(
                        width: fieldWidth,
                        key: const ValueKey<String>('quality-review-minutes'),
                        controller: _minutesController,
                        label: 'レビュー時間（分）',
                        strictlyPositive: true,
                      ),
                      _numberField(
                        width: fieldWidth,
                        key: const ValueKey<String>('quality-findings'),
                        controller: _findingsController,
                        label: '指摘件数',
                      ),
                      _numberField(
                        width: fieldWidth,
                        key: const ValueKey<String>(
                          'quality-review-threshold',
                        ),
                        controller: _reviewThresholdController,
                        label: '最低レビュー密度（分/単位）',
                        allowDecimal: true,
                      ),
                      _numberField(
                        width: fieldWidth,
                        key: const ValueKey<String>(
                          'quality-finding-threshold',
                        ),
                        controller: _findingThresholdController,
                        label: '最低指摘密度（件/単位）',
                        allowDecimal: true,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  key: const ValueKey<String>('quality-save'),
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_chart),
                  label: Text(_saving ? '保存中...' : '記録して計算'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required double width,
    required Key key,
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
  }) {
    return SizedBox(
      width: width,
      child: TextFormField(
        key: key,
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        maxLength: 120,
        validator: validator,
      ),
    );
  }

  Widget _numberField({
    required double width,
    required Key key,
    required TextEditingController controller,
    required String label,
    bool allowDecimal = false,
    bool strictlyPositive = false,
  }) {
    return SizedBox(
      width: width,
      child: TextFormField(
        key: key,
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(decimal: allowDecimal),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (value) {
          final parsed = double.tryParse(value ?? '');
          if (parsed == null || parsed.isNaN || parsed.isInfinite) {
            return '0以上の数値を入力してください';
          }
          if (parsed < 0 || (strictlyPositive && parsed <= 0)) {
            return strictlyPositive ? '0より大きい数値を入力してください' : '0以上の数値を入力してください';
          }
          if (!allowDecimal && parsed != parsed.roundToDouble()) {
            return '整数を入力してください';
          }
          return null;
        },
      ),
    );
  }

  String? _requiredText(String? value) {
    if (value == null || value.trim().isEmpty) return '入力してください';
    return null;
  }

  Widget _buildError(ThemeData theme) {
    return Material(
      color: theme.colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: <Widget>[
            Icon(Icons.error_outline, color: theme.colorScheme.error),
            const SizedBox(width: 10),
            Expanded(child: Text(_error!)),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(ThemeData theme) {
    final warningCount =
        _metrics.where((metric) => metric.needsAttention).length;
    final averageReview = _average(
      _metrics.map((metric) => metric.reviewDensity),
    );
    final averageFindings = _average(
      _metrics.map((metric) => metric.findingDensity),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth >= 680
            ? (constraints.maxWidth - 24) / 3
            : constraints.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            _summaryCard(
              width,
              '記録',
              '${_metrics.length}件',
              Icons.fact_check_outlined,
              theme.colorScheme.primary,
            ),
            _summaryCard(
              width,
              '平均レビュー密度',
              '${averageReview.toStringAsFixed(2)}分/単位',
              Icons.timer_outlined,
              theme.colorScheme.tertiary,
            ),
            _summaryCard(
              width,
              '閾値未達',
              '$warningCount件',
              Icons.warning_amber_outlined,
              warningCount > 0
                  ? theme.colorScheme.error
                  : const Color(0xFF15803D),
              supporting: '平均指摘 ${averageFindings.toStringAsFixed(2)}件/単位',
            ),
          ],
        );
      },
    );
  }

  Widget _summaryCard(
    double width,
    String label,
    String value,
    IconData icon,
    Color color, {
    String? supporting,
  }) {
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              Icon(icon, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(label),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (supporting != null)
                      Text(supporting, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDensityChart(ThemeData theme) {
    final chartMetrics = _metrics.take(8).toList(growable: false);
    return Card(
      key: const ValueKey<String>('quality-density-chart'),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '密度チャート（直近8件）',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'バーは各記録の最低基準に対する達成率です。100%以上で基準到達。',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            if (chartMetrics.isEmpty)
              const Text('記録を追加すると比較チャートが表示されます。')
            else
              for (final metric in chartMetrics) ...<Widget>[
                _densityBarGroup(metric, theme),
                if (metric != chartMetrics.last) const SizedBox(height: 16),
              ],
          ],
        ),
      ),
    );
  }

  Widget _densityBarGroup(ProcessQualityMetric metric, ThemeData theme) {
    final title = metric.featureName.isEmpty
        ? metric.projectName
        : '${metric.projectName} / ${metric.featureName}';
    return Semantics(
      label: '$title の密度',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          _densityBar(
            'レビュー ${metric.reviewDensity.toStringAsFixed(2)}分/単位',
            _thresholdRatio(
              metric.reviewDensity,
              metric.minimumReviewDensity,
            ),
            metric.reviewDensityBelowThreshold,
            theme,
          ),
          const SizedBox(height: 7),
          _densityBar(
            '指摘 ${metric.findingDensity.toStringAsFixed(2)}件/単位',
            _thresholdRatio(
              metric.findingDensity,
              metric.minimumFindingDensity,
            ),
            metric.findingDensityBelowThreshold,
            theme,
          ),
        ],
      ),
    );
  }

  Widget _densityBar(
    String label,
    double ratio,
    bool warning,
    ThemeData theme,
  ) {
    final progress = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LinearProgressIndicator(
        value: ratio.clamp(0.0, 1.0).toDouble(),
        minHeight: 12,
        color: warning ? theme.colorScheme.error : const Color(0xFF15803D),
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
      ),
    );
    final percentage = Text('${(ratio * 100).round()}%');
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(label),
              const SizedBox(height: 6),
              Row(
                children: <Widget>[
                  Expanded(child: progress),
                  const SizedBox(width: 8),
                  SizedBox(width: 46, child: percentage),
                ],
              ),
            ],
          );
        }
        return Row(
          children: <Widget>[
            SizedBox(width: 190, child: Text(label, maxLines: 1)),
            const SizedBox(width: 10),
            Expanded(child: progress),
            const SizedBox(width: 8),
            SizedBox(width: 46, child: percentage),
          ],
        );
      },
    );
  }

  Widget _buildHistory(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'レビュー履歴',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            if (_metrics.isEmpty)
              const Text('まだレビュー記録がありません。')
            else
              for (final metric in _metrics)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    metric.needsAttention
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle_outline,
                    color: metric.needsAttention
                        ? theme.colorScheme.error
                        : const Color(0xFF15803D),
                  ),
                  title: Text(
                    metric.featureName.isEmpty
                        ? metric.projectName
                        : '${metric.projectName} / ${metric.featureName}',
                  ),
                  subtitle: Text(
                    '${_date(metric.reviewedAt)} ・ '
                    '${metric.scopeSize.toStringAsFixed(1)} ${_unit(metric.scopeUnit)} ・ '
                    '${metric.reviewMinutes}分 ・ ${metric.findingCount}件\n'
                    'レビュー密度 ${metric.reviewDensity.toStringAsFixed(2)} / '
                    '指摘密度 ${metric.findingDensity.toStringAsFixed(2)}',
                  ),
                  trailing: metric.needsAttention
                      ? const Chip(label: Text('要確認'))
                      : const Chip(label: Text('基準到達')),
                  isThreeLine: true,
                ),
          ],
        ),
      ),
    );
  }

  double _average(Iterable<double> values) {
    if (values.isEmpty) return 0;
    return values.reduce((sum, value) => sum + value) / values.length;
  }

  double _thresholdRatio(double actual, double threshold) {
    if (threshold <= 0) return 1;
    return actual / threshold;
  }

  String _date(DateTime value) {
    final local = value.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  String _unit(String value) => switch (value) {
        'pages' => 'ページ',
        'test_cases' => 'テストケース',
        'documents' => '文書',
        _ => '機能',
      };
}
