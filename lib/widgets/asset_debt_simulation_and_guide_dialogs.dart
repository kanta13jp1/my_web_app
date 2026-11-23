import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_debt_danger_service.dart';
import 'package:my_web_app/services/asset_debt_simulation_service.dart';
import 'package:my_web_app/widgets/debt_legal_disclaimer_banner.dart';
import 'package:url_launcher/url_launcher.dart';

String _formatDebtYen(num value) {
  final rounded = value.round();
  final sign = rounded < 0 ? '-' : '';
  final digits = rounded.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[i]);
  }
  return '$sign$buffer円';
}

double? _parseNumber(String raw) {
  final normalized = raw.replaceAll(',', '').replaceAll(' ', '').trim();
  if (normalized.isEmpty) return null;
  return double.tryParse(normalized);
}

Widget _buildHorizontalComparisonBar({
  required String label,
  required double value,
  required double maxValue,
  required String displayValue,
  required Color color,
}) {
  final ratio = (maxValue > 0 && value.isFinite && value > 0)
      ? (value / maxValue).clamp(0.03, 1.0).toDouble()
      : 0.0;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
              ),
            ),
          ),
          Text(
            displayValue,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Container(
          height: 10,
          width: double.infinity,
          color: const Color(0xFFE2E8F0),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: ratio,
            child: Container(color: color),
          ),
        ),
      ),
    ],
  );
}

/// 複数借入の登録・日割り利息確認・高金利優先繰り上げ返済シミュレーター (#1369)。
class MultiDebtPrepaymentSimulatorDialog extends StatefulWidget {
  final List<MultiDebtInputItem> initialDebts;
  final VoidCallback? onOpenConsolidation;

  const MultiDebtPrepaymentSimulatorDialog({
    super.key,
    required this.initialDebts,
    this.onOpenConsolidation,
  });

  static Future<void> show(
    BuildContext context, {
    required List<MultiDebtInputItem> initialDebts,
    VoidCallback? onOpenConsolidation,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => MultiDebtPrepaymentSimulatorDialog(
        initialDebts: initialDebts,
        onOpenConsolidation: onOpenConsolidation,
      ),
    );
  }

  @override
  State<MultiDebtPrepaymentSimulatorDialog> createState() =>
      _MultiDebtPrepaymentSimulatorDialogState();
}

