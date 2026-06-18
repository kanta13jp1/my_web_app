import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/asset_liability_workbook.dart';
import 'recurring_fixed_cost_card.dart';

/// 振替元ドロップダウンに渡す口座 (ID + 表示名)。
typedef RecurringFixedCostSourceOption = ({String id, String name});

/// 定期固定費の追加/編集ダイアログを開き、保存された [AssetRecurringFixedCost] を返す。
/// キャンセル時は null。
Future<AssetRecurringFixedCost?> showRecurringFixedCostEditor(
  BuildContext context, {
  AssetRecurringFixedCost? existing,
  List<RecurringFixedCostSourceOption> sourceAccounts =
      const <RecurringFixedCostSourceOption>[],
}) {
  return showDialog<AssetRecurringFixedCost>(
    context: context,
    builder: (context) => RecurringFixedCostEditorDialog(
      existing: existing,
      sourceAccounts: sourceAccounts,
    ),
  );
}

/// 定期固定費の入力フォーム。`showRecurringFixedCostEditor` 経由で使う想定だが、
/// 単体テストのため公開している。
class RecurringFixedCostEditorDialog extends StatefulWidget {
  const RecurringFixedCostEditorDialog({
    super.key,
    this.existing,
    this.sourceAccounts = const <RecurringFixedCostSourceOption>[],
  });

  final AssetRecurringFixedCost? existing;
  final List<RecurringFixedCostSourceOption> sourceAccounts;

  @override
  State<RecurringFixedCostEditorDialog> createState() =>
      _RecurringFixedCostEditorDialogState();
}

class _RecurringFixedCostEditorDialogState
    extends State<RecurringFixedCostEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late final TextEditingController _dayController;
  late AssetRecurringFixedCostCadence _cadence;
  String? _sourceAccountId;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _amountController = TextEditingController(
      text: existing == null ? '' : existing.amount.toStringAsFixed(0),
    );
    _dayController = TextEditingController(
      text: existing == null ? '' : existing.paymentDay.toString(),
    );
    _cadence = existing?.cadence ?? AssetRecurringFixedCostCadence.monthly;
    // 渡された候補に無い振替元IDは保持しない (古い参照を残さない)。
    final ids = widget.sourceAccounts.map((option) => option.id).toSet();
    final source = existing?.sourceAccountId;
    _sourceAccountId = source != null && ids.contains(source) ? source : null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _dayController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final id =
        widget.existing?.id ?? 'fc_${DateTime.now().microsecondsSinceEpoch}';
    final cost = AssetRecurringFixedCost(
      id: id,
      name: _nameController.text.trim(),
      amount: double.parse(_amountController.text.trim()),
      paymentDay: int.parse(_dayController.text.trim()),
      cadence: _cadence,
      sourceAccountId: _sourceAccountId,
    );
    Navigator.of(context).pop(cost);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? '定期固定費を追加' : '定期固定費を編集'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '名称',
                  hintText: '例: 電気代',
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? '名称を入力してください'
                    : null,
              ),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: '月額 (円)',
                  hintText: '例: 8000',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  final amount = double.tryParse((value ?? '').trim());
                  if (amount == null || amount <= 0) {
                    return '1円以上の金額を入力してください';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _dayController,
                decoration: const InputDecoration(
                  labelText: '振替日 (1〜31)',
                  hintText: '例: 27',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  final day = int.tryParse((value ?? '').trim());
                  if (day == null || day < 1 || day > 31) {
                    return '1〜31 の日付を入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<AssetRecurringFixedCostCadence>(
                initialValue: _cadence,
                decoration: const InputDecoration(labelText: '周期'),
                items: [
                  for (final cadence in AssetRecurringFixedCostCadence.values)
                    DropdownMenuItem<AssetRecurringFixedCostCadence>(
                      value: cadence,
                      child: Text(RecurringFixedCostCard.cadenceLabel(cadence)),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _cadence = value);
                  }
                },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                initialValue: _sourceAccountId,
                decoration: const InputDecoration(labelText: '振替元 (任意)'),
                items: [
                  const DropdownMenuItem<String?>(
                    child: Text('未設定'),
                  ),
                  for (final option in widget.sourceAccounts)
                    DropdownMenuItem<String?>(
                      value: option.id,
                      child: Text(option.name),
                    ),
                ],
                onChanged: (value) => setState(() => _sourceAccountId = value),
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
          onPressed: _submit,
          child: const Text('保存'),
        ),
      ],
    );
  }
}
