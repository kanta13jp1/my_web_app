import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/card_statement_reconciliation_planner.dart';

/// 3ステップ手動照合ウィザードの入力結果 (#3329)。
class CardManualReconciliationWizardResult {
  final String billingAccountId;
  final String billingAccountName;
  final double amount;
  final String description;
  final bool adjustConfiguredTotal;

  const CardManualReconciliationWizardResult({
    required this.billingAccountId,
    required this.billingAccountName,
    required this.amount,
    required this.description,
    required this.adjustConfiguredTotal,
  });
}

/// 仮内訳登録ダイアログの入力ドラフト (#3349)。
class CardProvisionalDetailDraft {
  final double amount;
  final String memo;

  const CardProvisionalDetailDraft({
    required this.amount,
    required this.memo,
  });
}

String _formatYenText(double value) {
  final rounded = value.round();
  final digits = rounded.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[i]);
  }
  return '${rounded < 0 ? '-' : ''}¥$buffer';
}

double? _parseYenAmount(String raw) {
  final normalized = raw.replaceAll(',', '').replaceAll('¥', '').trim();
  if (normalized.isEmpty) {
    return null;
  }
  return double.tryParse(normalized);
}

/// 3ステップの手動照合ウィザード（請求額確認 → 差分入力 → 確認・保存）(#3329)。
class CardStatementManualReconciliationWizardDialog extends StatefulWidget {
  final List<AssetLiabilityCardStatementReconciliationGroup> needsReviewGroups;
  final String? initialBillingAccountId;

  const CardStatementManualReconciliationWizardDialog({
    super.key,
    required this.needsReviewGroups,
    this.initialBillingAccountId,
  });

  @override
  State<CardStatementManualReconciliationWizardDialog> createState() =>
      _CardStatementManualReconciliationWizardDialogState();
}

