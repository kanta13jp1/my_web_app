import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_safety_transfer_suggestion_service.dart';
import 'package:my_web_app/services/payment_confirmation_gate.dart';

String _formatDialogYen(double value) {
  final formatted = NumberFormat('#,##0', 'ja_JP').format(value.round().abs());
  return value < 0 ? '-¥$formatted' : '¥$formatted';
}

/// 安全残高割れを予防する振替タスクの編集・起票ウィザード (#3350)。
class AssetSafetyTransferWizardDialog extends StatefulWidget {
  final AssetSafetyTransferSuggestion suggestion;
  final List<AssetLiabilityAccount> donorOptions;
  final DateTime baseDate;

  const AssetSafetyTransferWizardDialog({
    super.key,
    required this.suggestion,
    required this.donorOptions,
    required this.baseDate,
  });

  @override
  State<AssetSafetyTransferWizardDialog> createState() =>
      _AssetSafetyTransferWizardDialogState();
}

class _AssetSafetyTransferWizardDialogState
    extends State<AssetSafetyTransferWizardDialog> {
  late final TextEditingController _amountController;
  late String _selectedFromAccountId;
  DateTime? _neededBy;
  String? _errorText;

  List<({String id, String name, double? balance})> get _effectiveDonors {
    final map = <String, ({String id, String name, double? balance})>{};
    for (final account in widget.donorOptions) {
      if (account.id == widget.suggestion.toAccountId) {
        continue;
      }
      map[account.id] = (
        id: account.id,
        name: account.name,
        balance: account.balance,
      );
    }
    map.putIfAbsent(
      widget.suggestion.fromAccountId,
      () => (
        id: widget.suggestion.fromAccountId,
        name: widget.suggestion.fromAccountName,
        balance: null,
      ),
    );
    return map.values.toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.suggestion.amount.round().toString(),
    );
    _selectedFromAccountId = widget.suggestion.fromAccountId;
    _neededBy = widget.suggestion.neededBy;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  String _selectedFromAccountName() {
    for (final donor in _effectiveDonors) {
      if (donor.id == _selectedFromAccountId) {
        return donor.name;
      }
    }
    return widget.suggestion.fromAccountName;
  }

  Future<void> _pickNeededBy() async {
    final initial = _neededBy ?? widget.baseDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(widget.baseDate.year - 1),
      lastDate: DateTime(widget.baseDate.year + 2),
    );
    if (!mounted || picked == null) {
      return;
    }
    setState(() {
      _neededBy = DateTime(picked.year, picked.month, picked.day);
    });
  }

  void _submit() {
    final normalized = _amountController.text.replaceAll(',', '').trim();
    final amount = double.tryParse(normalized);
    if (amount == null || amount <= 0) {
      setState(() {
        _errorText = '振替金額は 1 円以上で入力してください。';
      });
      return;
    }
    if (_selectedFromAccountId == widget.suggestion.toAccountId) {
      setState(() {
        _errorText = '振替元と振替先には異なる口座を指定してください。';
      });
      return;
    }
    Navigator.of(context).pop(
      AssetLiabilityTransferSuggestion(
        fromAccountId: _selectedFromAccountId,
        fromAccountName: _selectedFromAccountName(),
        toAccountId: widget.suggestion.toAccountId,
        toAccountName: widget.suggestion.toAccountName,
        amount: amount,
        neededBy: _neededBy,
        targetPaymentName: widget.suggestion.targetPaymentName,
        targetPaymentDate: widget.suggestion.targetPaymentDate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final donors = _effectiveDonors;
    final dateLabel = _neededBy == null
        ? '期限未指定（できるだけ早く）'
        : DateFormat('yyyy/MM/dd').format(_neededBy!);

    return AlertDialog(
      title: const Text('安全残高の振替タスク作成'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDFA),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF99F6E4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '振替先: ${widget.suggestion.toAccountName}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '見込み残高 ${_formatDialogYen(widget.suggestion.projectedBalanceBefore)} / '
                      '安全基準 ${_formatDialogYen(widget.suggestion.minimumSafetyBalance)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (widget.suggestion.isSameBankFreeTransfer)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          '同一銀行・無料振替優先候補',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F766E),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const Key('safety_transfer_from_dropdown'),
                initialValue: _selectedFromAccountId,
                decoration: const InputDecoration(
                  labelText: '振替元口座',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final donor in donors)
                    DropdownMenuItem<String>(
                      value: donor.id,
                      child: Text(
                        donor.balance == null
                            ? donor.name
                            : '${donor.name}（残高 ${_formatDialogYen(donor.balance!)}）',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _selectedFromAccountId = value;
                    _errorText = null;
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('safety_transfer_amount_field'),
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9,]')),
                ],
                decoration: const InputDecoration(
                  labelText: '振替金額（概算）',
                  suffixText: '円',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) {
                  if (_errorText != null) {
                    setState(() {
                      _errorText = null;
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('safety_transfer_due_date_button'),
                onPressed: () => _pickNeededBy(),
                icon: const Icon(Icons.calendar_today_outlined, size: 16),
                label: Text('振替期限: $dateLabel'),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorText!,
                  key: const Key('safety_transfer_error_text'),
                  style: const TextStyle(
                    color: Color(0xFFB91C1C),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('safety_transfer_cancel_button'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        FilledButton.icon(
          key: const Key('safety_transfer_submit_button'),
          onPressed: _submit,
          icon: const Icon(Icons.swap_horiz_rounded, size: 18),
          label: const Text('振替タスクを起票'),
        ),
      ],
    );
  }
}

/// 給料日・入金予定登録ウィザードの出力 (#3291)。
class AssetIncomePlanPaydayDraft {
  final int dayOfMonth;
  final double amount;
  final String name;
  final String? destinationAccountId;
  final String? destinationAccountName;
  final bool registerAsRecurring;

  const AssetIncomePlanPaydayDraft({
    required this.dayOfMonth,
    required this.amount,
    required this.name,
    required this.destinationAccountId,
    required this.destinationAccountName,
    required this.registerAsRecurring,
  });
}

/// 今月の給料日・入金予定を素早く登録するウィザード (#3291)。
class AssetIncomePlanPaydayWizardDialog extends StatefulWidget {
  final List<AssetLiabilityAccount> destinationOptions;
  final DateTime baseDate;
  final String initialName;
  final int initialDayOfMonth;

  const AssetIncomePlanPaydayWizardDialog({
    super.key,
    required this.destinationOptions,
    required this.baseDate,
    this.initialName = '給与',
    this.initialDayOfMonth = 25,
  });

  @override
  State<AssetIncomePlanPaydayWizardDialog> createState() =>
      _AssetIncomePlanPaydayWizardDialogState();
}

class _AssetIncomePlanPaydayWizardDialogState
    extends State<AssetIncomePlanPaydayWizardDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _dayController;
  late final TextEditingController _amountController;
  String? _selectedDestinationId;
  bool _registerAsRecurring = true;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _dayController = TextEditingController(
      text: widget.initialDayOfMonth.toString(),
    );
    _amountController = TextEditingController();
    _selectedDestinationId = widget.destinationOptions.isNotEmpty
        ? widget.destinationOptions.first.id
        : null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dayController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  String? _destinationNameFor(String? accountId) {
    if (accountId == null) {
      return null;
    }
    for (final account in widget.destinationOptions) {
      if (account.id == accountId) {
        return account.name;
      }
    }
    return null;
  }

  void _submit() {
    final dayOfMonth = int.tryParse(_dayController.text.trim());
    final amount = double.tryParse(
      _amountController.text.replaceAll(',', '').trim(),
    );
    final name = _nameController.text.trim();
    final validationError = PaymentConfirmationGate.validateIncomePlanInput(
      dayOfMonth: dayOfMonth,
      amount: amount,
      name: name,
    );
    if (validationError != null) {
      setState(() {
        _errorText = validationError;
      });
      return;
    }
    Navigator.of(context).pop(
      AssetIncomePlanPaydayDraft(
        dayOfMonth: dayOfMonth!,
        amount: amount!,
        name: name,
        destinationAccountId: _selectedDestinationId,
        destinationAccountName: _destinationNameFor(_selectedDestinationId),
        registerAsRecurring: _registerAsRecurring,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('入金予定・給料日を登録'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.baseDate.year}年${widget.baseDate.month}月の給料日・金額・入金先口座を登録すると、'
                '口座別資金繰りと使用可能額の試算が確定します。',
                style: const TextStyle(fontSize: 12, height: 1.5),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('income_wizard_name_field'),
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '収入名',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('income_wizard_day_field'),
                controller: _dayController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: '給料日・入金日 (1〜31日)',
                  suffixText: '日',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('income_wizard_amount_field'),
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9,]')),
                ],
                decoration: const InputDecoration(
                  labelText: '入金予定額',
                  suffixText: '円',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                key: const Key('income_wizard_destination_dropdown'),
                initialValue: _selectedDestinationId,
                decoration: const InputDecoration(
                  labelText: '入金先口座',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('未指定（全体残高に合算）'),
                  ),
                  for (final account in widget.destinationOptions)
                    DropdownMenuItem<String?>(
                      value: account.id,
                      child: Text(
                        '${account.name}（残高 ${_formatDialogYen(account.balance)}）',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedDestinationId = value;
                  });
                },
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                key: const Key('income_wizard_recurring_checkbox'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _registerAsRecurring,
                onChanged: (value) {
                  setState(() {
                    _registerAsRecurring = value ?? true;
                  });
                },
                title: const Text(
                  '毎月の定期収入テンプレートにも保存',
                  style: TextStyle(fontSize: 13),
                ),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 6),
                Text(
                  _errorText!,
                  key: const Key('income_wizard_error_text'),
                  style: const TextStyle(
                    color: Color(0xFFB91C1C),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('income_wizard_cancel_button'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        FilledButton.icon(
          key: const Key('income_wizard_save_button'),
          onPressed: _submit,
          icon: const Icon(Icons.check_circle_outline, size: 18),
          label: const Text('入金予定を登録'),
        ),
      ],
    );
  }
}

/// 原資未設定ガイドモーダルの口座候補 (#4059 Delta 5)。
class MissingPaymentSourceGuideOption {
  final String accountId;
  final String accountName;
  final double currentBalance;
  final double projectedAfterPayment;
  final bool recommended;

  const MissingPaymentSourceGuideOption({
    required this.accountId,
    required this.accountName,
    required this.currentBalance,
    required this.projectedAfterPayment,
    required this.recommended,
  });
}

/// 支払原資の重要性と最適口座の1タップ設定を案内するダイアログ (#4059 Delta 5)。
class MissingPaymentSourceGuideDialog extends StatelessWidget {
  final String accountName;
  final int? paymentDay;
  final double scheduledAmount;
  final List<MissingPaymentSourceGuideOption> options;

  const MissingPaymentSourceGuideDialog({
    super.key,
    required this.accountName,
    required this.paymentDay,
    required this.scheduledAmount,
    required this.options,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('$accountName の支払原資設定ガイド'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '支払日 ${paymentDay ?? '-'}日 / 予定 ${_formatDialogYen(scheduledAmount)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '引き落とし口座が未設定だと口座別資金繰りや事前振替提案の対象から漏れます。'
                '下の候補から引き落としに使っている銀行口座を選択してください。',
                style: TextStyle(fontSize: 12, height: 1.5),
              ),
              const SizedBox(height: 12),
              if (options.isEmpty)
                const Text(
                  '選択可能な資産口座が見つかりません。先に現金・銀行口座の残高を登録してください。',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFFB45309),
                  ),
                )
              else
                for (final option in options)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        option.accountName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    if (option.recommended) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFECFDF5),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          '余裕あり',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF047857),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '現在 ${_formatDialogYen(option.currentBalance)} / '
                                  '支払後見込み ${_formatDialogYen(option.projectedAfterPayment)}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            key: Key(
                              'missing_source_guide_apply_${option.accountId}',
                            ),
                            onPressed: () =>
                                Navigator.of(context).pop(option.accountId),
                            child: const Text('この口座に設定'),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('missing_source_guide_close_button'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('閉じる'),
        ),
      ],
    );
  }
}
