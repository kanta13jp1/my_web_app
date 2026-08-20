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
                  if (dashboard == null || dashboard.tasks.isEmpty)
                    _emptyState()
                  else ...[
                    _summaryRow(dashboard),
                    const SizedBox(height: 16),
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
              ),
            ),
    );
  }

  Widget _summaryRow(AiRouterCostDashboard dashboard) {
    return Row(
      children: [
        Expanded(
          child: _metricCard(
            icon: Icons.route_outlined,
            label: 'Requests',
            value: dashboard.totalRequests.toString(),
            color: _blue,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _metricCard(
            icon: Icons.attach_money,
            label: 'Cost',
            value: '\$${dashboard.totalCostUsd.toStringAsFixed(4)}',
            color: _orange,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _metricCard(
            icon: Icons.auto_graph,
            label: 'Models',
            value: dashboard.candidateCount.toString(),
            color: _green,
          ),
        ),
      ],
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