class _CardStatementManualReconciliationWizardDialogState
    extends State<CardStatementManualReconciliationWizardDialog> {
  int _step = 0;
  late String _selectedAccountId;
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    final initialGroup = _resolveInitialGroup();
    _selectedAccountId = initialGroup.billingAccountId;
    final suggested =
        CardStatementReconciliationPlanner.suggestedBalancingAmount(
            initialGroup);
    _amountController = TextEditingController(
      text: suggested > 0 ? suggested.round().toString() : '',
    );
    _descriptionController = TextEditingController(text: '手動照合差分');
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  AssetLiabilityCardStatementReconciliationGroup _resolveInitialGroup() {
    final targetId = widget.initialBillingAccountId;
    if (targetId != null) {
      for (final group in widget.needsReviewGroups) {
        if (group.billingAccountId == targetId) {
          return group;
        }
      }
    }
    return widget.needsReviewGroups.first;
  }

  AssetLiabilityCardStatementReconciliationGroup get _currentGroup {
    for (final group in widget.needsReviewGroups) {
      if (group.billingAccountId == _selectedAccountId) {
        return group;
      }
    }
    return widget.needsReviewGroups.first;
  }

  void _selectGroup(String billingAccountId) {
    setState(() {
      _selectedAccountId = billingAccountId;
      final group = _currentGroup;
      final suggested =
          CardStatementReconciliationPlanner.suggestedBalancingAmount(group);
      _amountController.text =
          suggested > 0 ? suggested.round().toString() : '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final group = _currentGroup;
    final amount = _parseYenAmount(_amountController.text) ?? 0;
    final adjustConfigured = group.configuredDifference <
            -CardStatementReconciliationPlanner.balanceTolerance ||
        (group.configuredDetailTotal == 0 && amount > 0);
    final preview = CardStatementReconciliationPlanner.previewAdjustment(
      group: group,
      additionalAmount: amount,
      applyToConfigured: adjustConfigured,
      applyToStatement: !group.hasStatementLines ||
          group.statementDifference <
              -CardStatementReconciliationPlanner.balanceTolerance,
    );

    return AlertDialog(
      key: const Key('card_reconciliation_wizard_dialog'),
      title: const Text('カード明細 手動照合ウィザード'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _WizardStepPill(label: '1. 請求額確認', active: _step == 0),
                  _WizardStepPill(label: '2. 差分入力', active: _step == 1),
                  _WizardStepPill(label: '3. 確認・保存', active: _step == 2),
                ],
              ),
              const SizedBox(height: 12),
              if (_step == 0) ...[
                if (widget.needsReviewGroups.length > 1) ...[
                  DropdownButtonFormField<String>(
                    initialValue: group.billingAccountId,
                    decoration: const InputDecoration(
                      labelText: '照合対象カード',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      for (final item in widget.needsReviewGroups)
                        DropdownMenuItem<String>(
                          value: item.billingAccountId,
                          child: Text(item.billingAccountName),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        _selectGroup(value);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                ],
                _SummaryRow(
                  label: '対象カード',
                  value: group.billingAccountName,
                ),
                _SummaryRow(
                  label: '請求額',
                  value: _formatYenText(group.billedAmount),
                ),
                _SummaryRow(
                  label: '設定内訳合計',
                  value: _formatYenText(group.configuredDetailTotal),
                ),
                _SummaryRow(
                  label: '明細合計',
                  value: _formatYenText(group.statementLineTotal),
                ),
                _SummaryRow(
                  label: '設定差分',
                  value: _formatYenText(group.configuredDifference),
                ),
                if (group.alerts.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  for (final alert in group.alerts)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            size: 16,
                            color: Color(0xFFD97706),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              alert,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ] else if (_step == 1) ...[
                Text(
                  '${group.billingAccountName} の不足差分を入力してください。',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const Key('card_recon_wizard_amount_field'),
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '調整金額（円）',
                    suffixText: '円',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const Key('card_recon_wizard_description_field'),
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: '調整メモ・摘要',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                _PreviewStatusBox(
                  preview: preview,
                  billedAmount: group.billedAmount,
                ),
              ] else ...[
                Text(
                  '反映内容を確認して保存してください。',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                _SummaryRow(
                  label: '対象カード',
                  value: group.billingAccountName,
                ),
                _SummaryRow(
                  label: '請求額',
                  value: _formatYenText(group.billedAmount),
                ),
                _SummaryRow(
                  label: '反映後 設定内訳合計',
                  value: _formatYenText(preview.projectedConfiguredTotal),
                ),
                _SummaryRow(
                  label: '反映後 明細合計',
                  value: _formatYenText(preview.projectedStatementTotal),
                ),
                _SummaryRow(
                  label: '残差分',
                  value: _formatYenText(preview.projectedConfiguredDifference),
                ),
                const SizedBox(height: 8),
                _PreviewStatusBox(
                  preview: preview,
                  billedAmount: group.billedAmount,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (_step > 0)
          TextButton(
            onPressed: () => setState(() => _step -= 1),
            child: const Text('戻る'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        if (_step == 0)
          FilledButton(
            key: const Key('card_recon_wizard_next_step1'),
            onPressed: () => setState(() => _step = 1),
            child: const Text('次へ（差分入力）'),
          )
        else if (_step == 1)
          FilledButton(
            key: const Key('card_recon_wizard_next_step2'),
            onPressed: amount > 0 ? () => setState(() => _step = 2) : null,
            child: const Text('次へ（確認）'),
          )
        else
          FilledButton(
            key: const Key('card_recon_wizard_save_button'),
            onPressed: amount > 0
                ? () {
                    final desc = _descriptionController.text.trim();
                    Navigator.of(context).pop(
                      CardManualReconciliationWizardResult(
                        billingAccountId: group.billingAccountId,
                        billingAccountName: group.billingAccountName,
                        amount: amount,
                        description: desc.isEmpty ? '手動照合差分' : desc,
                        adjustConfiguredTotal: adjustConfigured,
                      ),
                    );
                  }
                : null,
            child: const Text('保存して照合完了'),
          ),
      ],
    );
  }
}

class _ManualStatementEntryRowControllers {
  final TextEditingController dateController;
  final TextEditingController amountController;
  final TextEditingController descriptionController;
  String category;

  _ManualStatementEntryRowControllers({
    required DateTime initialDate,
    this.category = 'その他',
  })  : dateController = TextEditingController(
          text: DateFormat('yyyy-MM-dd').format(initialDate),
        ),
        amountController = TextEditingController(),
        descriptionController = TextEditingController();

  void dispose() {
    dateController.dispose();
    amountController.dispose();
    descriptionController.dispose();
  }
}

/// 複数行の手動明細入力と整合チェックダイアログ (#3326)。
class CardManualStatementEntryDialog extends StatefulWidget {
  final AssetLiabilityCardStatementReconciliationGroup group;
  final DateTime initialDate;

  const CardManualStatementEntryDialog({
    super.key,
    required this.group,
    required this.initialDate,
  });

  @override
  State<CardManualStatementEntryDialog> createState() =>
      _CardManualStatementEntryDialogState();
}

class _CardManualStatementEntryDialogState
    extends State<CardManualStatementEntryDialog> {
  static const List<String> _categories = <String>[
    '食費',
    '日用品',
    'サブスク',
    '交通・通信',
    '固定費',
    'その他',
  ];

  final List<_ManualStatementEntryRowControllers> _rows =
      <_ManualStatementEntryRowControllers>[];
  bool _allowMismatchSave = false;

  @override
  void initState() {
    super.initState();
    _rows.add(
      _ManualStatementEntryRowControllers(initialDate: widget.initialDate),
    );
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  void _addRow() {
    setState(() {
      _rows.add(
        _ManualStatementEntryRowControllers(initialDate: widget.initialDate),
      );
    });
  }

  void _removeRow(int index) {
    if (_rows.length <= 1) {
      return;
    }
    setState(() {
      final removed = _rows.removeAt(index);
      removed.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final parsedAmounts = [
      for (final row in _rows) _parseYenAmount(row.amountController.text),
    ];
    final hasPositiveAmount = parsedAmounts.any((a) => a != null && a > 0);
    final allNonEmptyPositive = parsedAmounts.every((a) => a != null && a > 0);
    final inputTotal = parsedAmounts.fold<double>(
      0,
      (sum, value) => sum + (value != null && value > 0 ? value : 0),
    );
    final adjustConfigured = widget.group.configuredDifference <
            -CardStatementReconciliationPlanner.balanceTolerance ||
        (widget.group.configuredDetailTotal == 0 && inputTotal > 0);
    final applyToStatement = !widget.group.hasStatementLines ||
        widget.group.statementDifference <
            -CardStatementReconciliationPlanner.balanceTolerance;
    final preview = CardStatementReconciliationPlanner.previewAdjustment(
      group: widget.group,
      additionalAmount: inputTotal,
      applyToConfigured: adjustConfigured,
      applyToStatement: applyToStatement,
    );
    final isEntryMatched = !widget.group.isRevolving &&
        (preview.resolvesAlert ||
            ((!adjustConfigured || preview.isBalanced) &&
                (!applyToStatement ||
                    preview.projectedStatementDifference.abs() <=
                        CardStatementReconciliationPlanner.balanceTolerance)));
    final canSave = hasPositiveAmount &&
        allNonEmptyPositive &&
        (isEntryMatched || widget.group.isRevolving || _allowMismatchSave);

    return AlertDialog(
      key: const Key('card_manual_statement_entry_dialog'),
      title: Text('${widget.group.billingAccountName} 手動で明細を追加'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '請求額 ${_formatYenText(widget.group.billedAmount)} / '
                '設定内訳合計 ${_formatYenText(widget.group.configuredDetailTotal)}',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 10),
              for (var i = 0; i < _rows.length; i++) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '明細 ${i + 1}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const Spacer(),
                          if (_rows.length > 1)
                            IconButton(
                              tooltip: '行を削除',
                              onPressed: () => _removeRow(i),
                              icon: const Icon(Icons.close, size: 18),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _rows[i].dateController,
                              decoration: const InputDecoration(
                                labelText: '利用日 (YYYY-MM-DD)',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              key: Key('card_manual_entry_amount_$i'),
                              controller: _rows[i].amountController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: '金額（円）',
                                suffixText: '円',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              key: Key('card_manual_entry_desc_$i'),
                              controller: _rows[i].descriptionController,
                              decoration: const InputDecoration(
                                labelText: '摘要',
                                hintText: '例: コンビニ・光熱費',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _rows[i].category,
                              decoration: const InputDecoration(
                                labelText: 'カテゴリ',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: [
                                for (final category in _categories)
                                  DropdownMenuItem<String>(
                                    value: category,
                                    child: Text(category),
                                  ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _rows[i].category = value);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              OutlinedButton.icon(
                key: const Key('card_manual_entry_add_row'),
                onPressed: _addRow,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('明細行を追加'),
              ),
              const SizedBox(height: 10),
              _SummaryRow(
                label: '入力合計',
                value: _formatYenText(inputTotal),
              ),
              _PreviewStatusBox(
                preview: preview,
                billedAmount: widget.group.billedAmount,
              ),
              if (hasPositiveAmount &&
                  !isEntryMatched &&
                  !widget.group.isRevolving) ...[
                const SizedBox(height: 8),
                Container(
                  key: const Key('card_manual_entry_mismatch_warning'),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFF59E0B)),
                  ),
                  child: const Text(
                    '入力合計が請求額と一致しないため保存をブロックしています。金額を修正するか、下の確認チェックを有効にしてください。',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                CheckboxListTile(
                  key: const Key('card_manual_entry_allow_mismatch_checkbox'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: _allowMismatchSave,
                  onChanged: (checked) {
                    setState(() => _allowMismatchSave = checked ?? false);
                  },
                  title: const Text(
                    '差分が残ったまま保存する',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          key: const Key('card_manual_entry_save_button'),
          onPressed: canSave
              ? () {
                  final baseMillis = DateTime.now().millisecondsSinceEpoch;
                  final lines = <AssetLiabilityCardStatementLine>[];
                  for (var i = 0; i < _rows.length; i++) {
                    final row = _rows[i];
                    final amount = _parseYenAmount(row.amountController.text);
                    if (amount == null || amount <= 0) {
                      continue;
                    }
                    final desc = row.descriptionController.text.trim();
                    final postedAt =
                        DateTime.tryParse(row.dateController.text.trim()) ??
                            widget.initialDate;
                    lines.add(
                      AssetLiabilityCardStatementLine(
                        id: 'manual_${widget.group.billingAccountId}_${baseMillis}_$i',
                        billingAccountId: widget.group.billingAccountId,
                        billingAccountName: widget.group.billingAccountName,
                        postedAt: postedAt,
                        description: desc.isEmpty ? '手動明細' : desc,
                        amount: amount,
                        category: row.category,
                        isConfiguredAdjustment: adjustConfigured,
                      ),
                    );
                  }
                  Navigator.of(context).pop(lines);
                }
              : null,
          child: const Text('明細を保存'),
        ),
      ],
    );
  }
}

/// 照合差分を仮内訳として一時記録するダイアログ (#3349)。
class CardProvisionalDetailDialog extends StatefulWidget {
  final AssetLiabilityCardStatementReconciliationGroup group;

  const CardProvisionalDetailDialog({
    super.key,
    required this.group,
  });

  @override
  State<CardProvisionalDetailDialog> createState() =>
      _CardProvisionalDetailDialogState();
}

class _CardProvisionalDetailDialogState
    extends State<CardProvisionalDetailDialog> {
  late final TextEditingController _amountController;
  late final TextEditingController _memoController;

  @override
  void initState() {
    super.initState();
    final diff = widget.group.configuredDifference.abs() >
            CardStatementReconciliationPlanner.balanceTolerance
        ? widget.group.configuredDifference.abs()
        : widget.group.statementDifference.abs();
    _amountController = TextEditingController(
      text: diff > 0 ? diff.round().toString() : '',
    );
    _memoController = TextEditingController(
      text: '${widget.group.billingAccountName} 仮内訳',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final amount = _parseYenAmount(_amountController.text) ?? 0;

    return AlertDialog(
      key: const Key('card_provisional_detail_dialog'),
      title: Text('${widget.group.billingAccountName} 仮内訳として追加'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '仮内訳は正式内訳合計には含まれません（二重計上防止）。後から正式内訳へ昇格・削除できます。',
                style: TextStyle(fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('card_provisional_amount_field'),
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '差分金額（円）',
                  suffixText: '円',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('card_provisional_memo_field'),
                controller: _memoController,
                decoration: const InputDecoration(
                  labelText: 'メモ',
                  hintText: '例: auPAY未取込分（後日明細確認）',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          key: const Key('card_provisional_save_button'),
          onPressed: amount > 0
              ? () {
                  final memo = _memoController.text.trim();
                  Navigator.of(context).pop(
                    CardProvisionalDetailDraft(
                      amount: amount,
                      memo: memo.isEmpty ? '仮内訳' : memo,
                    ),
                  );
                }
              : null,
          child: const Text('仮内訳を保存'),
        ),
      ],
    );
  }
}

class _WizardStepPill extends StatelessWidget {
  final String label;
  final bool active;

  const _WizardStepPill({
    required this.label,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final color = active
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.outlineVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: active
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: active ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _PreviewStatusBox extends StatelessWidget {
  final CardStatementAdjustmentPreview preview;
  final double billedAmount;

  const _PreviewStatusBox({
    required this.preview,
    required this.billedAmount,
  });

  @override
  Widget build(BuildContext context) {
    final isOk = preview.resolvesAlert || preview.isBalanced;
    final bgColor = isOk
        ? const Color(0xFFECFDF5)
        : (preview.isOvershoot
            ? const Color(0xFFFEF2F2)
            : const Color(0xFFFFFBEB));
    final borderColor = isOk
        ? const Color(0xFF10B981)
        : (preview.isOvershoot
            ? const Color(0xFFEF4444)
            : const Color(0xFFF59E0B));
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '反映後の設定内訳合計: ${_formatYenText(preview.projectedConfiguredTotal)} '
            '（請求額 ${_formatYenText(billedAmount)} との差 '
            '${_formatYenText(preview.projectedConfiguredDifference)}）',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            preview.statusMessage,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
