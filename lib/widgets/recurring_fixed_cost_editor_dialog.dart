import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/asset_liability_workbook.dart';
import 'recurring_fixed_cost_card.dart';

/// 振替元ドロップダウンに渡す口座 (ID + 表示名)。
typedef RecurringFixedCostSourceOption = ({String id, String name});

/// 振替元/請求先に選べる口座を組み立てる。
///
/// 既定は資産口座 (残高>0) のみ。サブスク等カードへ請求される費用では
/// [includeCards] = true で**残高の符号によらず**クレジット/プリペイドカードや
/// ショッピング枠 (例: ファミペイ バーチャルカード / アコムショッピング枠) も含める。
/// これらは後払い/残高<=0 だと `balance > 0` だけのフィルタでは選べないため、請求先
/// (リボ/分割で買い物に使う与信枠) として拾えるようにする。
/// [includeCarrierBilling] = true で auかんたん決済 (au通信料金合算) 等のキャリア決済
/// 口座 (au / KDDI) も含める。これらは負債(請求)口座で残高<=0 のため通常は出ない。
List<RecurringFixedCostSourceOption> recurringFixedCostSourceOptions(
  Iterable<AssetLiabilityAccount> accounts, {
  bool includeCards = false,
  bool includeCarrierBilling = false,
}) {
  return <RecurringFixedCostSourceOption>[
    for (final account in accounts)
      if (account.balance > 0 ||
          (includeCards && _isChargeableCardAccount(account)) ||
          (includeCarrierBilling && _isCarrierBillingAccount(account)))
        (id: account.id, name: account.name),
  ];
}

/// 買い物に使える与信枠の口座か (請求先候補)。クレジット/プリペイドカードに加え、
/// アコムショッピング枠などのショッピング枠 (shoppingDebt) も含める。消費者ローン
/// (cardLoan = 現金借入) や公共料金 (utility) は買い物の請求先ではないため除外。
bool _isChargeableCardAccount(AssetLiabilityAccount account) {
  return account.kind == AssetLiabilityAccountKind.creditCard ||
      account.kind == AssetLiabilityAccountKind.shoppingDebt;
}

