import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_web_app/services/asset_auto_transfer_service.dart';
import 'package:my_web_app/services/asset_tax_deduction_service.dart';

String _formatTaxYen(num value) {
  final rounded = value.round();
  final sign = rounded < 0 ? '-' : '';
  final digits = rounded.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buf.write(',');
    }
    buf.write(digits[i]);
  }
  return '$sign$buf円';
}

double? _parseTaxNumber(String raw) {
  final normalized = raw.replaceAll(',', '').replaceAll(' ', '').trim();
  if (normalized.isEmpty) return null;
  return double.tryParse(normalized);
}

/// 支払原資不足時の自動口座間移動 設定・候補確認・監査履歴ダイアログ (#3443)。
class AutoTransferSettingsAndAuditDialog extends StatefulWidget {
  final AutoTransferSettings initialSettings;
  final List<AutoTransferPlanCandidate> candidates;
  final List<AutoTransferAuditEntry> auditLogs;
  final ValueChanged<AutoTransferSettings> onSettingsChanged;
  final ValueChanged<AutoTransferPlanCandidate> onExecuteCandidate;

  const AutoTransferSettingsAndAuditDialog({
    super.key,
    required this.initialSettings,
    required this.candidates,
    required this.auditLogs,
    required this.onSettingsChanged,
    required this.onExecuteCandidate,
  });

  static Future<void> show(
    BuildContext context, {
    required AutoTransferSettings initialSettings,
    required List<AutoTransferPlanCandidate> candidates,
    required List<AutoTransferAuditEntry> auditLogs,
    required ValueChanged<AutoTransferSettings> onSettingsChanged,
    required ValueChanged<AutoTransferPlanCandidate> onExecuteCandidate,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => AutoTransferSettingsAndAuditDialog(
        initialSettings: initialSettings,
        candidates: candidates,
        auditLogs: auditLogs,
        onSettingsChanged: onSettingsChanged,
        onExecuteCandidate: onExecuteCandidate,
      ),
    );
  }

  @override
  State<AutoTransferSettingsAndAuditDialog> createState() =>
      _AutoTransferSettingsAndAuditDialogState();
}

