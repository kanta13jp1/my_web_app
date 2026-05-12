import 'package:flutter/material.dart';

import '../models/career_monthly_kpi.dart';
import '../models/kgi_csf_kpi.dart';
import '../services/career_monthly_kpi_service.dart';
import 'kgi_csf_kpi_panel.dart';

class CareerMonthlyKpiPanel extends StatefulWidget {
  final List<Map<String, dynamic>> lifeGoals;

  const CareerMonthlyKpiPanel({
    super.key,
    this.lifeGoals = const <Map<String, dynamic>>[],
  });

  @override
  State<CareerMonthlyKpiPanel> createState() => _CareerMonthlyKpiPanelState();
}

class _CareerMonthlyKpiPanelState extends State<CareerMonthlyKpiPanel> {
  final CareerMonthlyKpiService _service = CareerMonthlyKpiService();
  final TextEditingController _monthCtrl = TextEditingController();
  final TextEditingController _annualGoalCtrl = TextEditingController();
  final TextEditingController _metricCtrl = TextEditingController();
  final TextEditingController _targetCtrl = TextEditingController();
  final TextEditingController _actualCtrl = TextEditingController();
  final TextEditingController _unitCtrl = TextEditingController();
  final TextEditingController _reflectionCtrl = TextEditingController();
  final TextEditingController _nextActionCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  CareerMonthlyKpi? _editing;
  List<CareerMonthlyKpi> _items = <CareerMonthlyKpi>[];

  @override
  void initState() {
    super.initState();
    _monthCtrl.text = CareerMonthlyKpi.currentMonthKey();
    _load();
  }

  @override
  void dispose() {
    _monthCtrl.dispose();
    _annualGoalCtrl.dispose();
    _metricCtrl.dispose();
    _targetCtrl.dispose();
    _actualCtrl.dispose();
    _unitCtrl.dispose();
    _reflectionCtrl.dispose();
    _nextActionCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _service.list();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    final metric = _metricCtrl.text.trim();
    final annualGoal = _annualGoalCtrl.text.trim();
    if (metric.isEmpty || annualGoal.isEmpty) {
      setState(() => _error = 'Annual goal and KPI name are required.');
      return;
    }

    final kpi = CareerMonthlyKpi(
      id: _editing?.id,
      monthKey: _monthCtrl.text.trim().isEmpty
          ? CareerMonthlyKpi.currentMonthKey()
          : _monthCtrl.text.trim(),
      annualGoal: annualGoal,
      category: 'career',
      metricName: metric,
      targetValue: double.tryParse(_targetCtrl.text.trim()) ?? 0,
      actualValue: double.tryParse(_actualCtrl.text.trim()) ?? 0,
      unit: _unitCtrl.text.trim(),
      reflection: _reflectionCtrl.text.trim(),
      nextAction: _nextActionCtrl.text.trim(),
    );

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_editing == null) {
        await _service.add(kpi);
      } else {
        await _service.update(kpi);
      }
      _resetForm();
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _delete(CareerMonthlyKpi item) async {
    final id = item.id;
    if (id == null || id.isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _service.delete(id);
      if (_editing?.id == id) {
        _resetForm();
      }
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _edit(CareerMonthlyKpi item) {
    setState(() {
      _editing = item;
      _monthCtrl.text = item.monthKey;
      _annualGoalCtrl.text = item.annualGoal;
      _metricCtrl.text = item.metricName;
      _targetCtrl.text = _formatNumber(item.targetValue);
      _actualCtrl.text = _formatNumber(item.actualValue);
      _unitCtrl.text = item.unit;
      _reflectionCtrl.text = item.reflection;
      _nextActionCtrl.text = item.nextAction;
    });
  }

  void _resetForm() {
    _editing = null;
    _metricCtrl.clear();
    _targetCtrl.clear();
    _actualCtrl.clear();
    _unitCtrl.clear();
    _reflectionCtrl.clear();
    _nextActionCtrl.clear();
  }

  void _showReport() {
    final report = CareerMonthlyKpiService.buildMonthlyReport(
      _items,
      _monthCtrl.text.trim().isEmpty
          ? CareerMonthlyKpi.currentMonthKey()
          : _monthCtrl.text.trim(),
    );
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Monthly Close Report'),
        content: SizedBox(
          width: 640,
          child: SingleChildScrollView(child: SelectableText(report)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final monthKey = _monthCtrl.text.trim().isEmpty
        ? CareerMonthlyKpi.currentMonthKey()
        : _monthCtrl.text.trim();
    final monthlyItems =
        _items.where((item) => item.monthKey == monthKey).toList();
    final summary = CareerMonthlyKpiService.summarize(_items, monthKey);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: accent.withValues(alpha: 0.16)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics_outlined, color: accent),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Career KPI Ledger',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh),
                ),
                IconButton(
                  tooltip: 'Report',
                  onPressed: _showReport,
                  icon: const Icon(Icons.article_outlined),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '#1394 monthly business review for career goals',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (_loading)
              const LinearProgressIndicator()
            else
              KgiCsfKpiPanel(
                plan: _buildPlan(summary, monthlyItems),
                accentColor: accent,
                dense: true,
                initiallyExpanded: monthlyItems.isNotEmpty,
              ),
            const SizedBox(height: 12),
            _buildGoalChips(),
            const SizedBox(height: 12),
            _buildForm(),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 12),
            if (monthlyItems.isEmpty)
              Text(
                'No KPI records for $monthKey yet.',
                style: theme.textTheme.bodySmall,
              )
            else
              ...monthlyItems.map(_buildKpiTile),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalChips() {
    final titles = widget.lifeGoals
        .where((goal) => goal['category']?.toString() == 'career')
        .map((goal) => goal['title']?.toString().trim() ?? '')
        .where((title) => title.isNotEmpty)
        .take(6)
        .toList();
    if (titles.isEmpty) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final title in titles)
          ActionChip(
            label: Text(title, overflow: TextOverflow.ellipsis),
            avatar: const Icon(Icons.flag_outlined, size: 16),
            onPressed: () => setState(() => _annualGoalCtrl.text = title),
          ),
      ],
    );
  }

