import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/corporate_bank_account_cost_service.dart';

class CorporateBankAccountSimulatorPage extends StatefulWidget {
  const CorporateBankAccountSimulatorPage({
    super.key,
    this.service,
  });

  final CorporateBankAccountCostService? service;

  @override
  State<CorporateBankAccountSimulatorPage> createState() =>
      _CorporateBankAccountSimulatorPageState();
}

class _CorporateBankAccountSimulatorPageState
    extends State<CorporateBankAccountSimulatorPage> {
  final _otherBankTransferController = TextEditingController(text: '30');
  final _sameBankTransferController = TextEditingController(text: '0');
  final _currencyFormat = NumberFormat.currency(
    locale: 'ja_JP',
    symbol: '¥',
    decimalDigits: 0,
  );

  List<CorporateBankFeePlan> _plans =
      CorporateBankAccountCostService.builtInPlans;
  late final CorporateBankAccountCostService _service;
  CorporateAccountingSoftware _accountingSoftware =
      CorporateAccountingSoftware.moneyForward;
  bool _needsOverseasRemittance = false;
  bool _isLoadingPlans = true;
  bool _isRegisteringWbs = false;
  String? _loadWarning;

  @override
  void initState() {
    super.initState();
    _service = widget.service ??
        CorporateBankAccountCostService(supabase: Supabase.instance.client);
    _loadPlans();
  }

  @override
  void dispose() {
    _otherBankTransferController.dispose();
    _sameBankTransferController.dispose();
    super.dispose();
  }

  Future<void> _loadPlans() async {
    setState(() {
      _isLoadingPlans = true;
      _loadWarning = null;
    });

    try {
      final plans = await _service.loadPlans();
      if (!mounted) return;
      setState(() {
        _plans = plans.isEmpty
            ? CorporateBankAccountCostService.builtInPlans
            : plans;
        _isLoadingPlans = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _plans = CorporateBankAccountCostService.builtInPlans;
        _isLoadingPlans = false;
        _loadWarning =
            'Supabase master data is not available yet. Built-in verified seed is used.';
      });
    }
  }

  CorporateBankSimulationInput get _input => CorporateBankSimulationInput(
        otherBankMonthlyTransferCount: _parseCount(
          _otherBankTransferController.text,
        ),
        sameBankMonthlyTransferCount:
            _parseCount(_sameBankTransferController.text),
        needsOverseasRemittance: _needsOverseasRemittance,
        accountingSoftware: _accountingSoftware,
      );

  int _parseCount(String value) {
    final parsed = int.tryParse(value.trim());
    if (parsed == null || parsed < 0) return 0;
    return parsed.clamp(0, 100000);
  }

  @override
  Widget build(BuildContext context) {
    final input = _input;
    final results = _service.simulate(input, plans: _plans);
    final bestResult = _service.bestResult(results);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        title: const Text('法人口座コスト試算'),
        backgroundColor: const Color(0xFF0F766E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'マスタデータを再読込',
            onPressed: _isLoadingPlans ? null : _loadPlans,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 980;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildInputAndSummary(isWide, input, bestResult),
                      const SizedBox(height: 16),
                      if (_loadWarning != null) _buildWarningBanner(),
                      if (_loadWarning != null) const SizedBox(height: 16),
                      _buildChart(results),
                      const SizedBox(height: 16),
                      _buildComparisonTable(results),
                      const SizedBox(height: 16),
                      _buildSourcePanel(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInputAndSummary(
    bool isWide,
    CorporateBankSimulationInput input,
    CorporateBankCostResult? bestResult,
  ) {
    final children = <Widget>[
      Expanded(flex: isWide ? 7 : 0, child: _buildInputPanel(input)),
      SizedBox(width: isWide ? 16 : 0, height: isWide ? 0 : 16),
      Expanded(flex: isWide ? 5 : 0, child: _buildBestPlanPanel(bestResult)),
    ];

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children
          .map((child) => child is Expanded ? child.child : child)
          .toList(growable: false),
    );
  }

  Widget _buildInputPanel(CorporateBankSimulationInput input) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '入力条件',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              '月間振込件数、海外送金、会計ソフト要件から年間コストを比較します。',
              style: TextStyle(color: Color(0xFF5F6673), height: 1.5),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _buildCountField(
                  label: '他行宛 月間振込件数',
                  controller: _otherBankTransferController,
                ),
                _buildCountField(
                  label: '同行宛 月間振込件数',
                  controller: _sameBankTransferController,
                ),
              ],
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<CorporateAccountingSoftware>(
              initialValue: _accountingSoftware,
              decoration: const InputDecoration(
                labelText: '予定している会計ソフト',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.receipt_long_outlined),
              ),
              items: CorporateAccountingSoftware.values
                  .map(
                    (software) => DropdownMenuItem(
                      value: software,
                      child: Text(software.label),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _accountingSoftware = value);
              },
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('海外送金が必要'),
              subtitle: const Text('必要な場合は公式掲載の有無を必須条件にします。'),
              value: _needsOverseasRemittance,
              activeThumbColor: const Color(0xFF0F766E),
              onChanged: (value) {
                setState(() => _needsOverseasRemittance = value);
              },
            ),
            const Divider(height: 26),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: () => setState(() {}),
                  icon: const Icon(Icons.calculate_outlined),
                  label: const Text('再計算'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed:
                      _isRegisteringWbs ? null : () => _registerWbsTasks(),
                  icon: _isRegisteringWbs
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_task_outlined),
                  label: const Text('最適候補のWBSタスクを追加'),
                ),
                Text(
                  '合計 ${input.totalMonthlyTransferCount}件/月',
                  style: const TextStyle(
                    color: Color(0xFF475569),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountField({
    required String label,
    required TextEditingController controller,
  }) {
    return SizedBox(
      width: 240,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          suffixText: '件/月',
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.sync_alt_outlined),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildBestPlanPanel(CorporateBankCostResult? bestResult) {
    final result = bestResult;
    return Card(
      elevation: 0,
      color: const Color(0xFFEFFAF7),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: result == null
            ? const SizedBox(
                height: 180,
                child: Center(child: Text('比較できる料金プランがありません。')),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        result.meetsRequirements
                            ? Icons.verified_outlined
                            : Icons.warning_amber_outlined,
                        color: result.meetsRequirements
                            ? const Color(0xFF0F766E)
                            : const Color(0xFFB45309),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        result.meetsRequirements ? '最適候補' : '要件未充足の最安候補',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    result.plan.displayName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currencyFormat.format(result.annualTotalYen),
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F766E),
                    ),
                  ),
                  const Text(
                    '年間見込みコスト',
                    style: TextStyle(color: Color(0xFF475569)),
                  ),
                  const SizedBox(height: 16),
                  _buildMiniMetric(
                    '月額基本料',
                    _currencyFormat.format(result.monthlyBaseFeeYen),
                  ),
                  _buildMiniMetric(
                    '月間振込手数料',
                    _currencyFormat.format(
                      result.monthlySameBankTransferCostYen +
                          result.monthlyOtherBankTransferCostYen,
                    ),
                  ),
                  _buildMiniMetric(
                    'API/自動連携',
                    result.plan.apiAvailable ? '対応掲載あり' : '要確認',
                  ),
                  if (result.warnings.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    for (final warning in result.warnings)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Color(0xFFB45309),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                warning,
                                style: const TextStyle(
                                  color: Color(0xFF92400E),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _buildMiniMetric(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF475569))),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF59E0B)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFFB45309)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _loadWarning!,
              style: const TextStyle(color: Color(0xFF92400E)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(List<CorporateBankCostResult> results) {
    final maxCost = results.fold<int>(
      0,
      (current, result) =>
          result.annualTotalYen > current ? result.annualTotalYen : current,
    );
    final maxY = (maxCost * 1.2).clamp(1000, 10000000).toDouble();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '年間コスト比較',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              '要件を満たす候補を優先し、年間総額の低い順に並べます。',
              style: TextStyle(color: Color(0xFF5F6673)),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 300,
              child: BarChart(
                BarChartData(
                  maxY: maxY,
                  alignment: BarChartAlignment.spaceAround,
                  gridData: const FlGridData(
                    show: true,
                    drawVerticalLine: false,
                  ),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final result = results[group.x];
                        return BarTooltipItem(
                          '${result.plan.displayName}\n${_currencyFormat.format(result.annualTotalYen)}',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            height: 1.4,
                          ),
                        );
                      },
                    ),
                  ),
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
                        reservedSize: 68,
                        getTitlesWidget: (value, meta) => SideTitleWidget(
                          meta: meta,
                          child: Text(
                            NumberFormat.compactCurrency(
                              locale: 'ja_JP',
                              symbol: '¥',
                              decimalDigits: 0,
                            ).format(value),
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 34,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= results.length) {
                            return const SizedBox.shrink();
                          }
                          return SideTitleWidget(
                            meta: meta,
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: results.asMap().entries.map((entry) {
                    final result = entry.value;
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: result.annualTotalYen.toDouble(),
                          color: result.meetsRequirements
                              ? const Color(0xFF0F766E)
                              : const Color(0xFF94A3B8),
                          width: 28,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    );
                  }).toList(growable: false),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: results.asMap().entries.map((entry) {
                return Chip(
                  label: Text(
                    '${entry.key + 1}. ${entry.value.plan.displayName}',
                  ),
                  avatar: CircleAvatar(
                    backgroundColor: entry.value.meetsRequirements
                        ? const Color(0xFF0F766E)
                        : const Color(0xFF94A3B8),
                    child: Text(
                      '${entry.key + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                      ),
                    ),
                  ),
                );
              }).toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonTable(List<CorporateBankCostResult> results) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '比較明細',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('候補')),
                  DataColumn(label: Text('年間総額')),
                  DataColumn(label: Text('月額基本')),
                  DataColumn(label: Text('他行宛')),
                  DataColumn(label: Text('同行宛')),
                  DataColumn(label: Text('海外送金')),
                  DataColumn(label: Text('会計/API')),
                  DataColumn(label: Text('根拠')),
                ],
                rows: results.map((result) {
                  return DataRow(
                    color: WidgetStateProperty.resolveWith<Color?>(
                      (_) => result.meetsRequirements
                          ? null
                          : const Color(0xFFFFFBEB),
                    ),
                    cells: [
                      DataCell(
                        SizedBox(
                          width: 220,
                          child: Text(
                            result.plan.displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        Text(_currencyFormat.format(result.annualTotalYen)),
                      ),
                      DataCell(
                        Text(
                          _currencyFormat.format(result.monthlyBaseFeeYen),
                        ),
                      ),
                      DataCell(
                        Text(
                          '${_currencyFormat.format(result.plan.otherBankTransferFeeYen)}/件',
                        ),
                      ),
                      DataCell(
                        Text(
                          '${_currencyFormat.format(result.plan.sameBankTransferFeeYen)}/件',
                        ),
                      ),
                      DataCell(
                        _buildStatusPill(
                          result.plan.overseasRemittanceAvailable
                              ? '掲載あり'
                              : '未掲載',
                          result.plan.overseasRemittanceAvailable,
                        ),
                      ),
                      DataCell(
                        _buildStatusPill(
                          result.plan.apiAvailable ? '連携掲載あり' : '要確認',
                          result.plan.apiAvailable,
                        ),
                      ),
                      DataCell(
                        TextButton.icon(
                          onPressed: result.plan.sourceUrls.isEmpty
                              ? null
                              : () => _openUrl(result.plan.sourceUrls.first),
                          icon: const Icon(Icons.open_in_new, size: 16),
                          label: const Text('公式'),
                        ),
                      ),
                    ],
                  );
                }).toList(growable: false),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPill(String label, bool ok) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: ok ? const Color(0xFFEFFAF7) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: ok ? const Color(0xFF0F766E) : const Color(0xFFF59E0B),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: ok ? const Color(0xFF0F766E) : const Color(0xFF92400E),
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildSourcePanel() {
    final plans = _plans;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '料金マスタの確認情報',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              '料金は変更されるため、seed には確認日と公式URLを保存しています。',
              style: TextStyle(color: Color(0xFF5F6673)),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: plans.expand((plan) {
                return plan.sourceUrls.map((url) {
                  return ActionChip(
                    avatar: const Icon(Icons.link, size: 16),
                    label: Text('${plan.bankName}: ${_host(url)}'),
                    onPressed: () => _openUrl(url),
                  );
                });
              }).toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _registerWbsTasks() async {
    final results = _service.simulate(_input, plans: _plans);
    final bestResult = _service.bestResult(results);
    if (bestResult == null) return;

    setState(() => _isRegisteringWbs = true);

    final drafts = _service.buildWbsTaskDrafts(_input, bestResult);
    var success = 0;
    try {
      for (final draft in drafts) {
        await Supabase.instance.client.functions.invoke(
          'tools-hub',
          body: draft.toToolsHubBody(),
        );
        success++;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$success件のWBSタスクを追加しました。'),
          backgroundColor: const Color(0xFF0F766E),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('WBSタスク追加に失敗しました: $e'),
          backgroundColor: const Color(0xFFB91C1C),
        ),
      );
    } finally {
      if (mounted) setState(() => _isRegisteringWbs = false);
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _host(String url) {
    return Uri.tryParse(url)?.host ?? url;
  }
}
