import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/ai_router_cost_dashboard_service.dart';

class AiRouterCostDashboardPage extends StatefulWidget {
  const AiRouterCostDashboardPage({
    super.key,
    this.supabaseClient,
    this.service,
  });

  final SupabaseClient? supabaseClient;
  final AiRouterCostDashboardService? service;

  @override
  State<AiRouterCostDashboardPage> createState() =>
      _AiRouterCostDashboardPageState();
}

class _AiRouterCostDashboardPageState extends State<AiRouterCostDashboardPage> {
  static const _bg = Color(0xFF0A0A0A);
  static const _panel = Color(0xFF141414);
  static const _line = Color(0xFF262626);
  static const _orange = Color(0xFFF97316);
  static const _green = Color(0xFF22C55E);
  static const _blue = Color(0xFF38BDF8);
  static const _red = Color(0xFFEF4444);

  late final AiRouterCostDashboardService _service;
  AiRouterCostDashboard? _dashboard;
  String? _selectedTask;
  bool _loading = true;
  bool _saving = false;
  String? _savingRoiFeature;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = widget.service ??
        AiRouterCostDashboardService(supabaseClient: widget.supabaseClient);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dashboard = await _service.loadDashboard();
      if (!mounted) return;
      setState(() {
        _dashboard = dashboard;
        _selectedTask = dashboard.tasks.any((t) => t.task == _selectedTask)
            ? _selectedTask
            : dashboard.tasks.isEmpty
                ? null
                : dashboard.tasks.first.task;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save(AiRouterTaskSummary task, AiRouterCandidate item) async {
    setState(() => _saving = true);
    try {
      await _service.savePreference(
        task: task.task,
        provider: item.provider,
        model: item.model,
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${task.label}: ${item.displayModel}')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editRoiParameters(AiFeatureRoiSummary feature) async {
    final parameters = feature.parameters;
    final controllers = <TextEditingController>[
      TextEditingController(
        text: parameters.minutesSavedPerSuccess.toString(),
      ),
      TextEditingController(text: parameters.hourlyValueUsd.toString()),
      TextEditingController(
        text: parameters.directCostSavingUsdPerSuccess.toString(),
      ),
      TextEditingController(
        text: parameters.avoidedLossUsdPerSuccess.toString(),
      ),
      TextEditingController(
        text: parameters.valueCreatedUsdPerSuccess.toString(),
      ),
    ];
    final result = await showDialog<List<double>>(
      context: context,
      builder: (dialogContext) {
        String? validationError;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text('ROI assumptions: ${feature.featureKey}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Enter your own estimates. Defaults are zero and no '
                    'external pricing claims are applied.',
                  ),
                  const SizedBox(height: 12),
                  _roiInput(
                    controllers[0],
                    'Minutes saved per successful use',
                  ),
                  _roiInput(controllers[1], 'Hourly value (USD)'),
                  _roiInput(
                    controllers[2],
                    'Direct saving per success (USD)',
                  ),
                  _roiInput(
                    controllers[3],
                    'Avoided loss per success (USD)',
                  ),
                  _roiInput(
                    controllers[4],
                    'Value created per success (USD)',
                  ),
                  if (validationError != null)
                    Text(
                      validationError!,
                      style: const TextStyle(color: _red),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final values = controllers
                      .map((controller) => double.tryParse(controller.text))
                      .toList();
                  const maximums = <double>[
                    1440,
                    10000,
                    1000000,
                    1000000,
                    1000000,
                  ];
                  final invalid = values.indexed.any(
                    (entry) =>
                        entry.$2 == null ||
                        entry.$2! < 0 ||
                        entry.$2! > maximums[entry.$1],
                  );
                  if (invalid) {
                    setDialogState(() {
                      validationError =
                          'Use non-negative values within the displayed limits.';
                    });
                    return;
                  }
                  Navigator.of(dialogContext).pop(
                    values.cast<double>(),
                  );
                },
                child: const Text('Save assumptions'),
              ),
            ],
          ),
        );
      },
    );
    for (final controller in controllers) {
      controller.dispose();
    }
    if (result == null || !mounted) return;
    setState(() => _savingRoiFeature = feature.featureKey);
    try {
      await _service.saveRoiParameters(
        featureKey: feature.featureKey,
        minutesSavedPerSuccess: result[0],
        hourlyValueUsd: result[1],
        directCostSavingUsdPerSuccess: result[2],
        avoidedLossUsdPerSuccess: result[3],
        valueCreatedUsdPerSuccess: result[4],
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${feature.featureKey}: ROI assumptions saved')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _savingRoiFeature = null);
    }
  }

  Widget _roiInput(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = _dashboard;
    AiRouterTaskSummary? selected;
    if (dashboard != null) {
      for (final task in dashboard.tasks) {
        if (task.task == _selectedTask) {
          selected = task;
          break;
        }
      }
    }
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        title: const Text('AI Router Cost'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading && dashboard == null
          ? const Center(child: CircularProgressIndicator(color: _orange))
          : RefreshIndicator(
              color: _orange,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null) _errorBanner(_error!),
                  if (dashboard == null)
                    _emptyState()
                  else ...[
                    _summaryRow(dashboard),
                    const SizedBox(height: 16),
                    _roiSection(dashboard.roi),
                    const SizedBox(height: 16),
                    if (dashboard.tasks.isEmpty)
                      _emptyState()
                    else ...[
                      _taskSelector(dashboard),
                      const SizedBox(height: 16),
                      if (selected != null) ...[
                        _recommendation(selected),
                        const SizedBox(height: 16),
                        _chart(selected),
                        const SizedBox(height: 16),
                        ...selected.candidates.map(
                          (candidate) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _candidateTile(selected!, candidate),
                          ),
                        ),
                      ],
                    ],
                  ],
                ],
              ),
            ),
    );
  }

  Widget _summaryRow(AiRouterCostDashboard dashboard) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 720 ? 2 : 3;
        final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: width,
              child: _metricCard(
                icon: Icons.route_outlined,
                label: 'Requests',
                value: dashboard.totalRequests.toString(),
                color: _blue,
              ),
            ),
            SizedBox(
              width: width,
              child: _metricCard(
                icon: Icons.attach_money,
                label: 'Cost',
                value: '\$${dashboard.totalCostUsd.toStringAsFixed(4)}',
                color: _orange,
              ),
            ),
            SizedBox(
              width: width,
              child: _metricCard(
                icon: Icons.auto_graph,
                label: 'Models',
                value: dashboard.candidateCount.toString(),
                color: _green,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _metricCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _roiSection(AiFeatureRoiDashboard roi) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _blue.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.insights_outlined, color: _blue),
              SizedBox(width: 8),
              Text(
                'AI feature ROI',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Benefits use only your saved assumptions; unset values remain zero.',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          ),
          const SizedBox(height: 12),
          _roiMetricGrid(roi.overall),
          if (roi.dailyTrend.isNotEmpty) ...[
            const SizedBox(height: 16),
            _roiTrendChart(roi.dailyTrend),
          ],
          const SizedBox(height: 16),
          if (roi.features.isEmpty)
            const Text(
              'No AI feature usage in this period.',
              style: TextStyle(color: Color(0xFFCBD5E1)),
            )
          else
            ...roi.features.map(_roiFeatureTile),
        ],
      ),
    );
  }

  Widget _roiMetricGrid(AiFeatureRoiMetric metric) {
    final roiValue =
        metric.roiPct == null ? '—' : '${metric.roiPct!.toStringAsFixed(1)}%';
    final items = <({String label, String value, Color color})>[
      (label: 'ROI', value: roiValue, color: _blue),
      (
        label: 'Benefit',
        value: '\$${metric.totalBenefitUsd.toStringAsFixed(2)}',
        color: _green,
      ),
      (
        label: 'Net',
        value: '\$${metric.netBenefitUsd.toStringAsFixed(2)}',
        color: metric.netBenefitUsd >= 0 ? _green : _red,
      ),
      (
        label: 'API cost',
        value: '\$${metric.apiCostUsd.toStringAsFixed(4)}',
        color: _orange,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 640 ? 2 : 4;
        final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: _metricCard(
                  icon: Icons.circle,
                  label: item.label,
                  value: item.value,
                  color: item.color,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _roiTrendChart(List<AiFeatureRoiTrendPoint> trend) {
    final spots = <FlSpot>[
      for (final entry in trend.indexed)
        if (entry.$2.roiPct != null)
          FlSpot(entry.$1.toDouble(), entry.$2.roiPct!),
    ];
    if (spots.isEmpty) {
      return const Text(
        'ROI trend is undefined while API cost is zero.',
        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
      );
    }
    var minY = spots.map((spot) => spot.y).reduce(math.min);
    var maxY = spots.map((spot) => spot.y).reduce(math.max);
    minY = math.min(0, minY);
    maxY = math.max(0, maxY);
    if (minY == maxY) {
      minY -= 1;
      maxY += 1;
    }
    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: math.max(1, trend.length - 1).toDouble(),
          minY: minY,
          maxY: maxY,
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 48),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (value, _) {
                  final index = value.toInt();
                  if (index < 0 || index >= trend.length) {
                    return const SizedBox.shrink();
                  }
                  if (index != 0 && index != trend.length - 1) {
                    return const SizedBox.shrink();
                  }
                  final date = trend[index].usageDate;
                  return Text(
                    date.length >= 10 ? date.substring(5) : date,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 10,
                    ),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              color: _blue,
              barWidth: 3,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: _blue.withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roiFeatureTile(AiFeatureRoiSummary feature) {
    final roiValue =
        feature.roiPct == null ? '—' : '${feature.roiPct!.toStringAsFixed(1)}%';
    final isSaving = _savingRoiFeature == feature.featureKey;
    return Container(
      key: ValueKey('roi-feature-${feature.featureKey}'),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _line),
      ),
      child: ListTile(
        title: Text(
          feature.featureKey,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          'ROI $roiValue · benefit '
          '\$${feature.totalBenefitUsd.toStringAsFixed(2)} · '
          '${feature.successCount}/${feature.requestCount} successful',
          style: const TextStyle(color: Color(0xFF94A3B8)),
        ),
        trailing: IconButton(
          tooltip: 'Edit ROI assumptions for ${feature.featureKey}',
          onPressed: isSaving ? null : () => _editRoiParameters(feature),
          icon: isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.tune),
        ),
      ),
    );
  }

  Widget _taskSelector(AiRouterCostDashboard dashboard) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _line),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedTask,
          isExpanded: true,
          dropdownColor: _panel,
          iconEnabledColor: Colors.white70,
          items: dashboard.tasks
              .map(
                (task) => DropdownMenuItem<String>(
                  value: task.task,
                  child: Text(
                    '${task.label} (${task.totalRequests})',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => _selectedTask = value),
        ),
      ),
    );
  }

  Widget _recommendation(AiRouterTaskSummary task) {
    final item = task.recommendation;
    final pref = task.preference;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _green.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.recommend_outlined, color: _green),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item?.displayModel ?? 'No recommendation',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  pref == null
                      ? 'Current: auto'
                      : 'Current: ${pref.displayModel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (item != null)
            IconButton.filledTonal(
              tooltip: 'Apply',
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              onPressed: _saving ? null : () => _save(task, item),
            ),
        ],
      ),
    );
  }

  Widget _chart(AiRouterTaskSummary task) {
    final candidates = task.candidates.take(6).toList();
    if (candidates.isEmpty) return const SizedBox.shrink();
    return Container(
      height: 260,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _line),
      ),
      child: BarChart(
        BarChartData(
          minY: 0,
          maxY: 100,
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 34,
                getTitlesWidget: (value, _) => Text(
                  value.toInt().toString(),
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 10,
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (value, _) {
                  final index = value.toInt();
                  if (index < 0 || index >= candidates.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      candidates[index].provider,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFCBD5E1),
                        fontSize: 10,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < candidates.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: candidates[i].score.clamp(0, 100),
                    width: 10,
                    color: _blue,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  BarChartRodData(
                    toY: candidates[i].successRatePct.clamp(0, 100),
                    width: 10,
                    color: _green,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _candidateTile(AiRouterTaskSummary task, AiRouterCandidate candidate) {
    final selected = task.preference?.provider == candidate.provider &&
        task.preference?.model == candidate.model;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: selected ? _green : _line),
      ),
      child: Row(
        children: [
          Icon(
            candidate.quotaAlert ? Icons.warning_amber : Icons.smart_toy,
            color: candidate.quotaAlert ? _red : _orange,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  candidate.displayModel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    _smallMetric('score', candidate.score.toStringAsFixed(1)),
                    _smallMetric(
                      'success',
                      '${candidate.successRatePct.toStringAsFixed(1)}%',
                    ),
                    _smallMetric(
                      'cost',
                      '\$${candidate.totalCostUsd.toStringAsFixed(4)}',
                    ),
                    if (candidate.avgLatencyMs != null)
                      _smallMetric('latency', '${candidate.avgLatencyMs}ms'),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: selected ? 'Selected' : 'Apply',
            icon: Icon(selected ? Icons.check_circle : Icons.check),
            color: selected ? _green : Colors.white70,
            onPressed:
                _saving || selected ? null : () => _save(task, candidate),
          ),
        ],
      ),
    );
  }

  Widget _smallMetric(String label, String value) {
    return Text(
      '$label $value',
      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
    );
  }

  Widget _errorBanner(String error) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _red.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _red.withValues(alpha: 0.4)),
        ),
        child: Text(
          error,
          style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 12),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return const SizedBox(
      height: 360,
      child: Center(
        child: Text(
          'No AI router telemetry yet',
          style: TextStyle(color: Color(0xFFCBD5E1)),
        ),
      ),
    );
  }
}