class _MultiDebtPrepaymentSimulatorDialogState
    extends State<MultiDebtPrepaymentSimulatorDialog> {
  late List<MultiDebtInputItem> _debts;
  late final TextEditingController _extraController;
  late final TextEditingController _nameController;
  late final TextEditingController _balanceController;
  late final TextEditingController _rateController;
  late final TextEditingController _paymentController;

  bool _showAddForm = false;
  bool _isMonthlyRecurring = false;
  double _extraAmount = 30000;
  String? _formError;
  int _customCounter = 0;

  @override
  void initState() {
    super.initState();
    _debts = List<MultiDebtInputItem>.from(widget.initialDebts);
    _showAddForm = _debts.isEmpty;
    _extraController = TextEditingController(
      text: _extraAmount.round().toString(),
    );
    _nameController = TextEditingController();
    _balanceController = TextEditingController();
    _rateController = TextEditingController(text: '15.0');
    _paymentController = TextEditingController();
  }

  @override
  void dispose() {
    _extraController.dispose();
    _nameController.dispose();
    _balanceController.dispose();
    _rateController.dispose();
    _paymentController.dispose();
    super.dispose();
  }

  void _setExtra(double amount, {bool syncText = true}) {
    final safe = max(0.0, amount).toDouble();
    setState(() => _extraAmount = safe);
    if (syncText) {
      _extraController.text = safe.round().toString();
    }
  }

  void _addCustomDebt() {
    final name = _nameController.text.trim();
    final balance = _parseNumber(_balanceController.text);
    final ratePercent = _parseNumber(_rateController.text);
    final payment = _parseNumber(_paymentController.text);

    if (name.isEmpty) {
      setState(() => _formError = '借入先名を入力してください。');
      return;
    }
    if (balance == null || balance <= 0) {
      setState(() => _formError = '残高（1円以上）を入力してください。');
      return;
    }
    if (ratePercent == null || ratePercent < 0 || ratePercent > 50) {
      setState(() => _formError = '実質年率は 0〜50% の範囲で入力してください。');
      return;
    }
    if (payment == null || payment < 0) {
      setState(() => _formError = '毎月の返済額（0円以上）を入力してください。');
      return;
    }

    _customCounter++;
    final newItem = MultiDebtInputItem(
      id: 'custom_debt_$_customCounter',
      name: name,
      balance: balance,
      annualRate: ratePercent / 100.0,
      monthlyPayment: payment,
    );
    setState(() {
      _debts.add(newItem);
      _formError = null;
      _showAddForm = false;
      _nameController.clear();
      _balanceController.clear();
      _paymentController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dialogWidth = min(MediaQuery.sizeOf(context).width - 48, 680.0);
    final summary = AssetDebtSimulationService.simulateMultiDebtAvalanche(
      items: _debts,
      extraAmount: _extraAmount,
      isMonthlyRecurring: _isMonthlyRecurring,
    );
    final totalBalance = _debts.fold<double>(0.0, (s, e) => s + e.balance);
    final totalPayment = _debts.fold<double>(
      0.0,
      (s, e) => s + e.monthlyPayment,
    );
    final maxInterestForBar = max(
      summary.baselineTotalInterest,
      summary.boostedTotalInterest,
    );

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      title: const Row(
        children: <Widget>[
          Icon(Icons.calculate_outlined, color: Color(0xFF0F766E)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '複数借入・繰り上げ返済シミュレーター',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Chip(
                    label: Text('借入 ${_debts.length}件'),
                    visualDensity: VisualDensity.compact,
                  ),
                  Chip(
                    label: Text('合計残高 ${_formatDebtYen(totalBalance)}'),
                    visualDensity: VisualDensity.compact,
                  ),
                  Chip(
                    label: Text('月額合計 ${_formatDebtYen(totalPayment)}'),
                    visualDensity: VisualDensity.compact,
                  ),
                  OutlinedButton.icon(
                    key: const Key('multi_debt_add_button'),
                    onPressed: () =>
                        setState(() => _showAddForm = !_showAddForm),
                    icon: Icon(
                      _showAddForm ? Icons.expand_less : Icons.add,
                      size: 16,
                    ),
                    label: Text(_showAddForm ? '追加欄を閉じる' : '借入先を追加'),
                  ),
                ],
              ),
              if (_showAddForm) ...<Widget>[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        '借入先の追加（残高・実質年率・毎月返済額）',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        key: const Key('multi_debt_name_field'),
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: '借入先名（例: 三井住友CL）',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          SizedBox(
                            width: 170,
                            child: TextField(
                              key: const Key('multi_debt_balance_field'),
                              controller: _balanceController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: '残高（円）',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 140,
                            child: TextField(
                              key: const Key('multi_debt_rate_field'),
                              controller: _rateController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(
                                labelText: '実質年率（%）',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 170,
                            child: TextField(
                              key: const Key('multi_debt_payment_field'),
                              controller: _paymentController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: '毎月返済額（円）',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_formError != null) ...<Widget>[
                        const SizedBox(height: 6),
                        Text(
                          _formError!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFB91C1C),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          key: const Key('multi_debt_add_confirm_button'),
                          onPressed: _addCustomDebt,
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text('試算リストへ追加'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Container(
                key: const Key('multi_debt_daily_interest_section'),
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      '日割り利息・次回元金充当の内訳（残高 × 実質年率 ÷ 365 × 日数）',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (_debts.isEmpty)
                      const Text(
                        '借入先がありません。上の「借入先を追加」から登録してください。',
                        style: TextStyle(fontSize: 12),
                      ),
                    for (var i = 0; i < summary.dailyBreakdowns.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    '${summary.dailyBreakdowns[i].debtName}'
                                    '（年率 ${(summary.dailyBreakdowns[i].annualRate * 100).toStringAsFixed(1)}% / '
                                    '残高 ${_formatDebtYen(summary.dailyBreakdowns[i].balance)}）',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    '次回(${summary.dailyBreakdowns[i].days}日分) 利息 '
                                    '${_formatDebtYen(summary.dailyBreakdowns[i].dailyInterest)} / '
                                    '元金充当 ${_formatDebtYen(summary.dailyBreakdowns[i].principalPortion)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: summary.dailyBreakdowns[i]
                                              .interestExceedsPayment
                                          ? const Color(0xFFB91C1C)
                                          : const Color(0xFF475569),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              key: Key(
                                'multi_debt_remove_${summary.dailyBreakdowns[i].debtId}',
                              ),
                              tooltip: '削除',
                              visualDensity: VisualDensity.compact,
                              onPressed: () {
                                setState(() {
                                  _debts.removeAt(i);
                                });
                              },
                              icon: const Icon(Icons.close, size: 16),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '高金利優先 繰り上げ返済シミュレーション',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  ChoiceChip(
                    key: const Key('multi_debt_mode_lump_sum'),
                    label: const Text('一括繰り上げ'),
                    selected: !_isMonthlyRecurring,
                    onSelected: (_) =>
                        setState(() => _isMonthlyRecurring = false),
                  ),
                  ChoiceChip(
                    key: const Key('multi_debt_mode_monthly'),
                    label: const Text('毎月上乗せ'),
                    selected: _isMonthlyRecurring,
                    onSelected: (_) =>
                        setState(() => _isMonthlyRecurring = true),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('multi_debt_extra_amount_field'),
                controller: _extraController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText:
                      _isMonthlyRecurring ? '毎月の上乗せ額（円）' : '一括繰り上げ予定額（円）',
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (value) {
                  final parsed = _parseNumber(value);
                  if (parsed != null && parsed >= 0) {
                    _setExtra(parsed, syncText: false);
                  }
                },
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  for (final preset in const <int>[10000, 30000, 50000, 100000])
                    ActionChip(
                      label: Text('${preset ~/ 10000}万円'),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _setExtra(preset.toDouble()),
                    ),
                ],
              ),
              if (summary.allocations.isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                Container(
                  key: const Key('multi_debt_allocation_summary'),
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF6EE7B7)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        '優先充当先（高金利順）',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF065F46),
                        ),
                      ),
                      const SizedBox(height: 4),
                      for (final alloc in summary.allocations)
                        Text(
                          '・${alloc.debtName}（年率 ${(alloc.annualRate * 100).toStringAsFixed(1)}%）: '
                          '${_formatDebtYen(alloc.appliedAmount)} 充当'
                          '${summary.isMonthlyRecurring ? '' : ' → 残高 ${_formatDebtYen(alloc.remainingBalanceAfterExtra)}'}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF064E3B),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Container(
                key: const Key('multi_debt_savings_summary'),
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _buildHorizontalComparisonBar(
                      label:
                          '現状ペース（完済目安: ${summary.baselineMonths == null ? '未確定' : '約${summary.baselineMonths}ヶ月'}）',
                      value: summary.baselineTotalInterest,
                      maxValue: maxInterestForBar,
                      displayValue:
                          '総利息 ${_formatDebtYen(summary.baselineTotalInterest)}',
                      color: const Color(0xFF64748B),
                    ),
                    const SizedBox(height: 8),
                    _buildHorizontalComparisonBar(
                      label:
                          '繰り上げ後（完済目安: ${summary.boostedMonths == null ? '未確定' : '約${summary.boostedMonths}ヶ月'}）',
                      value: summary.boostedTotalInterest,
                      maxValue: maxInterestForBar,
                      displayValue:
                          '総利息 ${_formatDebtYen(summary.boostedTotalInterest)}',
                      color: const Color(0xFF0F766E),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _buildSavingsMessage(summary),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F766E),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const DebtLegalDisclaimerBanner(
                contextType: DebtLegalNoticeContext.overpaymentAndSimulation,
                compact: true,
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        if (widget.onOpenConsolidation != null)
          TextButton.icon(
            key: const Key('multi_debt_switch_consolidation_button'),
            onPressed: () {
              Navigator.of(context).pop();
              widget.onOpenConsolidation!();
            },
            icon: const Icon(Icons.compare_arrows, size: 16),
            label: const Text('おまとめローン比較を見る'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('閉じる'),
        ),
      ],
    );
  }

  String _buildSavingsMessage(MultiDebtSimulationSummary summary) {
    if (_debts.isEmpty) {
      return '借入先を追加すると軽減効果を試算します。';
    }
    if (summary.becomesPayable) {
      return '繰り上げ返済により完済見込みが立ちます。';
    }
    final monthsSaved = summary.monthsSaved;
    final interestSaved = summary.interestSaved;
    if (monthsSaved != null && interestSaved != null && interestSaved > 0) {
      return '完済まで約$monthsSavedヶ月短縮し、総支払利息を約${_formatDebtYen(interestSaved)}軽減できる試算です。';
    }
    return '条件を調整して利息軽減効果を比較できます。';
  }
}

/// 複数借入のおまとめローン（借り換え）効果比較ダイアログ (#2750)。
class DebtConsolidationSimulatorDialog extends StatefulWidget {
  final List<MultiDebtInputItem> initialDebts;

  const DebtConsolidationSimulatorDialog({
    super.key,
    required this.initialDebts,
  });

  static Future<void> show(
    BuildContext context, {
    required List<MultiDebtInputItem> initialDebts,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) =>
          DebtConsolidationSimulatorDialog(initialDebts: initialDebts),
    );
  }

  @override
  State<DebtConsolidationSimulatorDialog> createState() =>
      _DebtConsolidationSimulatorDialogState();
}

class _DebtConsolidationSimulatorDialogState
    extends State<DebtConsolidationSimulatorDialog> {
  late final TextEditingController _principalController;
  late final TextEditingController _rateController;
  late final TextEditingController _termController;

  late double _principal;
  double _consolidatedRatePercent = 9.5;
  int _termMonths = 60;

  @override
  void initState() {
    super.initState();
    _principal = widget.initialDebts.fold<double>(
      0.0,
      (sum, item) => sum + item.balance,
    );
    _principalController = TextEditingController(
      text: _principal.round().toString(),
    );
    _rateController = TextEditingController(
      text: _consolidatedRatePercent.toStringAsFixed(1),
    );
    _termController = TextEditingController(text: _termMonths.toString());
  }

  @override
  void dispose() {
    _principalController.dispose();
    _rateController.dispose();
    _termController.dispose();
    super.dispose();
  }

  void _setRatePercent(double ratePercent, {bool syncText = true}) {
    setState(() {
      _consolidatedRatePercent = ratePercent.clamp(0.0, 30.0).toDouble();
    });
    if (syncText) {
      _rateController.text = _consolidatedRatePercent.toStringAsFixed(1);
    }
  }

  void _setTermMonths(int months, {bool syncText = true}) {
    setState(() {
      _termMonths = months.clamp(1, 360);
    });
    if (syncText) {
      _termController.text = _termMonths.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dialogWidth = min(MediaQuery.sizeOf(context).width - 48, 680.0);
    final result = AssetDebtSimulationService.simulateConsolidation(
      items: widget.initialDebts,
      consolidatedAnnualRate: _consolidatedRatePercent / 100.0,
      consolidatedTermMonths: _termMonths,
      overrideTotalPrincipal: _principal,
    );

    final maxMonthly = max(
      result.currentMonthlyPaymentTotal,
      result.consolidatedMonthlyPayment,
    );
    final maxInterest = max(
      result.currentTotalInterest,
      result.consolidatedTotalInterest,
    );
    final monthlySavings = result.monthlyPaymentSavings;
    final interestSavings = result.totalInterestSavings;

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      title: const Row(
        children: <Widget>[
          Icon(Icons.compare_arrows, color: Color(0xFF1D4ED8)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'おまとめローン（借り換え）効果シミュレーション',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '現在の加重平均年率: '
                '${(result.weightedAverageAnnualRate * 100).toStringAsFixed(2)}% / '
                '対象 ${widget.initialDebts.length}件',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF475569),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  SizedBox(
                    width: 190,
                    child: TextField(
                      key: const Key('consolidation_principal_field'),
                      controller: _principalController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '借換対象残高合計（円）',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        final parsed = _parseNumber(value);
                        if (parsed != null && parsed >= 0) {
                          setState(() => _principal = parsed);
                        }
                      },
                    ),
                  ),
                  SizedBox(
                    width: 160,
                    child: TextField(
                      key: const Key('consolidation_rate_field'),
                      controller: _rateController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: '想定年利（%）',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        final parsed = _parseNumber(value);
                        if (parsed != null && parsed >= 0) {
                          _setRatePercent(parsed, syncText: false);
                        }
                      },
                    ),
                  ),
                  SizedBox(
                    width: 150,
                    child: TextField(
                      key: const Key('consolidation_term_field'),
                      controller: _termController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '返済期間（ヶ月）',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        final parsed = _parseNumber(value);
                        if (parsed != null && parsed >= 1) {
                          _setTermMonths(parsed.round(), syncText: false);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  for (final rate in const <double>[6.0, 9.5, 12.0, 14.5])
                    ChoiceChip(
                      label: Text('年利 ${rate.toStringAsFixed(1)}%'),
                      selected: (_consolidatedRatePercent - rate).abs() < 0.05,
                      onSelected: (_) => _setRatePercent(rate),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  for (final months in const <int>[36, 60, 84, 120])
                    ChoiceChip(
                      label: Text('$monthsヶ月'),
                      selected: _termMonths == months,
                      onSelected: (_) => _setTermMonths(months),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                key: const Key('consolidation_comparison_chart'),
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      '借り換え前後の定量比較',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildHorizontalComparisonBar(
                      label: '毎月の返済額（現在合計）',
                      value: result.currentMonthlyPaymentTotal,
                      maxValue: maxMonthly,
                      displayValue:
                          _formatDebtYen(result.currentMonthlyPaymentTotal),
                      color: const Color(0xFF64748B),
                    ),
                    const SizedBox(height: 6),
                    _buildHorizontalComparisonBar(
                      label: '毎月の返済額（おまとめ後）',
                      value: result.consolidatedMonthlyPayment,
                      maxValue: maxMonthly,
                      displayValue:
                          _formatDebtYen(result.consolidatedMonthlyPayment),
                      color: const Color(0xFF1D4ED8),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      monthlySavings >= 0
                          ? '月額負担差: 約${_formatDebtYen(monthlySavings)} 軽減'
                          : '月額負担差: 約${_formatDebtYen(-monthlySavings)} 増加',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: monthlySavings >= 0
                            ? const Color(0xFF0F766E)
                            : const Color(0xFFB45309),
                      ),
                    ),
                    const Divider(height: 18),
                    _buildHorizontalComparisonBar(
                      label:
                          '総支払利息（現在ペース: ${result.currentPayoffMonths == null ? '完済未確定' : '約${result.currentPayoffMonths}ヶ月'}）',
                      value: result.currentTotalInterest,
                      maxValue: maxInterest,
                      displayValue: _formatDebtYen(result.currentTotalInterest),
                      color: const Color(0xFF64748B),
                    ),
                    const SizedBox(height: 6),
                    _buildHorizontalComparisonBar(
                      label: '総支払利息（おまとめ $_termMonthsヶ月）',
                      value: result.consolidatedTotalInterest,
                      maxValue: maxInterest,
                      displayValue:
                          _formatDebtYen(result.consolidatedTotalInterest),
                      color: result.increasesTotalInterest
                          ? const Color(0xFFB45309)
                          : const Color(0xFF0F766E),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      interestSavings == null
                          ? '現在ペースは完済未確定のため、総利息の単純比較はできません。'
                          : interestSavings >= 0
                              ? '総利息差: 約${_formatDebtYen(interestSavings)} 削減見込み'
                              : '総利息差: 返済期間の長期化により約${_formatDebtYen(-interestSavings)} 増加見込み',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: (interestSavings != null && interestSavings < 0)
                            ? const Color(0xFFB45309)
                            : const Color(0xFF0F766E),
                      ),
                    ),
                    if (result.increasesTotalInterest) ...<Widget>[
                      const SizedBox(height: 8),
                      Container(
                        key: const Key(
                          'consolidation_interest_increase_warning',
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFF59E0B)),
                        ),
                        child: const Text(
                          '返済期間を長く設定すると、年率が下がっても総支払利息が増える場合があります。',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF92400E),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const DebtLegalDisclaimerBanner(
                key: Key('consolidation_legal_disclaimer'),
                contextType: DebtLegalNoticeContext.consolidation,
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('閉じる'),
        ),
      ],
    );
  }
}

/// 返済危険度判定の設定調整および債務整理・公的相談窓口ガイドダイアログ (#1370)。
class DebtDangerConsultationGuideDialog extends StatefulWidget {
  final AssetLiabilityWorkbook workbook;
  final double? monthlyIncome;
  final List<AssetLiabilityMonthlySnapshot> monthlySnapshots;
  final DebtDangerSettings initialSettings;
  final ValueChanged<DebtDangerSettings> onSettingsChanged;
  final Future<bool> Function(Uri uri)? onOpenUrl;

  const DebtDangerConsultationGuideDialog({
    super.key,
    required this.workbook,
    required this.monthlyIncome,
    required this.monthlySnapshots,
    required this.initialSettings,
    required this.onSettingsChanged,
    this.onOpenUrl,
  });

  static Future<void> show(
    BuildContext context, {
    required AssetLiabilityWorkbook workbook,
    required double? monthlyIncome,
    required List<AssetLiabilityMonthlySnapshot> monthlySnapshots,
    required DebtDangerSettings initialSettings,
    required ValueChanged<DebtDangerSettings> onSettingsChanged,
    Future<bool> Function(Uri uri)? onOpenUrl,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => DebtDangerConsultationGuideDialog(
        workbook: workbook,
        monthlyIncome: monthlyIncome,
        monthlySnapshots: monthlySnapshots,
        initialSettings: initialSettings,
        onSettingsChanged: onSettingsChanged,
        onOpenUrl: onOpenUrl,
      ),
    );
  }

  @override
  State<DebtDangerConsultationGuideDialog> createState() =>
      _DebtDangerConsultationGuideDialogState();
}

class _DebtDangerConsultationGuideDialogState
    extends State<DebtDangerConsultationGuideDialog> {
  late DebtDangerSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings;
  }

  void _updateSettings(DebtDangerSettings next) {
    setState(() => _settings = next);
    widget.onSettingsChanged(next);
  }

  Future<void> _launchConsultationUrl(DebtConsultationResource resource) async {
    final uri = Uri.parse(resource.url);
    final opener = widget.onOpenUrl ??
        ((target) => launchUrl(target, mode: LaunchMode.externalApplication));
    final ok = await opener(uri);
    if (!mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${resource.title} のページを開けませんでした。')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dialogWidth = min(MediaQuery.sizeOf(context).width - 48, 680.0);
    final assessment = AssetDebtDangerService.evaluate(
      workbook: widget.workbook,
      monthlyIncome: widget.monthlyIncome,
      monthlySnapshots: widget.monthlySnapshots,
      settings: _settings,
    );
    final ratioText = assessment.repaymentToIncomeRatio == null
        ? '月収未登録のため参考値なし'
        : '${(assessment.repaymentToIncomeRatio! * 100).toStringAsFixed(0)}%';

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      title: const Row(
        children: <Widget>[
          Icon(Icons.support_agent_outlined, color: Color(0xFF334155)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '返済状況の確認と専門家・公的相談窓口ガイド',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: assessment.isAlertTriggered
                      ? const Color(0xFFEEF2FF)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: assessment.isAlertTriggered
                        ? const Color(0xFFA5B4FC)
                        : const Color(0xFFCBD5E1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      assessment.isAlertTriggered
                          ? '判定: 返済計画の見直し・専門家への相談検討目安に該当'
                          : '判定: 現在の設定基準内の推移です',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '月次返済予定額: ${_formatDebtYen(assessment.monthlyScheduledPayment)} / '
                      '対収入比率: $ratioText / '
                      '残高非減少の連続月数: ${assessment.consecutiveNonDecreasingMonths}ヶ月',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF475569),
                      ),
                    ),
                    for (final reason in assessment.reasons) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        '・$reason',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                key: const Key('debt_danger_threshold_section'),
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      '通知基準のカスタマイズ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '収入に対する月次返済比率の目安',
                      style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        ChoiceChip(
                          key: const Key('debt_danger_ratio_chip_25'),
                          label: const Text('25%'),
                          selected:
                              (_settings.repaymentToIncomeThreshold - 0.25)
                                      .abs() <
                                  0.015,
                          onSelected: (_) => _updateSettings(
                            _settings.copyWith(
                              repaymentToIncomeThreshold: 0.25,
                            ),
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        ChoiceChip(
                          key: const Key('debt_danger_ratio_chip_33'),
                          label: const Text('33% (1/3)'),
                          selected:
                              (_settings.repaymentToIncomeThreshold - (1 / 3))
                                      .abs() <
                                  0.015,
                          onSelected: (_) => _updateSettings(
                            _settings.copyWith(
                              repaymentToIncomeThreshold: 1 / 3,
                            ),
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        ChoiceChip(
                          key: const Key('debt_danger_ratio_chip_40'),
                          label: const Text('40%'),
                          selected:
                              (_settings.repaymentToIncomeThreshold - 0.40)
                                      .abs() <
                                  0.015,
                          onSelected: (_) => _updateSettings(
                            _settings.copyWith(
                              repaymentToIncomeThreshold: 0.40,
                            ),
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        ChoiceChip(
                          key: const Key('debt_danger_ratio_chip_50'),
                          label: const Text('50%'),
                          selected:
                              (_settings.repaymentToIncomeThreshold - 0.50)
                                      .abs() <
                                  0.015,
                          onSelected: (_) => _updateSettings(
                            _settings.copyWith(
                              repaymentToIncomeThreshold: 0.50,
                            ),
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '残高が減らない連続月数の目安',
                      style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        for (final m in const <int>[2, 3, 4, 6])
                          ChoiceChip(
                            key: Key('debt_danger_months_chip_$m'),
                            label: Text('$mヶ月'),
                            selected: _settings.stagnantMonthsThreshold == m,
                            onSelected: (_) => _updateSettings(
                              _settings.copyWith(stagnantMonthsThreshold: m),
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text(
                        'ダッシュボードの案内バナーを表示する',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: !_settings.bannerDismissed,
                      onChanged: (show) => _updateSettings(
                        _settings.copyWith(bannerDismissed: !show),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                key: const Key('debt_relief_overview_section'),
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      '債務整理の基礎知識（一般的な制度概要）',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    for (final opt in AssetDebtDangerService.debtReliefOptions)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              '${opt.title}（目安: ${opt.typicalPeriod}）',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              opt.summary,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF334155),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '留意点: ${opt.keyNote}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                key: const Key('debt_consultation_links_section'),
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      '公的・中立的な無料相談窓口（外部公式サイト）',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    for (final resource
                        in AssetDebtDangerService.publicConsultationResources)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: OutlinedButton(
                          key: Key('debt_consultation_link_${resource.id}'),
                          style: OutlinedButton.styleFrom(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.all(10),
                          ),
                          onPressed: () =>
                              unawaited(_launchConsultationUrl(resource)),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      resource.title,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      resource.subtitle,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF475569),
                                      ),
                                    ),
                                    if (resource.phoneHint != null)
                                      Text(
                                        '電話窓口: ${resource.phoneHint}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF1D4ED8),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.open_in_new, size: 16),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const DebtLegalDisclaimerBanner(
                contextType: DebtLegalNoticeContext.debtReliefConsultation,
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('閉じる'),
        ),
      ],
    );
  }
}
