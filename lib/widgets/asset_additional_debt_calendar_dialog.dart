import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// 追加の借金としてカレンダーへ記録する種別。
enum AssetAdditionalDebtRecordKind {
  cashing,
  revolvingUsage,
}

/// 記録ダイアログの口座・カード選択肢。
class AssetAdditionalDebtAccountOption {
  const AssetAdditionalDebtAccountOption({
    required this.id,
    required this.name,
    this.isRevolvingCard = false,
  });

  final String id;
  final String name;
  final bool isRevolvingCard;
}

/// ダイアログ確定時の入力内容。
class AssetAdditionalDebtCalendarDraft {
  const AssetAdditionalDebtCalendarDraft({
    required this.kind,
    required this.date,
    required this.accountId,
    required this.accountName,
    required this.amount,
    required this.memo,
    required this.recordDebtGuardViolation,
  });

  final AssetAdditionalDebtRecordKind kind;
  final DateTime date;
  final String accountId;
  final String accountName;
  final int amount;
  final String memo;
  final bool recordDebtGuardViolation;
}

/// キャッシング・追加借入またはリボ払い利用を発生日付きでカレンダーへ登録するダイアログ。
class AssetAdditionalDebtCalendarDialog extends StatefulWidget {
  const AssetAdditionalDebtCalendarDialog({
    super.key,
    this.initialKind = AssetAdditionalDebtRecordKind.cashing,
    required this.initialDate,
    this.initialAmount,
    this.initialAccountId,
    this.initialAccountName,
    this.accountOptions = const <AssetAdditionalDebtAccountOption>[],
    this.helperNotice,
  });

  final AssetAdditionalDebtRecordKind initialKind;
  final DateTime initialDate;
  final double? initialAmount;
  final String? initialAccountId;
  final String? initialAccountName;
  final List<AssetAdditionalDebtAccountOption> accountOptions;
  final String? helperNotice;

  @override
  State<AssetAdditionalDebtCalendarDialog> createState() =>
      _AssetAdditionalDebtCalendarDialogState();
}