  Widget _buildForm() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 640;
        final monthField = SizedBox(
          width: stacked ? double.infinity : 110,
          child: TextField(
            controller: _monthCtrl,
            decoration: const InputDecoration(
              labelText: 'Month',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
        );
        final annualGoalField = TextField(
          controller: _annualGoalCtrl,
          decoration: const InputDecoration(
            labelText: 'Annual goal',
            isDense: true,
            border: OutlineInputBorder(),
          ),
        );
        final metricField = TextField(
          controller: _metricCtrl,
          decoration: const InputDecoration(
            labelText: 'KPI',
            isDense: true,
            border: OutlineInputBorder(),
          ),
        );
        final targetField = TextField(
          controller: _targetCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Target',
            isDense: true,
            border: OutlineInputBorder(),
          ),
        );
        final actualField = TextField(
          controller: _actualCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Actual',
            isDense: true,
            border: OutlineInputBorder(),
          ),
        );
        final unitField = TextField(
          controller: _unitCtrl,
          decoration: const InputDecoration(
            labelText: 'Unit',
            isDense: true,
            border: OutlineInputBorder(),
          ),
        );

        return Column(
          children: [
            if (stacked) ...[
              monthField,
              const SizedBox(height: 8),
              annualGoalField,
              const SizedBox(height: 8),
              metricField,
              const SizedBox(height: 8),
              targetField,
              const SizedBox(height: 8),
              actualField,
              const SizedBox(height: 8),
              unitField,
            ] else ...[
              Row(
                children: [
                  monthField,
                  const SizedBox(width: 8),
                  Expanded(child: annualGoalField),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(flex: 2, child: metricField),
                  const SizedBox(width: 8),
                  Expanded(child: targetField),
                  const SizedBox(width: 8),
                  Expanded(child: actualField),
                  const SizedBox(width: 8),
                  SizedBox(width: 88, child: unitField),
                ],
              ),
            ],
            const SizedBox(height: 8),
            TextField(
              controller: _reflectionCtrl,
              minLines: 1,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Reflection',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nextActionCtrl,
              minLines: 1,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Next action',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_editing != null)
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => setState(() {
                              _resetForm();
                            }),
                    child: const Text('Cancel'),
                  ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: Icon(
                    _editing == null ? Icons.add : Icons.save_outlined,
                  ),
                  label: Text(_editing == null ? 'Add KPI' : 'Update KPI'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiTile(CareerMonthlyKpi item) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.metricName,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatNumber(item.actualValue)}${item.unit} / '
                  '${_formatNumber(item.targetValue)}${item.unit} '
                  '(${item.achievementPercentLabel})',
                  style: theme.textTheme.bodySmall,
                ),
                if (item.nextAction.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.nextAction,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Edit',
            onPressed: _saving ? null : () => _edit(item),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Delete',
            onPressed: _saving ? null : () => _delete(item),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }

  KgiCsfKpiPlan _buildPlan(
    CareerMonthlyKpiSummary summary,
    List<CareerMonthlyKpi> monthlyItems,
  ) {
    final metrics = monthlyItems.take(4).map((item) {
      return KgiCsfKpiMetric.number(
        csf: item.annualGoal.isEmpty ? 'Career goal' : item.annualGoal,
        kpi: item.metricName,
        actual: item.actualValue,
        target: item.targetValue,
        unit: item.unit,
      );
    }).toList();

    return KgiCsfKpiPlan(
      domain: 'Career monthly KPI',
      kgi: summary.primaryGoal.isEmpty
          ? 'Keep one measurable career goal reviewed monthly'
          : summary.primaryGoal,
      actualLabel: '${summary.completedMetrics}/${summary.totalMetrics}',
      targetLabel: 'monthly close',
      progress: summary.averageProgress,
      metrics: metrics,
    );
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.round().toString();
    }
    return value.toStringAsFixed(1);
  }
}