class _AutoTransferSettingsAndAuditDialogState
    extends State<AutoTransferSettingsAndAuditDialog> {
  late AutoTransferSettings _settings;
  late List<AutoTransferAuditEntry> _logs;
  final Set<String> _executedKeys = <String>{};

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings;
    _logs = List<AutoTransferAuditEntry>.from(widget.auditLogs);
  }

  void _updateSettings(AutoTransferSettings next) {
    setState(() => _settings = next);
    widget.onSettingsChanged(next);
  }

  void _executeCandidate(AutoTransferPlanCandidate candidate) {
    widget.onExecuteCandidate(candidate);
    final bundle = AssetAutoTransferService.buildTransferTaskAndAudit(
      candidate: candidate,
      mode: _settings.executionMode,
      now: DateTime.now(),
    );
    setState(() {
      _executedKeys.add(candidate.suggestion.dedupeKey);
      _logs = <AutoTransferAuditEntry>[bundle.audit, ..._logs];
    });
  }

  @override
  Widget build(BuildContext context) {
    final dialogWidth = min(MediaQuery.sizeOf(context).width - 48, 680.0);
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      title: const Row(
        children: <Widget>[
          Icon(Icons.auto_mode_outlined, color: Color(0xFF0F766E)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '口座間移動の自動実行・監査履歴',
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
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SwitchListTile.adaptive(
                      key: const Key('auto_transfer_enabled_switch'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text(
                        '支払原資不足時の自動口座間移動を許可する',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: const Text(
                        '移動元の安全維持残高を下回らない範囲のみ対象にします。',
                        style: TextStyle(fontSize: 11),
                      ),
                      value: _settings.enabled,
                      onChanged: (enabled) => _updateSettings(
                        _settings.copyWith(enabled: enabled),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '実行方式',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        ChoiceChip(
                          key: const Key('auto_transfer_mode_prompt'),
                          label: const Text('実行前に最終確認'),
                          selected: _settings.executionMode ==
                              AutoTransferExecutionMode.promptConfirmation,
                          onSelected: (_) => _updateSettings(
                            _settings.copyWith(
                              executionMode:
                                  AutoTransferExecutionMode.promptConfirmation,
                            ),
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        ChoiceChip(
                          key: const Key('auto_transfer_mode_auto'),
                          label: const Text('検知時に自動起票'),
                          selected: _settings.executionMode ==
                              AutoTransferExecutionMode.autoCreateTask,
                          onSelected: (_) => _updateSettings(
                            _settings.copyWith(
                              executionMode:
                                  AutoTransferExecutionMode.autoCreateTask,
                            ),
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SwitchListTile.adaptive(
                      key: const Key('auto_transfer_notify_switch'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text(
                        '自動起票時に画面通知を表示',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: _settings.notifyOnExecution,
                      onChanged: (notify) => _updateSettings(
                        _settings.copyWith(notifyOnExecution: notify),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '移動額へ上乗せする安全余裕バッファ（円）',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        for (final buf in const <int>[0, 5000, 10000, 20000])
                          ChoiceChip(
                            key: Key('auto_transfer_buffer_chip_$buf'),
                            label: Text(_formatTaxYen(buf)),
                            selected:
                                (_settings.extraSafetyBuffer - buf).abs() < 1,
                            onSelected: (_) => _updateSettings(
                              _settings.copyWith(
                                extraSafetyBuffer: buf.toDouble(),
                              ),
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                key: const Key('auto_transfer_candidates_section'),
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDFA),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF99F6E4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '安全な補填候補（${widget.candidates.length}件）',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F766E),
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (widget.candidates.isEmpty)
                      const Text(
                        '現在、移動元の余裕残高を保ったまま起票できる不足補填候補はありません。',
                        style: TextStyle(fontSize: 12),
                      ),
                    for (final c in widget.candidates) ...<Widget>[
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: <Widget>[
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  '${c.suggestion.fromAccountName} → '
                                  '${c.suggestion.toAccountName}: '
                                  '${_formatTaxYen(c.suggestion.amount)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  '移動後の移動元見込み残高: '
                                  '${_formatTaxYen(c.donorRemainingProjectedBalance)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ],
                            ),
                            FilledButton(
                              key: Key(
                                'auto_transfer_execute_candidate_${c.suggestion.toAccountId}',
                              ),
                              onPressed: (c.alreadyTracked ||
                                      _executedKeys.contains(
                                        c.suggestion.dedupeKey,
                                      ))
                                  ? null
                                  : () => _executeCandidate(c),
                              child: Text(
                                (c.alreadyTracked ||
                                        _executedKeys.contains(
                                          c.suggestion.dedupeKey,
                                        ))
                                    ? '起票済み'
                                    : '確認して振替起票',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                key: const Key('auto_transfer_audit_history_section'),
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
                    Text(
                      '自動・確認実行の監査履歴（${_logs.length}件）',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (_logs.isEmpty)
                      const Text(
                        'まだ記録された実行履歴はありません。',
                        style: TextStyle(fontSize: 12),
                      ),
                    for (final entry in _logs.take(10))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                '${DateFormat('M/d HH:mm').format(entry.executedAt)} '
                                '${entry.fromAccountName} → ${entry.toAccountName} '
                                '${_formatTaxYen(entry.amount)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            Chip(
                              visualDensity: VisualDensity.compact,
                              label: Text(
                                entry.status == 'auto_created'
                                    ? '自動起票'
                                    : '確認実行',
                                style: const TextStyle(fontSize: 10),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
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

/// ふるさと納税 控除上限シミュレーターダイアログ (#2490)。
class FurusatoTaxCalculatorDialog extends StatefulWidget {
  final double? initialAnnualSalary;

  const FurusatoTaxCalculatorDialog({
    super.key,
    this.initialAnnualSalary,
  });

  static Future<void> show(
    BuildContext context, {
    double? initialAnnualSalary,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => FurusatoTaxCalculatorDialog(
        initialAnnualSalary: initialAnnualSalary,
      ),
    );
  }

  @override
  State<FurusatoTaxCalculatorDialog> createState() =>
      _FurusatoTaxCalculatorDialogState();
}

class _FurusatoTaxCalculatorDialogState
    extends State<FurusatoTaxCalculatorDialog> {
  late final TextEditingController _salaryController;
  late final TextEditingController _socialController;
  late double _salary;
  double? _socialOverride;
  FurusatoMaritalStatus _maritalStatus = FurusatoMaritalStatus.single;
  int _generalDependents = 0;
  int _specificDependents = 0;
  int _elderlyLivingTogether = 0;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialAnnualSalary;
    _salary = (initial != null && initial > 0) ? initial : 5000000;
    _salaryController = TextEditingController(text: _salary.round().toString());
    _socialController = TextEditingController();
  }

  @override
  void dispose() {
    _salaryController.dispose();
    _socialController.dispose();
    super.dispose();
  }

  Widget _buildCounterChip({
    required String label,
    required int count,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text('$label: $count人', style: const TextStyle(fontSize: 12)),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: count > 0 ? () => onChanged(count - 1) : null,
            icon: const Icon(Icons.remove_circle_outline, size: 16),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: count < 6 ? () => onChanged(count + 1) : null,
            icon: const Icon(Icons.add_circle_outline, size: 16),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dialogWidth = min(MediaQuery.sizeOf(context).width - 48, 680.0);
    final estimate = AssetFurusatoTaxCalculator.estimate(
      FurusatoTaxInput(
        annualSalaryIncome: _salary,
        maritalStatus: _maritalStatus,
        generalDependentsCount: _generalDependents,
        specificDependentsCount: _specificDependents,
        elderlyLivingTogetherCount: _elderlyLivingTogether,
        socialInsuranceOverride: _socialOverride,
      ),
    );

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      title: const Row(
        children: <Widget>[
          Icon(Icons.volunteer_activism_outlined, color: Color(0xFF0F766E)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'ふるさと納税 控除上限シミュレーター',
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
                runSpacing: 8,
                children: <Widget>[
                  SizedBox(
                    width: 210,
                    child: TextField(
                      key: const Key('furusato_salary_field'),
                      controller: _salaryController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '給与年収（円）',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        final parsed = _parseTaxNumber(value);
                        setState(() => _salary = max(0.0, parsed ?? 0.0));
                      },
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: TextField(
                      key: const Key('furusato_social_insurance_field'),
                      controller: _socialController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '社会保険料（任意・空欄は15%概算）',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(
                          () => _socialOverride = _parseTaxNumber(value),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                '家族構成',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  ChoiceChip(
                    key: const Key('furusato_marital_single'),
                    label: const Text('独身・共働き'),
                    selected: _maritalStatus !=
                        FurusatoMaritalStatus.marriedWithSpouseDeduction,
                    onSelected: (_) => setState(
                      () => _maritalStatus = FurusatoMaritalStatus.single,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  ChoiceChip(
                    key: const Key('furusato_marital_spouse'),
                    label: const Text('配偶者控除あり'),
                    selected: _maritalStatus ==
                        FurusatoMaritalStatus.marriedWithSpouseDeduction,
                    onSelected: (_) => setState(
                      () => _maritalStatus =
                          FurusatoMaritalStatus.marriedWithSpouseDeduction,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: <Widget>[
                  _buildCounterChip(
                    label: '一般扶養',
                    count: _generalDependents,
                    onChanged: (v) => setState(() => _generalDependents = v),
                  ),
                  _buildCounterChip(
                    label: '特定扶養(19-22歳)',
                    count: _specificDependents,
                    onChanged: (v) => setState(() => _specificDependents = v),
                  ),
                  _buildCounterChip(
                    label: '老人扶養(同居)',
                    count: _elderlyLivingTogether,
                    onChanged: (v) =>
                        setState(() => _elderlyLivingTogether = v),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                key: const Key('furusato_result_card'),
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDFA),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF99F6E4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '控除上限額の目安: ${_formatTaxYen(estimate.estimatedLimitYen)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F766E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '自己負担額目安: ${_formatTaxYen(estimate.selfBurdenYen)} / '
                      '所得税率 ${(estimate.incomeTaxRate * 100).toStringAsFixed(0)}% / '
                      '住民税所得割 ${_formatTaxYen(estimate.residentTaxIncomePortion)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF134E4A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '給与所得: ${_formatTaxYen(estimate.salaryIncome)}（給与所得控除 ${_formatTaxYen(estimate.salaryDeduction)}） / '
                      '社会保険料控除: ${_formatTaxYen(estimate.socialInsuranceUsed)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 6),
                    for (final note in estimate.notes)
                      Text(
                        '・$note',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF475569),
                        ),
                      ),
                  ],
                ),
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

/// 医療費控除トラッカー・年累計判定ダイアログ (#2491)。
class MedicalExpenseTrackerDialog extends StatefulWidget {
  final List<MedicalExpenseEntry> initialEntries;
  final int taxYear;
  final double? annualTotalIncome;
  final ValueChanged<List<MedicalExpenseEntry>> onEntriesChanged;

  const MedicalExpenseTrackerDialog({
    super.key,
    required this.initialEntries,
    required this.taxYear,
    this.annualTotalIncome,
    required this.onEntriesChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required List<MedicalExpenseEntry> initialEntries,
    required int taxYear,
    double? annualTotalIncome,
    required ValueChanged<List<MedicalExpenseEntry>> onEntriesChanged,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => MedicalExpenseTrackerDialog(
        initialEntries: initialEntries,
        taxYear: taxYear,
        annualTotalIncome: annualTotalIncome,
        onEntriesChanged: onEntriesChanged,
      ),
    );
  }

  @override
  State<MedicalExpenseTrackerDialog> createState() =>
      _MedicalExpenseTrackerDialogState();
}

class _MedicalExpenseTrackerDialogState
    extends State<MedicalExpenseTrackerDialog> {
  late List<MedicalExpenseEntry> _entries;
  late final TextEditingController _amountController;
  late final TextEditingController _reimburseController;
  late final TextEditingController _memoController;

  MedicalExpenseCategory _category = MedicalExpenseCategory.hospital;
  int _selectedMonth = 6;
  String? _formError;
  int _counter = 0;

  @override
  void initState() {
    super.initState();
    _entries = List<MedicalExpenseEntry>.from(widget.initialEntries);
    _amountController = TextEditingController();
    _reimburseController = TextEditingController(text: '0');
    _memoController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _reimburseController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  void _addEntry() {
    final amount = _parseTaxNumber(_amountController.text);
    final reimburse = _parseTaxNumber(_reimburseController.text) ?? 0.0;
    if (amount == null || amount <= 0) {
      setState(() => _formError = '支払金額（1円以上）を入力してください。');
      return;
    }
    if (reimburse < 0) {
      setState(() => _formError = '補填金額は0円以上を入力してください。');
      return;
    }
    _counter++;
    final entry = MedicalExpenseEntry(
      id: 'med_${widget.taxYear}_$_counter',
      date: DateTime(widget.taxYear, _selectedMonth, 15),
      category: _category,
      amount: amount,
      reimbursementAmount: reimburse,
      memo: _memoController.text.trim(),
    );
    final next = <MedicalExpenseEntry>[entry, ..._entries];
    setState(() {
      _entries = next;
      _formError = null;
      _amountController.clear();
      _reimburseController.text = '0';
      _memoController.clear();
    });
    widget.onEntriesChanged(List<MedicalExpenseEntry>.unmodifiable(next));
  }

  void _removeEntry(String id) {
    final next = _entries.where((e) => e.id != id).toList(growable: false);
    setState(() => _entries = next);
    widget.onEntriesChanged(List<MedicalExpenseEntry>.unmodifiable(next));
  }

  @override
  Widget build(BuildContext context) {
    final dialogWidth = min(MediaQuery.sizeOf(context).width - 48, 680.0);
    final summary = AssetMedicalExpenseService.summarizeYear(
      taxYear: widget.taxYear,
      entries: _entries,
      annualTotalIncome: widget.annualTotalIncome,
    );

    final String? alertText;
    if (summary.isAtCap) {
      alertText = '控除上限（200万円）に達しています。';
    } else if (summary.isDeductionEligible) {
      alertText =
          '年間実質医療費が基準額（${_formatTaxYen(summary.deductionThreshold)}）を超えました。'
          '控除見込額: ${_formatTaxYen(summary.estimatedDeduction)}';
    } else if (summary.isApproachingThreshold) {
      alertText =
          '控除基準額まであと ${_formatTaxYen(summary.amountToThreshold)} です（確定申告の領収書保管を推奨）。';
    } else {
      alertText = null;
    }

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      title: Row(
        children: <Widget>[
          const Icon(Icons.local_hospital_outlined, color: Color(0xFF0F766E)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '医療費控除トラッカー（${widget.taxYear}年）',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
                key: const Key('medical_expense_summary_card'),
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDFA),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF99F6E4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '年間実質医療費: ${_formatTaxYen(summary.netTotal)} / '
                      '基準額: ${_formatTaxYen(summary.deductionThreshold)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F766E),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '支払総額: ${_formatTaxYen(summary.grossTotal)} / '
                      '保険補填等: ${_formatTaxYen(summary.reimbursementTotal)} / '
                      '控除対象見込: ${_formatTaxYen(summary.estimatedDeduction)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (alertText != null) ...<Widget>[
                      const SizedBox(height: 6),
                      Container(
                        key: const Key('medical_expense_threshold_alert'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: summary.isDeductionEligible
                              ? const Color(0xFFECFDF5)
                              : const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: summary.isDeductionEligible
                                ? const Color(0xFF10B981)
                                : const Color(0xFFF59E0B),
                          ),
                        ),
                        child: Text(
                          alertText,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Container(
                key: const Key('medical_expense_category_breakdown'),
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: <Widget>[
                    for (final cat in MedicalExpenseCategory.values)
                      Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text(
                          '${cat.label}: ${_formatTaxYen(summary.categoryTotals[cat] ?? 0)}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '月次医療費を追加',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  for (final cat in MedicalExpenseCategory.values)
                    ChoiceChip(
                      key: Key('medical_category_chip_${cat.name}'),
                      label: Text(cat.label),
                      selected: _category == cat,
                      onSelected: (_) => setState(() => _category = cat),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  SizedBox(
                    width: 110,
                    child: DropdownButtonFormField<int>(
                      initialValue: _selectedMonth,
                      decoration: const InputDecoration(
                        labelText: '月',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: <DropdownMenuItem<int>>[
                        for (var m = 1; m <= 12; m++)
                          DropdownMenuItem<int>(value: m, child: Text('$m月')),
                      ],
                      onChanged: (m) {
                        if (m != null) {
                          setState(() => _selectedMonth = m);
                        }
                      },
                    ),
                  ),
                  SizedBox(
                    width: 150,
                    child: TextField(
                      key: const Key('medical_entry_amount_field'),
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '支払額（円）',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 150,
                    child: TextField(
                      key: const Key('medical_entry_reimbursement_field'),
                      controller: _reimburseController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '保険補填（円）',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: TextField(
                      key: const Key('medical_entry_memo_field'),
                      controller: _memoController,
                      decoration: const InputDecoration(
                        labelText: '病院・薬局メモ',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              if (_formError != null) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  _formError!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFB91C1C),
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  key: const Key('medical_entry_add_button'),
                  onPressed: _addEntry,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('記録を追加'),
                ),
              ),
              const SizedBox(height: 8),
              for (final entry in summary.entries)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${entry.date.month}月 ${entry.category.label}: '
                    '${_formatTaxYen(entry.amount)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '補填 ${_formatTaxYen(entry.reimbursementAmount)} / '
                    '実質 ${_formatTaxYen(entry.netAmount)}'
                    '${entry.memo.isEmpty ? '' : '・${entry.memo}'}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: IconButton(
                    key: Key('medical_entry_delete_${entry.id}'),
                    tooltip: '削除',
                    onPressed: () => _removeEntry(entry.id),
                    icon: const Icon(Icons.delete_outline, size: 18),
                  ),
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