/// auかんたん決済 (au通信料金合算) / KDDI などキャリア決済の口座か。残高の符号に依らず
/// サブスクの振替元候補に含めるための判定。id は planning service の
/// `auAccountId`('au') / `kddiProviderAccountId`('kddi_provider') と一致させる。
bool _isCarrierBillingAccount(AssetLiabilityAccount account) {
  final name = account.name.toLowerCase().replaceAll(RegExp(r'\s+'), '');
  return name == 'au' ||
      account.id == 'au' ||
      name.contains('kddi') ||
      account.id == 'kddi_provider';
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
  double? usdJpyRate,
  DateTime? usdJpyRateAsOf,
}) {
  return showDialog<AssetRecurringFixedCost>(
    context: context,
    builder: (context) => RecurringFixedCostEditorDialog(
      existing: existing,
      prefill: prefill,
      sourceAccounts: sourceAccounts,
      category: category,
      gateway: gateway,
      usdJpyRate: usdJpyRate,
      usdJpyRateAsOf: usdJpyRateAsOf,
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
    this.usdJpyRate,
    this.usdJpyRateAsOf,
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

  /// 最新の USD/JPY レート (1 ドル = ◯円)。ドル建て入力の円換算プレビューと
  /// 保存時の円額 materialize に使う。null のときはレート未取得。
  final double? usdJpyRate;

  /// [usdJpyRate] の基準日 (表示用)。
  final DateTime? usdJpyRateAsOf;

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
  late AssetRecurringFixedCostCurrency _currency;
  String? _sourceAccountId;

  @override
  void initState() {
    super.initState();
    // existing(編集)優先。なければ prefill(検出結果からの追加)を初期値に使う。
    final initial = widget.existing ?? widget.prefill;
    // 区分は initial が持つ値を最優先し、無ければ呼び出し側が指定した既定を使う。
    _category = initial?.category ?? widget.category;
    _gateway = initial?.billingGateway ?? widget.gateway;
    _currency = initial?.currency ?? AssetRecurringFixedCostCurrency.jpy;
    _nameController = TextEditingController(text: initial?.name ?? '');
    // ドル建てなら金額欄には USD の原資額を、円建てなら円額を初期表示する。
    _amountController = TextEditingController(
      text: initial == null
          ? ''
          : (initial.isUsd && initial.usdAmount != null
              ? _trimAmount(initial.usdAmount!)
              : initial.amount.toStringAsFixed(0)),
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

  bool get _isUsd => _currency == AssetRecurringFixedCostCurrency.usd;

  /// USD 額は小数点以下を許容するため、整数なら小数を省いて表示する。
  static String _trimAmount(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toString();
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
    final entered = double.parse(_amountController.text.trim());
    final double amountJpy;
    final double? usdAmount;
    if (_isUsd) {
      usdAmount = entered;
      // レートがあれば円へ materialize。無ければ既存の円額 (編集時) か 0 を暫定値に
      // 置き、ロード時のレート反映で自動的に正しい円額へ更新される。
      final rate = widget.usdJpyRate;
      amountJpy = (rate != null && rate > 0)
          ? (entered * rate).roundToDouble()
          : (widget.existing?.amount ?? 0);
    } else {
      usdAmount = null;
      amountJpy = entered;
    }
    final cost = AssetRecurringFixedCost(
      id: id,
      name: _nameController.text.trim(),
      amount: amountJpy,
      paymentDay: int.parse(_dayController.text.trim()),
      cadence: _cadence,
      sourceAccountId: _sourceAccountId,
      category: _category,
      subscriptionReviewDecision:
          _category == AssetRecurringFixedCostCategory.subscription
              ? (widget.existing?.subscriptionReviewDecision ??
                  widget.prefill?.subscriptionReviewDecision ??
                  AssetSubscriptionReviewDecision.unreviewed)
              : AssetSubscriptionReviewDecision.unreviewed,
      // 請求経路は区分=サブスクのときだけ意味を持つ。固定費では direct に固定する。
      billingGateway: _category == AssetRecurringFixedCostCategory.subscription
          ? _gateway
          : AssetSubscriptionBillingGateway.direct,
      currency: _currency,
      usdAmount: usdAmount,
    );
    Navigator.of(context).pop(cost);
  }

  String _formatYen(double value) {
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

  /// ドル建て入力欄の下に「≈ ¥X (1ドル=¥Y, MM/DD時点)」の換算プレビューを出す。
  /// レート未取得時は取得中/据え置きの案内にする。
  Widget _buildUsdConversionHint() {
    final rate = widget.usdJpyRate;
    final usd = double.tryParse(_amountController.text.trim());
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
      color: const Color(0xFF0D9488),
      fontWeight: FontWeight.w700,
    );
    final Widget child;
    if (rate == null || rate <= 0) {
      child = Text(
        '為替レート取得中… 保存後、最新レートで自動換算します。',
        style: theme.textTheme.bodySmall?.copyWith(
          color: const Color(0xFF64748B),
        ),
      );
    } else if (usd == null || usd <= 0) {
      child = Text(
        '1ドル=${_formatYen(rate)}${_rateAsOfSuffix()} で円換算します。',
        style: style,
      );
    } else {
      child = Text(
        '≈ ${_formatYen(usd * rate)}'
        '(1ドル=${_formatYen(rate)}${_rateAsOfSuffix()})',
        style: style,
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Align(alignment: Alignment.centerLeft, child: child),
    );
  }

  String _rateAsOfSuffix() {
    final asOf = widget.usdJpyRateAsOf;
    if (asOf == null) {
      return '';
    }
    final local = asOf.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    return ' / $mm/$dd時点';
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
              const SizedBox(height: 8),
              // 通貨トグル。ドル建て (Claude/Notion 等) は毎月の為替で円額が
              // 変わるため、USD 原資を保持し最新レートで円換算する。
              SegmentedButton<AssetRecurringFixedCostCurrency>(
                segments: const [
                  ButtonSegment(
                    value: AssetRecurringFixedCostCurrency.jpy,
                    label: Text('円'),
                    icon: Icon(Icons.currency_yen, size: 16),
                  ),
                  ButtonSegment(
                    value: AssetRecurringFixedCostCurrency.usd,
                    label: Text('USD'),
                    icon: Icon(Icons.attach_money, size: 16),
                  ),
                ],
                selected: {_currency},
                onSelectionChanged: (selection) {
                  setState(() => _currency = selection.first);
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: _isUsd ? '月額 (USD)' : '月額 (円)',
                  hintText: _isUsd ? '例: 20' : '例: 8000',
                  prefixText: _isUsd ? r'$ ' : null,
                ),
                keyboardType: TextInputType.numberWithOptions(
                  decimal: _isUsd,
                ),
                inputFormatters: _isUsd
                    ? [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9.]'),
                        ),
                      ]
                    : [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  final amount = double.tryParse((value ?? '').trim());
                  if (amount == null || amount <= 0) {
                    return _isUsd ? '0より大きい金額を入力してください' : '1円以上の金額を入力してください';
                  }
                  return null;
                },
              ),
              if (_isUsd) _buildUsdConversionHint(),
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