class _AssetAdditionalDebtCalendarDialogState
    extends State<AssetAdditionalDebtCalendarDialog> {
  static const String _customAccountId = '__custom_account__';

  late AssetAdditionalDebtRecordKind _kind;
  late DateTime _selectedDate;
  late String _selectedAccountId;
  late final TextEditingController _customAccountController;
  late final TextEditingController _amountController;
  late final TextEditingController _memoController;
  bool _recordDebtGuardViolation = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _kind = widget.initialKind;
    _selectedDate = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
    );
    final initialAmount = widget.initialAmount;
    _amountController = TextEditingController(
      text: initialAmount != null && initialAmount >= 1
          ? initialAmount.round().toString()
          : '',
    );
    _memoController = TextEditingController();
    _customAccountController = TextEditingController(
      text: widget.initialAccountName?.trim() ?? '',
    );
    _selectedAccountId = _resolveInitialAccountId(_kind);
  }

  @override
  void dispose() {
    _customAccountController.dispose();
    _amountController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  List<AssetAdditionalDebtAccountOption> _effectiveOptions(
    AssetAdditionalDebtRecordKind kind,
  ) {
    final base = <AssetAdditionalDebtAccountOption>[...widget.accountOptions];
    final initialId = widget.initialAccountId?.trim();
    final initialName = widget.initialAccountName?.trim();
    if (initialId != null &&
        initialId.isNotEmpty &&
        initialName != null &&
        initialName.isNotEmpty &&
        !base.any((opt) => opt.id == initialId)) {
      base.insert(
        0,
        AssetAdditionalDebtAccountOption(
          id: initialId,
          name: initialName,
          isRevolvingCard: kind == AssetAdditionalDebtRecordKind.revolvingUsage,
        ),
      );
    }
    base.sort((a, b) {
      final aMatches = kind == AssetAdditionalDebtRecordKind.revolvingUsage
          ? a.isRevolvingCard
          : !a.isRevolvingCard;
      final bMatches = kind == AssetAdditionalDebtRecordKind.revolvingUsage
          ? b.isRevolvingCard
          : !b.isRevolvingCard;
      if (aMatches == bMatches) return 0;
      return aMatches ? -1 : 1;
    });
    return base;
  }

  String _resolveInitialAccountId(AssetAdditionalDebtRecordKind kind) {
    final options = _effectiveOptions(kind);
    final initialId = widget.initialAccountId?.trim();
    if (initialId != null &&
        initialId.isNotEmpty &&
        options.any((opt) => opt.id == initialId)) {
      return initialId;
    }
    if (options.isNotEmpty) {
      return options.first.id;
    }
    return _customAccountId;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final lastDate = DateTime(now.year + 1, now.month, now.day);
    final safeInitial = _selectedDate.isAfter(lastDate)
        ? lastDate
        : (_selectedDate.isBefore(DateTime(2020))
            ? DateTime(2020)
            : _selectedDate);
    final picked = await showDatePicker(
      context: context,
      initialDate: safeInitial,
      firstDate: DateTime(2020),
      lastDate: lastDate,
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _selectedDate = DateTime(picked.year, picked.month, picked.day);
    });
  }

  void _submit() {
    final sanitized = _amountController.text
        .replaceAll(',', '')
        .replaceAll('，', '')
        .replaceAll('¥', '')
        .replaceAll('￥', '')
        .replaceAll('円', '')
        .trim();
    final parsedAmount = int.tryParse(sanitized);
    if (parsedAmount == null || parsedAmount < 1) {
      setState(() {
        _errorMessage = '1円以上の金額を入力してください';
      });
      return;
    }

    final options = _effectiveOptions(_kind);
    final String accountId;
    final String accountName;
    if (_selectedAccountId == _customAccountId) {
      final customName = _customAccountController.text.trim();
      accountName = customName.isNotEmpty
          ? customName
          : (_kind == AssetAdditionalDebtRecordKind.cashing
              ? 'キャッシング・借入'
              : 'リボ払いカード');
      accountId = widget.initialAccountId?.trim().isNotEmpty == true
          ? widget.initialAccountId!.trim()
          : 'manual_${_kind.name}';
    } else {
      final matched = options.firstWhere(
        (opt) => opt.id == _selectedAccountId,
        orElse: () => options.first,
      );
      accountId = matched.id;
      accountName = matched.name;
    }

    final rawMemo = _memoController.text.trim();
    final memo = rawMemo.isNotEmpty
        ? rawMemo
        : (_kind == AssetAdditionalDebtRecordKind.cashing
            ? 'キャッシング・追加借入'
            : 'リボ払い利用');

    Navigator.of(context).pop(
      AssetAdditionalDebtCalendarDraft(
        kind: _kind,
        date: _selectedDate,
        accountId: accountId,
        accountName: accountName,
        amount: parsedAmount,
        memo: memo,
        recordDebtGuardViolation: _recordDebtGuardViolation,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final options = _effectiveOptions(_kind);
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      key: const Key('asset_additional_debt_calendar_dialog'),
      title: const Text('借入・リボ利用をカレンダーに記録'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.helperNotice != null &&
                  widget.helperNotice!.trim().isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFCD34D)),
                  ),
                  child: Text(
                    widget.helperNotice!.trim(),
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: Color(0xFF78350F),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              DropdownButtonFormField<AssetAdditionalDebtRecordKind>(
                key: const Key('asset_additional_debt_kind_field'),
                initialValue: _kind,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: '記録種別',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem<AssetAdditionalDebtRecordKind>(
                    value: AssetAdditionalDebtRecordKind.cashing,
                    child: Text('キャッシング・追加借入（収入集計外）'),
                  ),
                  DropdownMenuItem<AssetAdditionalDebtRecordKind>(
                    value: AssetAdditionalDebtRecordKind.revolvingUsage,
                    child: Text('リボ払い利用（現金引落なし）'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _kind = value;
                    _selectedAccountId = _resolveInitialAccountId(value);
                    _errorMessage = null;
                  });
                },
              ),
              const SizedBox(height: 12),
              Semantics(
                button: true,
                label: '発生日を選択',
                child: InkWell(
                  key: const Key('asset_additional_debt_date_button'),
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(6),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: '発生日（借入日・利用日）',
                        border: OutlineInputBorder(),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('yyyy年M月d日').format(_selectedDate),
                            style: const TextStyle(fontSize: 14),
                          ),
                          Icon(
                            Icons.calendar_today,
                            size: 18,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey<String>(
                  'asset_additional_debt_account_${_kind.name}_$_selectedAccountId',
                ),
                initialValue: _selectedAccountId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: '対象口座・カード',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final option in options)
                    DropdownMenuItem<String>(
                      value: option.id,
                      child: Text(
                        option.isRevolvingCard
                            ? '${option.name}（リボ対象）'
                            : option.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  const DropdownMenuItem<String>(
                    value: _customAccountId,
                    child: Text('その他（手入力）'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedAccountId = value;
                  });
                },
              ),
              if (_selectedAccountId == _customAccountId) ...[
                const SizedBox(height: 12),
                TextField(
                  key: const Key('asset_additional_debt_custom_account_field'),
                  controller: _customAccountController,
                  decoration: const InputDecoration(
                    labelText: '口座・カード名',
                    hintText: '例: モビット / ファミマカード',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                key: const Key('asset_additional_debt_amount_field'),
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: '金額（円）',
                  suffixText: '円',
                  border: const OutlineInputBorder(),
                  error: _errorMessage == null
                      ? null
                      : Text(
                          _errorMessage!,
                          key: const Key('asset_additional_debt_error_text'),
                        ),
                ),
                onChanged: (_) {
                  if (_errorMessage != null) {
                    setState(() {
                      _errorMessage = null;
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('asset_additional_debt_memo_field'),
                controller: _memoController,
                decoration: const InputDecoration(
                  labelText: '利用内容・メモ（任意）',
                  hintText: '例: ATMキャッシング / コンビニ利用',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                key: const Key('asset_additional_debt_guard_checkbox'),
                value: _recordDebtGuardViolation,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(
                  '禁止ルール（Debt Guard: 追加の借金）にも違反記録を残す',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  '追記専用ログに発生日で記録され、カレンダーにも違反表示されます',
                  style: TextStyle(fontSize: 11),
                ),
                onChanged: (checked) {
                  setState(() {
                    _recordDebtGuardViolation = checked ?? false;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            minimumSize: const Size(64, 48),
          ),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          key: const Key('asset_additional_debt_submit_button'),
          onPressed: _submit,
          style: FilledButton.styleFrom(
            minimumSize: const Size(64, 48),
          ),
          child: const Text('カレンダーに記録'),
        ),
      ],
    );
  }
}
