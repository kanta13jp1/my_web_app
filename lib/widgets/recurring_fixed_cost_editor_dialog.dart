import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/asset_liability_workbook.dart';
import 'recurring_fixed_cost_card.dart';

/// 振替元ドロップダウンに渡す口座 (ID + 表示名)。
typedef RecurringFixedCostSourceOption = ({String id, String name});

/// 振替元/請求先に選べる口座を組み立てる。
///
/// 既定は資産口座 (残高>0) のみ。サブスク等カードへ請求される費用では
/// [includeCards] = true で**残高の符号によらず**クレジット/プリペイドカード
/// (例: ファミペイ バーチャルカード) も含める。FamiPay は後払い/残高0だと
/// `balance > 0` だけのフィルタでは選べないため、請求先カードとして拾えるようにする。
List<RecurringFixedCostSourceOption> recurringFixedCostSourceOptions(
  Iterable<AssetLiabilityAccount> accounts, {
  bool includeCards = false,
}) {
  return <RecurringFixedCostSourceOption>[
    for (final account in accounts)
      if (account.balance > 0 ||
          (includeCards &&
              account.kind == AssetLiabilityAccountKind.creditCard))
        (id: account.id, name: account.name),
  ];
}

/// 定期固定費の追加/編集ダイアログを開き、保存された [AssetRecurringFixedCost] を返す。
/// キャンセル時は null。
///
/// [prefill] を渡すと(かつ [existing] が null のとき)、各フィールドを prefill 値で
/// 初期化した「追加」モードで開く(定期取引の自動検出からの登録用)。保存時は
/// 新しい id を採番するため、prefill の id は使われない。
Future<AssetRecurringFixedCost?> showRecurringFixedCostEditor(
  BuildContext context, {
  AssetRecurringFixedCost? existing,
  AssetRecurringFixedCost? prefill,
  List<RecurringFixedCostSourceOption> sourceAccounts =
      const <RecurringFixedCostSourceOption>[],
  AssetRecurringFixedCostCategory category =
      AssetRecurringFixedCostCategory.utility,
  AssetSubscriptionBillingGateway gateway =
      AssetSubscriptionBillingGateway.direct,
}) {
  return showDialog<AssetRecurringFixedCost>(
    context: context,
    builder: (context) => RecurringFixedCostEditorDialog(
      existing: existing,
      prefill: prefill,
      sourceAccounts: sourceAccounts,
      category: category,
      gateway: gateway,
    ),
  );
}

/// 定期固定費の入力フォーム。`showRecurringFixedCostEditor` 経由で使う想定だが、
/// 単体テストのため公開している。
class RecurringFixedCostEditorDialog extends StatefulWidget {
  const RecurringFixedCostEditorDialog({
    super.key,
    this.existing,
    this.prefill,
    this.sourceAccounts = const <RecurringFixedCostSourceOption>[],
    this.category = AssetRecurringFixedCostCategory.utility,
    this.gateway = AssetSubscriptionBillingGateway.direct,
  });

  final AssetRecurringFixedCost? existing;

  /// 追加モードの初期値(検出結果からの登録用)。[existing] があれば無視される。
  final AssetRecurringFixedCost? prefill;
  final List<RecurringFixedCostSourceOption> sourceAccounts;

  /// 区分の初期値 (固定費 / サブスク)。[existing]/[prefill] が区分を持つ場合は
  /// そちらを優先する (サブスクカードから「その他を追加」する際の既定値)。
  final AssetRecurringFixedCostCategory category;

  /// 請求経路の初期値。棚卸しの Apple/au/Google 行から登録する際に既定を与える。
  /// [existing]/[prefill] が経路を持つ場合はそちらを優先する。
  final AssetSubscriptionBillingGateway gateway;

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
  late AssetRecurringFixedCostCategory _category;
  late AssetSubscriptionBillingGateway _gateway;
  String? _sourceAccountId;

  @override
  void initState() {
    super.initState();
    // existing(編集)優先。なければ prefill(検出結果からの追加)を初期値に使う。
    final initial = widget.existing ?? widget.prefill;
    // 区分は initial が持つ値を最優先し、無ければ呼び出し側が指定した既定を使う。
    _category = initial?.category ?? widget.category;
    _gateway = initial?.billingGateway ?? widget.gateway;
    _nameController = TextEditingController(text: initial?.name ?? '');
    _amountController = TextEditingController(
      text: initial == null ? '' : initial.amount.toStringAsFixed(0),
    );
    _dayController = TextEditingController(
      text: initial == null ? '' : initial.paymentDay.toString(),
    );
    _cadence = initial?.cadence ?? AssetRecurringFixedCostCadence.monthly;
    // 渡された候補に無い振替元IDは保持しない (古い参照を残さない)。
    final ids = widget.sourceAccounts.map((option) => option.id).toSet();
    final source = initial?.sourceAccountId;
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
      category: _category,
      // 請求経路は区分=サブスクのときだけ意味を持つ。固定費では direct に固定する。
      billingGateway: _category == AssetRecurringFixedCostCategory.subscription
          ? _gateway
          : AssetSubscriptionBillingGateway.direct,
    );
    Navigator.of(context).pop(cost);
  }

  static String categoryLabel(AssetRecurringFixedCostCategory category) {
    switch (category) {
      case AssetRecurringFixedCostCategory.utility:
        return '定期固定費';
      case AssetRecurringFixedCostCategory.subscription:
        return 'サブスク';
    }
  }

  static String gatewayLabel(AssetSubscriptionBillingGateway gateway) {
    switch (gateway) {
      case AssetSubscriptionBillingGateway.direct:
        return '直接 (口座/カード)';
      case AssetSubscriptionBillingGateway.apple:
        return 'Apple (App Store)';
      case AssetSubscriptionBillingGateway.googlePlay:
        return 'Google Play';
      case AssetSubscriptionBillingGateway.auKantan:
        return 'auかんたん決済';
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = categoryLabel(_category);
    return AlertDialog(
      title: Text(widget.existing == null ? '$labelを追加' : '$labelを編集'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<AssetRecurringFixedCostCategory>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: '区分'),
                items: [
                  for (final category in AssetRecurringFixedCostCategory.values)
                    DropdownMenuItem<AssetRecurringFixedCostCategory>(
                      value: category,
                      child: Text(categoryLabel(category)),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _category = value);
                  }
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: '名称',
                  hintText:
                      _category == AssetRecurringFixedCostCategory.subscription
                          ? '例: Anthropic (Claude)'
                          : '例: 電気代',
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
              if (_category ==
                  AssetRecurringFixedCostCategory.subscription) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<AssetSubscriptionBillingGateway>(
                  initialValue: _gateway,
                  decoration: const InputDecoration(
                    labelText: '請求経路',
                    helperText: 'Apple/Google/au 経由は明細に集約名義で出ます',
                  ),
                  items: [
                    for (final gateway
                        in AssetSubscriptionBillingGateway.values)
                      DropdownMenuItem<AssetSubscriptionBillingGateway>(
                        value: gateway,
                        child: Text(gatewayLabel(gateway)),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _gateway = value);
                    }
                  },
                ),
              ],
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                initialValue: _sourceAccountId,
                decoration: const InputDecoration(labelText: '振替元 (任意)'),
                items: [
                  const DropdownMenuItem<String?>(child: Text('未設定')),
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
        FilledButton(onPressed: _submit, child: const Text('保存')),
      ],
    );
  }
}
