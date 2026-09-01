enum AssetLiabilityAccountKind {
  cash,
  deposit,
  securities,
  cardLoan,
  shoppingDebt,
  creditCard,
  utility,
  otherAsset,
  otherLiability,
}

enum AssetLiabilityPaymentMethod { direct, includedInCard }

enum AssetLiabilityPaymentMethodSettingSource {
  builtInDefault,
  defaultSetting,
  monthlyOverride,
}

enum AssetLiabilityAnnualRateEvidenceStatus {
  verified,
  rejected,
  needsReview,
  failed,
}

class AssetLiabilityAnnualRateEvidence {
  final String accountId;
  final String fileName;
  final String mimeType;
  final DateTime submittedAt;
  final double submittedAnnualRate;
  final double? detectedAnnualRate;
  final AssetLiabilityAnnualRateEvidenceStatus status;
  final String summary;
  final String source;
  final String? errorMessage;

  const AssetLiabilityAnnualRateEvidence({
    required this.accountId,
    required this.fileName,
    required this.mimeType,
    required this.submittedAt,
    required this.submittedAnnualRate,
    required this.detectedAnnualRate,
    required this.status,
    required this.summary,
    required this.source,
    this.errorMessage,
  });

  bool get verified =>
      status == AssetLiabilityAnnualRateEvidenceStatus.verified;

  bool matchesAnnualRate(double annualRate) {
    return verified && (submittedAnnualRate - annualRate).abs() < 0.0001;
  }

  AssetLiabilityAnnualRateEvidence copyWith({
    String? accountId,
    String? fileName,
    String? mimeType,
    DateTime? submittedAt,
    double? submittedAnnualRate,
    double? detectedAnnualRate,
    AssetLiabilityAnnualRateEvidenceStatus? status,
    String? summary,
    String? source,
    String? errorMessage,
  }) {
    return AssetLiabilityAnnualRateEvidence(
      accountId: accountId ?? this.accountId,
      fileName: fileName ?? this.fileName,
      mimeType: mimeType ?? this.mimeType,
      submittedAt: submittedAt ?? this.submittedAt,
      submittedAnnualRate: submittedAnnualRate ?? this.submittedAnnualRate,
      detectedAnnualRate: detectedAnnualRate ?? this.detectedAnnualRate,
      status: status ?? this.status,
      summary: summary ?? this.summary,
      source: source ?? this.source,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'accountId': accountId,
      'fileName': fileName,
      'mimeType': mimeType,
      'submittedAt': submittedAt.toUtc().toIso8601String(),
      'submittedAnnualRate': submittedAnnualRate,
      'detectedAnnualRate': detectedAnnualRate,
      'status': status.name,
      'summary': summary,
      'source': source,
      'errorMessage': errorMessage,
    };
  }

  static AssetLiabilityAnnualRateEvidence? fromJson(Map<String, Object?> json) {
    final accountId =
        json['accountId']?.toString().trim() ??
        json['account_id']?.toString().trim();
    final fileName =
        json['fileName']?.toString().trim() ??
        json['file_name']?.toString().trim();
    final mimeType =
        json['mimeType']?.toString().trim() ??
        json['mime_type']?.toString().trim();
    final submittedAtText =
        json['submittedAt']?.toString() ?? json['submitted_at']?.toString();
    final submittedAt = submittedAtText == null
        ? null
        : DateTime.tryParse(submittedAtText);
    final submittedAnnualRate =
        _parseEvidenceDouble(
          json['submittedAnnualRate'] ?? json['submitted_annual_rate'],
        ) ??
        -1;
    final detectedAnnualRate = _parseEvidenceDouble(
      json['detectedAnnualRate'] ?? json['detected_annual_rate'],
    );
    final rawStatus = json['status']?.toString().trim();
    AssetLiabilityAnnualRateEvidenceStatus? status;
    for (final value in AssetLiabilityAnnualRateEvidenceStatus.values) {
      if (value.name == rawStatus) {
        status = value;
        break;
      }
    }
    if (accountId == null ||
        accountId.isEmpty ||
        fileName == null ||
        fileName.isEmpty ||
        mimeType == null ||
        mimeType.isEmpty ||
        submittedAt == null ||
        submittedAnnualRate < 0 ||
        status == null) {
      return null;
    }
    final rawError =
        json['errorMessage']?.toString() ?? json['error_message']?.toString();
    final error = rawError == null || rawError.trim().isEmpty
        ? null
        : rawError.trim();
    return AssetLiabilityAnnualRateEvidence(
      accountId: accountId,
      fileName: fileName,
      mimeType: mimeType,
      submittedAt: submittedAt,
      submittedAnnualRate: submittedAnnualRate,
      detectedAnnualRate: detectedAnnualRate,
      status: status,
      summary: json['summary']?.toString().trim() ?? '',
      source: json['source']?.toString().trim() ?? '',
      errorMessage: error,
    );
  }
}

double? _parseEvidenceDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value == null) {
    return null;
  }
  return double.tryParse(value.toString().replaceAll(',', '').trim());
}

class AssetLiabilityAccount {
  final String id;
  final String name;
  final AssetLiabilityAccountKind kind;
  final double balance;
  final int? paymentDay;
  final String? paymentSourceAccountName;
  final AssetLiabilityPaymentMethod paymentMethod;
  final String? paymentMethodLabel;
  final AssetLiabilityPaymentMethodSettingSource paymentMethodSettingSource;
  final String? billingAccountId;
  final String? billingAccountName;
  final bool includedInBillingAccount;
  final double annualRate;
  final double minimumPaymentRate;
  final double minimumPaymentFloor;
  final bool fullPaymentEstimate;

  const AssetLiabilityAccount({
    required this.id,
    required this.name,
    required this.kind,
    required this.balance,
    this.paymentDay,
    this.paymentSourceAccountName,
    this.paymentMethod = AssetLiabilityPaymentMethod.direct,
    this.paymentMethodLabel,
    this.paymentMethodSettingSource =
        AssetLiabilityPaymentMethodSettingSource.builtInDefault,
    this.billingAccountId,
    this.billingAccountName,
    this.includedInBillingAccount = false,
    this.annualRate = 0,
    this.minimumPaymentRate = 0,
    this.minimumPaymentFloor = 0,
    this.fullPaymentEstimate = false,
  });

  bool get isAsset => balance > 0;
  bool get isLiability => balance < 0;
  double get liabilityBalance => isLiability ? balance.abs() : 0;

  AssetLiabilityAccount copyWith({int? paymentDay}) {
    return AssetLiabilityAccount(
      id: id,
      name: name,
      kind: kind,
      balance: balance,
      paymentDay: paymentDay ?? this.paymentDay,
      paymentSourceAccountName: paymentSourceAccountName,
      paymentMethod: paymentMethod,
      paymentMethodLabel: paymentMethodLabel,
      paymentMethodSettingSource: paymentMethodSettingSource,
      billingAccountId: billingAccountId,
      billingAccountName: billingAccountName,
      includedInBillingAccount: includedInBillingAccount,
      annualRate: annualRate,
      minimumPaymentRate: minimumPaymentRate,
      minimumPaymentFloor: minimumPaymentFloor,
      fullPaymentEstimate: fullPaymentEstimate,
    );
  }
}

/// リボ払いカードの設定。
///
/// 返済予定額 = [monthlyAmount] + 当月の新規利用額。
/// 既存のリボ残高は一括返済の対象にせず、最低返済額で計画的に圧縮する。
/// 新規利用額だけは同月に全額上乗せし、残高を増やさない運用を表す。
class AssetLiabilityRevolvingCreditConfig {
  /// リボ設定額 (毎月固定で請求される最低額)。
  final double monthlyAmount;

  /// 明細を未取り込みのときに使う当月新規利用額の手入力値。
  final double newUsageAmount;

  /// リボ返済日。給料日に合わせて毎月25日を既定とする。
  final int paymentDay;

  /// 利用限度額。現行の返済額計算では使用せず、与信枠不足の確認だけに使う。
  final double creditLimit;

  const AssetLiabilityRevolvingCreditConfig({
    required this.monthlyAmount,
    this.newUsageAmount = 0,
    this.paymentDay = 25,
    this.creditLimit = 0,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
    'monthlyAmount': monthlyAmount,
    'newUsageAmount': newUsageAmount,
    'paymentDay': paymentDay,
    'creditLimit': creditLimit,
  };

  factory AssetLiabilityRevolvingCreditConfig.fromJson(
    Map<String, dynamic> json,
  ) {
    return AssetLiabilityRevolvingCreditConfig(
      monthlyAmount: (json['monthlyAmount'] as num?)?.toDouble() ?? 0,
      newUsageAmount:
          (json['newUsageAmount'] as num?)?.toDouble() ??
          (json['new_usage_amount'] as num?)?.toDouble() ??
          0,
      paymentDay:
          (json['paymentDay'] as num?)?.toInt() ??
          (json['payment_day'] as num?)?.toInt() ??
          25,
      creditLimit: (json['creditLimit'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// カード会社へ連絡して「今後は一括（1回）払い」に変更した実行記録。
///
/// [enforceOneShot] が true のカードは、残高が残っていても設定変更を促す
/// 助言を繰り返さない。返済額や完済目標の計算自体は止めず、残高圧縮の
/// 月額目標は引き続き提示する。
class AssetCardUsagePolicy {
  /// 今後の利用分を一括（1回）払いにする設定変更が完了しているか。
  final bool enforceOneShot;

  /// 設定変更を完了として記録した日時（UTC 保存を推奨）。
  final DateTime? changedAt;

  /// 受付番号、連絡日、担当窓口などの監査メモ。
  final String memo;

  const AssetCardUsagePolicy({
    required this.enforceOneShot,
    this.changedAt,
    this.memo = '',
  });

  AssetCardUsagePolicy copyWith({
    bool? enforceOneShot,
    DateTime? changedAt,
    String? memo,
  }) {
    return AssetCardUsagePolicy(
      enforceOneShot: enforceOneShot ?? this.enforceOneShot,
      changedAt: changedAt ?? this.changedAt,
      memo: memo ?? this.memo,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'enforce_one_shot': enforceOneShot,
    if (changedAt != null) 'changed_at': changedAt!.toUtc().toIso8601String(),
    if (memo.trim().isNotEmpty) 'memo': memo.trim(),
  };

  factory AssetCardUsagePolicy.fromJson(Map<String, dynamic> json) {
    final changedAtRaw = json['changed_at'] ?? json['changedAt'];
    return AssetCardUsagePolicy(
      enforceOneShot:
          json['enforce_one_shot'] == true || json['enforceOneShot'] == true,
      changedAt: changedAtRaw == null
          ? null
          : DateTime.tryParse(changedAtRaw.toString())?.toUtc(),
      memo: json['memo']?.toString().trim() ?? '',
    );
  }
}

/// 定期固定費の発生周期。
enum AssetRecurringFixedCostCadence {
  /// 毎月。
  monthly,

  /// 隔月 (偶数月のみ / 例: 水道代)。
  bimonthlyEvenMonth,

  /// 隔月 (奇数月のみ)。
  bimonthlyOddMonth,
}

/// 定期固定費の区分。資金繰りへの計上は区分に依らず同じ (全額支払いの utility 負債)
/// だが、UI 上の表示セクションと既定アイコンを切り替えるためだけに使う。
enum AssetRecurringFixedCostCategory {
  /// 家賃・光熱費・通信費など従来の定期固定費 (既定)。
  utility,

  /// AI/クラウド等の月額サブスク (Anthropic / OpenAI / Gemini / GCP / Supabase /
  /// Notion など)。資金繰りでは固定費として同様に計上される。
  subscription,
}

/// サブスク棚卸しでユーザーが付けた判断。
enum AssetSubscriptionReviewDecision { unreviewed, keep, hold, cancelCandidate }

/// 定期固定費の入力通貨。既定は円 (jpy)。ドル建て (usd) の場合は毎月の為替で
/// 円換算額が変動するため、原資の USD 額を保持し、最新レートで円へ materialize する。
enum AssetRecurringFixedCostCurrency {
  /// 円建て (既定)。[AssetRecurringFixedCost.amount] がそのまま月額。
  jpy,

  /// ドル建て。[AssetRecurringFixedCost.usdAmount] が原資で、[amount] は
  /// 最新レートで換算した円額 (レート未取得時は前回換算値を据え置く)。
  usd,
}

/// サブスクの請求経路 (どこ経由で課金されるか)。
///
/// 例: ChatGPT Pro は Apple App Store のサブスクとして課金され、Apple ID の支払い方法
/// (ファミペイ等のカード) に請求される。この場合カード明細には `APPLE.COM/BILL` の
/// 集約名義で出るため、個別サービス名では現れない。請求経路を記録しておくと、棚卸しで
/// 「Apple 経由のサブスク合計」を集約請求と突き合わせて確認できる。
enum AssetSubscriptionBillingGateway {
  /// 経由なし (口座/カードへ直接請求)。既定。
  direct,

  /// Apple App Store (iOS/Mac) のサブスク経由。
  apple,

  /// Google Play 定期購入経由。
  googlePlay,

  /// auかんたん決済 (キャリア決済) 経由。
  auKantan,
}

/// UI から登録できる定期固定費 (家賃・光熱費・通信費など毎月/隔月の口座振替)。
///
/// ハードコードされた既定固定費 (家賃/KDDI/水道/ガス) と同様に、資金繰りへ
/// 「全額支払いの負債 (utility)」として計上される。`buildWorkbook` の
/// `recurringFixedCosts` で渡し、`asset_pref_mirror` で端末間同期する。
/// 保存形は `{id: {name, amount, paymentDay, cadence, sourceAccountId,
/// category?, billingGateway?}}` (既定値 category=utility / billingGateway=direct
/// は後方互換のため出力しない)。
class AssetRecurringFixedCost {
  /// 安定した一意 ID (編集・削除のキー)。
  final String id;

  /// 表示名 (例: 電気代)。
  final String name;

  /// 月額の概算 (今月分は手入力の支払額上書きで変更可)。
  final double amount;

  /// 振替日 (1-31)。
  final int paymentDay;

  /// 発生周期 (毎月 / 隔月偶数月 / 隔月奇数月)。
  final AssetRecurringFixedCostCadence cadence;

  /// 引落の振替元口座 ID (任意)。
  final String? sourceAccountId;

  /// 区分 (固定費 / サブスク)。既定は utility で、表示セクションの振り分けにのみ使う。
  final AssetRecurringFixedCostCategory category;

  /// 棚卸し判定。サブスク以外では常に [AssetSubscriptionReviewDecision.unreviewed]。
  final AssetSubscriptionReviewDecision subscriptionReviewDecision;

  /// 請求経路 (Apple/Google/au 経由 or 直接)。既定は direct。棚卸しでの集約請求との
  /// 突き合わせ表示に使い、資金繰りの計上額には影響しない。
  final AssetSubscriptionBillingGateway billingGateway;

  /// 入力通貨。既定は円 (jpy)。ドル建て (usd) のサブスク (Claude/Notion 等) は
  /// 毎月の為替で円額が変わるため usd を指定し、[usdAmount] に原資の USD 額を持つ。
  final AssetRecurringFixedCostCurrency currency;

  /// ドル建て時の原資 (USD 額)。[currency] == usd のときのみ意味を持つ。
  /// 円換算額 [amount] は「最新レートで再計算した値」を都度保存するため、
  /// レート未取得時でも前回値で計上でき、レート更新時に自動で追随する。
  final double? usdAmount;

  const AssetRecurringFixedCost({
    required this.id,
    required this.name,
    required this.amount,
    required this.paymentDay,
    this.cadence = AssetRecurringFixedCostCadence.monthly,
    this.sourceAccountId,
    this.category = AssetRecurringFixedCostCategory.utility,
    this.subscriptionReviewDecision =
        AssetSubscriptionReviewDecision.unreviewed,
    this.billingGateway = AssetSubscriptionBillingGateway.direct,
    this.currency = AssetRecurringFixedCostCurrency.jpy,
    this.usdAmount,
  });

  /// ドル建てか。
  bool get isUsd => currency == AssetRecurringFixedCostCurrency.usd;

  /// 指定レート (1 USD = [usdJpyRate] 円) で円換算した月額を返す。
  /// ドル建てかつ原資・レートが有効なときのみ再計算し、それ以外は現行の
  /// [amount] を据え置く (レート未取得時に 0 円へ落ちないようにする)。
  double resolveJpyAmount(double? usdJpyRate) {
    if (!isUsd || usdAmount == null || usdJpyRate == null || usdJpyRate <= 0) {
      return amount;
    }
    return (usdAmount! * usdJpyRate).roundToDouble();
  }

  /// 指定した月 (1-12) にこの固定費が発生するか (隔月は偶数/奇数月のみ計上)。
  bool appliesToMonth(int month) {
    switch (cadence) {
      case AssetRecurringFixedCostCadence.monthly:
        return true;
      case AssetRecurringFixedCostCadence.bimonthlyEvenMonth:
        return month.isEven;
      case AssetRecurringFixedCostCadence.bimonthlyOddMonth:
        return month.isOdd;
    }
  }

  AssetRecurringFixedCost copyWith({
    String? id,
    String? name,
    double? amount,
    int? paymentDay,
    AssetRecurringFixedCostCadence? cadence,
    String? sourceAccountId,
    bool clearSourceAccountId = false,
    AssetRecurringFixedCostCategory? category,
    AssetSubscriptionReviewDecision? subscriptionReviewDecision,
    AssetSubscriptionBillingGateway? billingGateway,
    AssetRecurringFixedCostCurrency? currency,
    double? usdAmount,
    bool clearUsdAmount = false,
  }) {
    return AssetRecurringFixedCost(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      paymentDay: paymentDay ?? this.paymentDay,
      cadence: cadence ?? this.cadence,
      sourceAccountId: clearSourceAccountId
          ? null
          : (sourceAccountId ?? this.sourceAccountId),
      category: category ?? this.category,
      subscriptionReviewDecision:
          subscriptionReviewDecision ?? this.subscriptionReviewDecision,
      billingGateway: billingGateway ?? this.billingGateway,
      currency: currency ?? this.currency,
      usdAmount: clearUsdAmount ? null : (usdAmount ?? this.usdAmount),
    );
  }

  /// ID をキーにする保存形のため、JSON には id を含めない。
  /// 区分は既定 (utility) のときは出力しない (既存ペイロードと互換を保つ)。
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'amount': amount,
      'paymentDay': paymentDay,
      'cadence': cadence.name,
      if (sourceAccountId != null && sourceAccountId!.isNotEmpty)
        'sourceAccountId': sourceAccountId,
      if (category != AssetRecurringFixedCostCategory.utility)
        'category': category.name,
      if (subscriptionReviewDecision !=
          AssetSubscriptionReviewDecision.unreviewed)
        'subscriptionReviewDecision': subscriptionReviewDecision.name,
      if (billingGateway != AssetSubscriptionBillingGateway.direct)
        'billingGateway': billingGateway.name,
      // 通貨は既定 (jpy) のとき出力しない (既存ペイロードと互換を保つ)。
      if (currency != AssetRecurringFixedCostCurrency.jpy)
        'currency': currency.name,
      if (usdAmount != null) 'usdAmount': usdAmount,
    };
  }

  /// 不正な値 (空名 / 金額<=0 / 振替日範囲外) は null を返す寛容なパース。
  static AssetRecurringFixedCost? fromJson(
    String id,
    Map<String, dynamic> json,
  ) {
    final trimmedId = id.trim();
    if (trimmedId.isEmpty) {
      return null;
    }
    final name = json['name']?.toString().trim() ?? '';
    if (name.isEmpty) {
      return null;
    }
    final amount =
        (json['amount'] as num?)?.toDouble() ??
        double.tryParse(json['amount']?.toString() ?? '');
    if (amount == null || amount <= 0) {
      return null;
    }
    final paymentDay =
        (json['paymentDay'] as num?)?.toInt() ??
        int.tryParse(json['paymentDay']?.toString() ?? '');
    if (paymentDay == null || paymentDay < 1 || paymentDay > 31) {
      return null;
    }
    final cadenceName = json['cadence']?.toString();
    final cadence = AssetRecurringFixedCostCadence.values.firstWhere(
      (value) => value.name == cadenceName,
      orElse: () => AssetRecurringFixedCostCadence.monthly,
    );
    final rawSource = json['sourceAccountId']?.toString().trim();
    final categoryName = json['category']?.toString();
    final category = AssetRecurringFixedCostCategory.values.firstWhere(
      (value) => value.name == categoryName,
      orElse: () => AssetRecurringFixedCostCategory.utility,
    );
    final reviewDecisionName = json['subscriptionReviewDecision']?.toString();
    final reviewDecision =
        category == AssetRecurringFixedCostCategory.subscription
        ? AssetSubscriptionReviewDecision.values.firstWhere(
            (value) => value.name == reviewDecisionName,
            orElse: () => AssetSubscriptionReviewDecision.unreviewed,
          )
        : AssetSubscriptionReviewDecision.unreviewed;
    final gatewayName = json['billingGateway']?.toString();
    final billingGateway = AssetSubscriptionBillingGateway.values.firstWhere(
      (value) => value.name == gatewayName,
      orElse: () => AssetSubscriptionBillingGateway.direct,
    );
    final currencyName = json['currency']?.toString();
    final currency = AssetRecurringFixedCostCurrency.values.firstWhere(
      (value) => value.name == currencyName,
      orElse: () => AssetRecurringFixedCostCurrency.jpy,
    );
    final usdAmount =
        (json['usdAmount'] as num?)?.toDouble() ??
        double.tryParse(json['usdAmount']?.toString() ?? '');
    return AssetRecurringFixedCost(
      id: trimmedId,
      name: name,
      amount: amount,
      paymentDay: paymentDay,
      cadence: cadence,
      sourceAccountId: rawSource == null || rawSource.isEmpty
          ? null
          : rawSource,
      category: category,
      subscriptionReviewDecision: reviewDecision,
      billingGateway: billingGateway,
      currency: currency,
      usdAmount: usdAmount != null && usdAmount > 0 ? usdAmount : null,
    );
  }
}

/// リボ残高に対して算出した今月の請求内訳。
class AssetLiabilityRevolvingCreditBilling {
  /// リボ残高 (= 当月時点の負債残高)。
  final double balance;

  /// 利用限度額。返済額計算では使用せず、与信枠不足の確認だけに使う。
  final double creditLimit;

  /// 既存残高へ充当する当月の最低返済額。
  final double monthlyAmount;

  /// 当月中に全額返済する新規利用額。
  final double newUsageAmount;

  /// 新規利用分を除いた既存リボ残高。
  final double existingBalanceAmount;

  /// 返済日。給料日に合わせて毎月25日。
  final int paymentDay;

  /// 旧計算とのAPI互換用。現行ルールでは常に0。
  final double overLimitAmount;

  /// 今月返済予定額 = [monthlyAmount] + [newUsageAmount]。
  final double billedAmount;

  const AssetLiabilityRevolvingCreditBilling({
    required this.balance,
    required this.creditLimit,
    required this.monthlyAmount,
    required this.newUsageAmount,
    required this.existingBalanceAmount,
    required this.paymentDay,
    required this.overLimitAmount,
    required this.billedAmount,
  });

  /// 旧限度額超過ルールが有効か。現行ルールでは常に false。
  bool get isOverLimit => overLimitAmount > 0;
}

class AssetLiabilityDebtRow {
  final String id;
  final String name;
  final AssetLiabilityAccountKind kind;
  final double balance;
  final int? paymentDay;
  final String? paymentSourceAccountId;
  final String? paymentSourceAccountName;
  final AssetLiabilityPaymentMethod paymentMethod;
  final String? paymentMethodLabel;
  final AssetLiabilityPaymentMethodSettingSource paymentMethodSettingSource;
  final String? billingAccountId;
  final String? billingAccountName;
  final bool includedInBillingAccount;
  final double annualRate;
  final double minimumPaymentEstimate;
  final double? manualPaymentAmount;
  final double scheduledPaymentAmount;
  final double? actualPaymentAmount;
  final String? paymentDifferenceReason;
  final double monthlyInterestEstimate;
  final double principalPaymentEstimate;
  final double balanceAfterPaymentEstimate;
  final double liabilityShare;
  final String priorityLabel;
  final bool paymentAmountEstimated;
  final bool billingConfirmed;
  final bool paid;

  /// 今月の支払いを期限管理・行動対象として扱うか。
  ///
  /// 支払予定額が 0 円の月と支払済みの行は確認対象に留め、延滞として扱わない。
  final bool requiresAction;

  /// 家賃・通信費など毎月全額を支払う固定費型の負債。利率の概念を持たない。
  final bool fullPaymentEstimate;

  /// リボ払いカードの場合の今月返済内訳 (= 最低返済額 + 新規利用額)。
  /// null なら通常の負債 (請求額は手入力 or 推定)。
  final AssetLiabilityRevolvingCreditBilling? revolvingBilling;

  const AssetLiabilityDebtRow({
    required this.id,
    required this.name,
    required this.kind,
    required this.balance,
    required this.paymentDay,
    required this.paymentSourceAccountId,
    required this.paymentSourceAccountName,
    required this.paymentMethod,
    required this.paymentMethodLabel,
    required this.paymentMethodSettingSource,
    required this.billingAccountId,
    required this.billingAccountName,
    required this.includedInBillingAccount,
    required this.annualRate,
    required this.minimumPaymentEstimate,
    required this.manualPaymentAmount,
    required this.scheduledPaymentAmount,
    this.actualPaymentAmount,
    this.paymentDifferenceReason,
    required this.monthlyInterestEstimate,
    required this.principalPaymentEstimate,
    required this.balanceAfterPaymentEstimate,
    required this.liabilityShare,
    required this.priorityLabel,
    required this.paymentAmountEstimated,
    required this.billingConfirmed,
    required this.paid,
    required this.requiresAction,
    this.fullPaymentEstimate = false,
    this.revolvingBilling,
  });

  /// リボ払いカードか (= 最低返済額 + 新規利用額を25日に返すか)。
  bool get isRevolving => revolvingBilling != null;

  bool get isDirectCashflowTarget =>
      !includedInBillingAccount &&
      paymentMethod == AssetLiabilityPaymentMethod.direct;

  double get effectivePaidPaymentAmount =>
      paid ? actualPaymentAmount ?? scheduledPaymentAmount : 0;

  double? get paymentDifferenceAmount {
    if (!paid || actualPaymentAmount == null) {
      return null;
    }
    return actualPaymentAmount! - scheduledPaymentAmount;
  }
}

class AssetLiabilityPaymentDayRisk {
  final int paymentDay;
  final DateTime paymentDate;
  final List<String> accountNames;
  final double balanceTotal;
  final double minimumPaymentEstimateTotal;
  final double scheduledPaymentTotal;
  final double manualPaymentTotal;
  final double interestEstimateTotal;
  final int manualPaymentCount;
  final int estimatedPaymentCount;
  final bool requiresAction;
  final bool isPast;
  final bool isToday;

  const AssetLiabilityPaymentDayRisk({
    required this.paymentDay,
    required this.paymentDate,
    required this.accountNames,
    required this.balanceTotal,
    required this.minimumPaymentEstimateTotal,
    required this.scheduledPaymentTotal,
    required this.manualPaymentTotal,
    required this.interestEstimateTotal,
    required this.manualPaymentCount,
    required this.estimatedPaymentCount,
    required this.requiresAction,
    required this.isPast,
    required this.isToday,
  });

  bool get isUpcoming => !isPast && !isToday;
  bool get hasManualPayments => manualPaymentCount > 0;
  bool get hasEstimatedPayments => estimatedPaymentCount > 0;
}

enum AssetLiabilityCashRiskLevel { normal, watch, caution, short }

enum AssetLiabilityCashflowEventType { payment, income }

class AssetLiabilityIncomePlan {
  final String id;
  final DateTime date;
  final String name;
  final double amount;
  final String? destinationAccountId;
  final String? destinationAccountName;
  final bool received;

  const AssetLiabilityIncomePlan({
    required this.id,
    required this.date,
    required this.name,
    required this.amount,
    required this.destinationAccountId,
    required this.destinationAccountName,
    required this.received,
  });
}

class AssetLiabilityRecurringIncomeTemplate {
  final String id;
  final int dayOfMonth;
  final String name;
  final double amount;
  final String? destinationAccountId;
  final String? destinationAccountName;

  const AssetLiabilityRecurringIncomeTemplate({
    required this.id,
    required this.dayOfMonth,
    required this.name,
    required this.amount,
    required this.destinationAccountId,
    required this.destinationAccountName,
  });
}

class AssetLiabilityCashflowRow {
  final AssetLiabilityCashflowEventType eventType;
  final String accountId;
  final String accountName;
  final int paymentDay;
  final DateTime paymentDate;
  final String? paymentSourceAccountId;
  final String? paymentSourceAccountName;
  final String? destinationAccountId;
  final String? destinationAccountName;
  final AssetLiabilityPaymentMethod paymentMethod;
  final String? paymentMethodLabel;
  final AssetLiabilityPaymentMethodSettingSource paymentMethodSettingSource;
  final String? billingAccountId;
  final String? billingAccountName;
  final bool includedInBillingAccount;
  final double paymentAmount;
  final double? actualPaymentAmount;
  final double? paymentDifferenceAmount;
  final String? paymentDifferenceReason;
  final bool paymentAmountEstimated;
  final bool paid;
  final bool received;
  final bool overdue;
  final double cashBeforePayment;
  final double cashAfterPayment;
  final AssetLiabilityCashRiskLevel riskLevel;

  const AssetLiabilityCashflowRow({
    required this.eventType,
    required this.accountId,
    required this.accountName,
    required this.paymentDay,
    required this.paymentDate,
    required this.paymentSourceAccountId,
    required this.paymentSourceAccountName,
    required this.destinationAccountId,
    required this.destinationAccountName,
    required this.paymentMethod,
    required this.paymentMethodLabel,
    required this.paymentMethodSettingSource,
    required this.billingAccountId,
    required this.billingAccountName,
    required this.includedInBillingAccount,
    required this.paymentAmount,
    this.actualPaymentAmount,
    this.paymentDifferenceAmount,
    this.paymentDifferenceReason,
    required this.paymentAmountEstimated,
    required this.paid,
    required this.received,
    required this.overdue,
    required this.cashBeforePayment,
    required this.cashAfterPayment,
    required this.riskLevel,
  });

  bool get isPayment => eventType == AssetLiabilityCashflowEventType.payment;
  bool get isIncome => eventType == AssetLiabilityCashflowEventType.income;
  bool get isDirectCashflowTarget =>
      !includedInBillingAccount &&
      paymentMethod == AssetLiabilityPaymentMethod.direct;
}

class AssetLiabilityAccountCashflowSummary {
  final String accountId;
  final String accountName;
  final double currentBalance;
  final double upcomingPayments;
  final double upcomingIncome;
  final double pendingTransferIn;
  final double pendingTransferOut;
  final double projectedBalance;
  final AssetLiabilityCashRiskLevel riskLevel;

  const AssetLiabilityAccountCashflowSummary({
    required this.accountId,
    required this.accountName,
    required this.currentBalance,
    required this.upcomingPayments,
    required this.upcomingIncome,
    this.pendingTransferIn = 0,
    this.pendingTransferOut = 0,
    required this.projectedBalance,
    required this.riskLevel,
  });

  bool get isShort => projectedBalance < 0;
  double get shortfall => isShort ? projectedBalance.abs() : 0;
}

class AssetLiabilityTransferSuggestion {
  final String fromAccountId;
  final String fromAccountName;
  final String toAccountId;
  final String toAccountName;
  final double amount;
  final DateTime? neededBy;

  const AssetLiabilityTransferSuggestion({
    required this.fromAccountId,
    required this.fromAccountName,
    required this.toAccountId,
    required this.toAccountName,
    required this.amount,
    required this.neededBy,
  });
}

class AssetLiabilityTransferTask {
  final String id;
  final String fromAccountId;
  final String fromAccountName;
  final String toAccountId;
  final String toAccountName;
  final double amount;
  final DateTime? dueDate;
  final bool completed;
  final DateTime? completedAt;
  final String completionMemo;
  final bool canceled;
  final DateTime? canceledAt;
  final String cancellationReason;

  const AssetLiabilityTransferTask({
    required this.id,
    required this.fromAccountId,
    required this.fromAccountName,
    required this.toAccountId,
    required this.toAccountName,
    required this.amount,
    required this.dueDate,
    this.completed = false,
    this.completedAt,
    this.completionMemo = '',
    this.canceled = false,
    this.canceledAt,
    this.cancellationReason = '',
  });

  AssetLiabilityTransferTask copyWith({
    String? id,
    String? fromAccountId,
    String? fromAccountName,
    String? toAccountId,
    String? toAccountName,
    double? amount,
    DateTime? dueDate,
    bool? completed,
    DateTime? completedAt,
    String? completionMemo,
    bool? canceled,
    DateTime? canceledAt,
    String? cancellationReason,
  }) {
    return AssetLiabilityTransferTask(
      id: id ?? this.id,
      fromAccountId: fromAccountId ?? this.fromAccountId,
      fromAccountName: fromAccountName ?? this.fromAccountName,
      toAccountId: toAccountId ?? this.toAccountId,
      toAccountName: toAccountName ?? this.toAccountName,
      amount: amount ?? this.amount,
      dueDate: dueDate ?? this.dueDate,
      completed: completed ?? this.completed,
      completedAt: completedAt ?? this.completedAt,
      completionMemo: completionMemo ?? this.completionMemo,
      canceled: canceled ?? this.canceled,
      canceledAt: canceledAt ?? this.canceledAt,
      cancellationReason: cancellationReason ?? this.cancellationReason,
    );
  }
}

class AssetLiabilityMonthlySnapshot {
  final String monthKey;
  final DateTime savedAt;
  final double positiveAssetTotal;
  final double liabilityTotal;
  final double netWorth;
  final double cashLikeTotal;
  final double monthlyScheduledPaymentTotal;
  final double monthlyPaidPaymentTotal;
  final double monthlyUnpaidPaymentTotal;
  final double monthlyActualPaymentTotal;
  final double monthlyPaymentDifferenceTotal;
  final int overduePaymentCount;

  /// その月末時点の証券 (securities 口座) 評価額合計。
  ///
  /// 従来スナップショットに保存されておらず、旧データ / Supabase 同期分は
  /// null (= 未追跡) になる。投資評価額の時系列グラフ (#2469) は
  /// 「未追跡」と「評価額 0 円」を区別する必要があるため nullable のままにし、
  /// null の月はグラフの点として描かない (0 円へ落とすと保有していたはずの
  /// 資産が消えたように見えるため)。
  final double? securitiesTotal;

  /// その月に受領済み (received=true) となった収入の合計。
  ///
  /// 収入は従来スナップショットに保存されておらず、旧データ / Supabase 同期分は
  /// null (= 未追跡) になる。キャッシュフロー計算では null を「0 円の収入」と
  /// 誤認すると全月が赤字に倒れるため、null の月は月次CF・黒字赤字カウントから
  /// 除外する (= [AssetCashflowStatementService])。非 null の 0 は「収入 0 円」を
  /// 意味し、追跡済みとして扱う。
  final double? monthlyReceivedIncomeTotal;

  const AssetLiabilityMonthlySnapshot({
    required this.monthKey,
    required this.savedAt,
    required this.positiveAssetTotal,
    required this.liabilityTotal,
    required this.netWorth,
    required this.cashLikeTotal,
    required this.monthlyScheduledPaymentTotal,
    required this.monthlyPaidPaymentTotal,
    required this.monthlyUnpaidPaymentTotal,
    this.monthlyActualPaymentTotal = 0,
    this.monthlyPaymentDifferenceTotal = 0,
    required this.overduePaymentCount,
    this.monthlyReceivedIncomeTotal,
    this.securitiesTotal,
  });
}

class AssetLiabilityMonthlyReport {
  final String monthKey;
  final DateTime generatedAt;
  final double totalAssets;
  final double totalLiabilities;
  final double netWorth;
  final String aiSummary;
  final String aiModel;

  const AssetLiabilityMonthlyReport({
    required this.monthKey,
    required this.generatedAt,
    required this.totalAssets,
    required this.totalLiabilities,
    required this.netWorth,
    required this.aiSummary,
    required this.aiModel,
  });
}

class AssetLiabilityMonthlySnapshotComparison {
  final AssetLiabilityMonthlySnapshot snapshot;
  final double? positiveAssetDelta;
  final double? liabilityDelta;
  final double? netWorthDelta;
  final double? cashLikeDelta;

  const AssetLiabilityMonthlySnapshotComparison({
    required this.snapshot,
    required this.positiveAssetDelta,
    required this.liabilityDelta,
    required this.netWorthDelta,
    required this.cashLikeDelta,
  });

  bool get hasPrevious => netWorthDelta != null;
}

enum AssetLiabilityMonthlyChartMetric {
  positiveAssetTotal,
  liabilityTotal,
  netWorth,
  cashLikeTotal,
}

class AssetLiabilityMonthlyChartPoint {
  final String monthKey;
  final double value;
  final double? deltaFromPrevious;
  final bool worsened;

  const AssetLiabilityMonthlyChartPoint({
    required this.monthKey,
    required this.value,
    required this.deltaFromPrevious,
    required this.worsened,
  });
}

class AssetLiabilityMonthlyChartSeries {
  final AssetLiabilityMonthlyChartMetric metric;
  final String label;
  final List<AssetLiabilityMonthlyChartPoint> points;

  const AssetLiabilityMonthlyChartSeries({
    required this.metric,
    required this.label,
    required this.points,
  });
}

class AssetLiabilityMonthlyChartData {
  final List<String> monthKeys;
  final List<AssetLiabilityMonthlyChartSeries> series;

  const AssetLiabilityMonthlyChartData({
    required this.monthKeys,
    required this.series,
  });

  bool get hasEnoughData => monthKeys.length >= 2;
}

class AssetLiabilityCardBillingReviewItem {
  final String accountId;
  final String accountName;
  final double amount;
  final int? paymentDay;
  final AssetLiabilityPaymentMethod paymentMethod;
  final String paymentMethodLabel;
  final AssetLiabilityPaymentMethodSettingSource paymentMethodSettingSource;
  final String? billingAccountId;
  final String? billingAccountName;
  final bool includedInBillingAccount;
  final bool directCashflowTarget;
  final bool paid;
  final List<String> alerts;

  const AssetLiabilityCardBillingReviewItem({
    required this.accountId,
    required this.accountName,
    required this.amount,
    required this.paymentDay,
    required this.paymentMethod,
    required this.paymentMethodLabel,
    required this.paymentMethodSettingSource,
    required this.billingAccountId,
    required this.billingAccountName,
    required this.includedInBillingAccount,
    required this.directCashflowTarget,
    required this.paid,
    this.alerts = const <String>[],
  });

  bool get needsReview => alerts.isNotEmpty;
  bool get hasMissingBillingAccount =>
      includedInBillingAccount &&
      (billingAccountId == null || billingAccountId!.trim().isEmpty);
  bool get excludedFromDirectCashflow => includedInBillingAccount;
}

class AssetLiabilityCardBillingGroup {
  final String billingAccountId;
  final String billingAccountName;
  final List<AssetLiabilityCardBillingReviewItem> items;

  const AssetLiabilityCardBillingGroup({
    required this.billingAccountId,
    required this.billingAccountName,
    required this.items,
  });

  double get totalAmount {
    return items.fold<double>(0, (sum, item) => sum + item.amount);
  }
}

class AssetLiabilityCardStatementLine {
  final String id;
  final String billingAccountId;
  final String? billingAccountName;
  final DateTime? postedAt;
  final String description;
  final double amount;

  const AssetLiabilityCardStatementLine({
    required this.id,
    required this.billingAccountId,
    required this.billingAccountName,
    required this.postedAt,
    required this.description,
    required this.amount,
  });

  AssetLiabilityCardStatementLine copyWith({
    String? id,
    String? billingAccountId,
    String? billingAccountName,
    DateTime? postedAt,
    String? description,
    double? amount,
  }) {
    return AssetLiabilityCardStatementLine(
      id: id ?? this.id,
      billingAccountId: billingAccountId ?? this.billingAccountId,
      billingAccountName: billingAccountName ?? this.billingAccountName,
      postedAt: postedAt ?? this.postedAt,
      description: description ?? this.description,
      amount: amount ?? this.amount,
    );
  }
}

class AssetLiabilityCardStatementRejectedRow {
  final int rowNumber;
  final String rawText;
  final String reason;

  const AssetLiabilityCardStatementRejectedRow({
    required this.rowNumber,
    required this.rawText,
    required this.reason,
  });
}

class AssetLiabilityCardStatementImportResult {
  final List<AssetLiabilityCardStatementLine> lines;
  final List<AssetLiabilityCardStatementRejectedRow> rejectedRows;

  const AssetLiabilityCardStatementImportResult({
    required this.lines,
    required this.rejectedRows,
  });

  bool get hasAcceptedRows => lines.isNotEmpty;
  bool get hasRejectedRows => rejectedRows.isNotEmpty;
}

/// 明細照合の差分をユーザーがその場で解消するための修正アクション種別。
enum AssetLiabilityCardStatementFixActionKind {
  /// カード明細を貼り付けて取り込む（明細未取込）。
  importStatement,

  /// 設定済みカード内訳（支払い方式・今月支払予定額）を見直す。
  adjustConfiguredBreakdown,

  /// 取込済み明細と請求額の差分行を確認する。
  reviewStatementLines,

  /// 請求先カード口座が見つからないため再設定する。
  assignBillingAccount,
}

/// 明細照合アラートに対応する具体的な修正アクション。
/// アラート文字列だけでは「次に何をすればよいか」が分からないため、
/// 差分金額と操作内容をセットで planning service が算出する。
class AssetLiabilityCardStatementFixAction {
  final AssetLiabilityCardStatementFixActionKind kind;
  final String title;
  final String description;

  /// 解消すべき差分金額（+は請求額超過 / −は不足）。差分が定義できない
  /// アクション（明細未取込など）は null。
  final double? amount;

  const AssetLiabilityCardStatementFixAction({
    required this.kind,
    required this.title,
    required this.description,
    this.amount,
  });
}

class AssetLiabilityCardStatementReconciliationGroup {
  final String billingAccountId;
  final String billingAccountName;
  final double billedAmount;
  final double configuredDetailTotal;
  final double statementLineTotal;
  final List<AssetLiabilityCardBillingReviewItem> configuredItems;
  final List<AssetLiabilityCardStatementLine> statementLines;
  final List<String> alerts;

  /// アラートを解消するための修正アクション（planning service が算出）。
  final List<AssetLiabilityCardStatementFixAction> fixActions;

  /// リボ払いカードの場合の今月請求内訳。null なら通常の一括払いカード。
  /// リボ払いでは 請求額 ≠ 明細合計 が正常なため、不一致アラートは抑止する。
  final AssetLiabilityRevolvingCreditBilling? revolvingBilling;

  const AssetLiabilityCardStatementReconciliationGroup({
    required this.billingAccountId,
    required this.billingAccountName,
    required this.billedAmount,
    required this.configuredDetailTotal,
    required this.statementLineTotal,
    required this.configuredItems,
    required this.statementLines,
    required this.alerts,
    this.fixActions = const <AssetLiabilityCardStatementFixAction>[],
    this.revolvingBilling,
  });

  double get statementDifference => statementLineTotal - billedAmount;
  double get configuredDifference => configuredDetailTotal - billedAmount;
  bool get hasStatementLines => statementLines.isNotEmpty;
  bool get needsReview => alerts.isNotEmpty;
  bool get hasFixActions => fixActions.isNotEmpty;

  /// 設定済み内訳合計が請求額とずれているか（＝内訳の修正が必要か）。
  bool get hasConfiguredMismatchFix => fixActions.any(
    (action) =>
        action.kind ==
        AssetLiabilityCardStatementFixActionKind.adjustConfiguredBreakdown,
  );

  /// リボ払いカードか。
  bool get isRevolving => revolvingBilling != null;
}

class AssetLiabilityCardStatementReconciliationData {
  final List<AssetLiabilityCardStatementReconciliationGroup> groups;
  final List<AssetLiabilityCardStatementLine> unmatchedStatementLines;

  const AssetLiabilityCardStatementReconciliationData({
    required this.groups,
    required this.unmatchedStatementLines,
  });

  int get importedLineCount {
    return groups.fold<int>(
          0,
          (sum, group) => sum + group.statementLines.length,
        ) +
        unmatchedStatementLines.length;
  }

  double get importedLineTotal {
    return groups.fold<double>(
          0,
          (sum, group) => sum + group.statementLineTotal,
        ) +
        unmatchedStatementLines.fold<double>(
          0,
          (sum, line) => sum + line.amount,
        );
  }

  List<AssetLiabilityCardStatementReconciliationGroup> get needsReviewGroups {
    return groups.where((group) => group.needsReview).toList(growable: false);
  }

  bool get hasNeedsReview => needsReviewGroups.isNotEmpty;
}

class AssetLiabilityCardBillingReviewData {
  final List<AssetLiabilityCardBillingReviewItem> directPaymentItems;
  final List<AssetLiabilityCardBillingGroup> cardBillingGroups;
  final List<AssetLiabilityCardBillingReviewItem> missingBillingAccountItems;
  final List<AssetLiabilityCardBillingReviewItem> needsReviewItems;
  final List<AssetLiabilityCardBillingReviewItem> doubleCountingRiskItems;

  const AssetLiabilityCardBillingReviewData({
    required this.directPaymentItems,
    required this.cardBillingGroups,
    required this.missingBillingAccountItems,
    required this.needsReviewItems,
    required this.doubleCountingRiskItems,
  });

  bool get hasDoubleCountingRisk => doubleCountingRiskItems.isNotEmpty;
  bool get hasNeedsReviewItems => needsReviewItems.isNotEmpty;
  bool get hasMissingBillingAccounts => missingBillingAccountItems.isNotEmpty;
  int get cardBilledItemCount {
    return cardBillingGroups.fold<int>(
      0,
      (sum, group) => sum + group.items.length,
    );
  }
}

class AssetLiabilityCsvExportBundle {
  final String monthlyHistoryCsv;
  final String paymentScheduleCsv;
  final String cardStatementCsv;
  final String incomePlansCsv;
  final String accountCashflowCsv;

  const AssetLiabilityCsvExportBundle({
    required this.monthlyHistoryCsv,
    required this.paymentScheduleCsv,
    required this.cardStatementCsv,
    required this.incomePlansCsv,
    required this.accountCashflowCsv,
  });
}

class AssetLiabilityWorkbook {
  final DateTime baseDate;
  final List<AssetLiabilityAccount> accounts;
  final List<AssetLiabilityDebtRow> debtMasterRows;
  final List<AssetLiabilityDebtRow> repaymentPriorityRows;
  final List<AssetLiabilityPaymentDayRisk> paymentDayRisks;
  final List<AssetLiabilityCashflowRow> cashflowRows;
  final List<AssetLiabilityIncomePlan> incomePlans;
  final List<AssetLiabilityTransferTask> transferTasks;
  final List<AssetLiabilityAccountCashflowSummary> accountCashflowSummaries;
  final List<AssetLiabilityTransferSuggestion> transferSuggestions;
  final AssetLiabilityCardBillingReviewData cardBillingReview;
  final AssetLiabilityCardStatementReconciliationData
  cardStatementReconciliation;
  final double cashLikeTotal;
  final double securitiesTotal;
  final double positiveAssetTotal;
  final double liabilityTotal;
  final double netWorth;
  final double monthlyMinimumPaymentEstimateTotal;
  final double monthlyScheduledPaymentTotal;
  final double monthlyActualPaymentTotal;
  final double monthlyPaymentDifferenceTotal;
  final double monthlyUnpaidPaymentTotal;
  final double monthlyUnreceivedIncomeTotal;
  final double cashAfterMinimumPayments;
  final double cashAfterScheduledPayments;
  final double debtToAssetRatio;
  final double topFourDebtShare;
  final int manualPaymentCount;
  final int estimatedPaymentCount;

  /// サブスク区分 (AssetRecurringFixedCostCategory.subscription) として登録された
  /// 定期固定費の口座 ID 集合。資金繰り上は utility 負債として計上され
  /// fullPaymentEstimate=true になるため、家賃・光熱費などの「生命線」と
  /// 区別できない。トリアージで「生命線を優先確保」から除外するために保持する
  /// (サブスクは解約候補であって優先支払い対象ではない)。
  final Set<String> subscriptionFixedCostAccountIds;

  /// カードIDごとの「今後は一括（1回）払い」実行記録。
  ///
  /// 規律違反や残高圧縮額の算出は維持し、設定変更を促す助言だけをカード単位で
  /// 抑止するために insight 層へ渡す。
  final Map<String, AssetCardUsagePolicy> cardUsagePolicies;

  const AssetLiabilityWorkbook({
    required this.baseDate,
    required this.accounts,
    required this.debtMasterRows,
    required this.repaymentPriorityRows,
    required this.paymentDayRisks,
    required this.cashflowRows,
    required this.incomePlans,
    required this.transferTasks,
    required this.accountCashflowSummaries,
    required this.transferSuggestions,
    required this.cardBillingReview,
    required this.cardStatementReconciliation,
    required this.cashLikeTotal,
    required this.securitiesTotal,
    required this.positiveAssetTotal,
    required this.liabilityTotal,
    required this.netWorth,
    required this.monthlyMinimumPaymentEstimateTotal,
    required this.monthlyScheduledPaymentTotal,
    required this.monthlyActualPaymentTotal,
    required this.monthlyPaymentDifferenceTotal,
    required this.monthlyUnpaidPaymentTotal,
    required this.monthlyUnreceivedIncomeTotal,
    required this.cashAfterMinimumPayments,
    required this.cashAfterScheduledPayments,
    required this.debtToAssetRatio,
    required this.topFourDebtShare,
    required this.manualPaymentCount,
    required this.estimatedPaymentCount,
    this.subscriptionFixedCostAccountIds = const <String>{},
    this.cardUsagePolicies = const <String, AssetCardUsagePolicy>{},
  });

  List<AssetLiabilityCashflowRow> get overdueCashflowRows {
    return cashflowRows.where((row) => row.overdue).toList();
  }

  bool get hasOverduePayments => overdueCashflowRows.isNotEmpty;

  List<AssetLiabilityAccountCashflowSummary> get shortAccountSummaries {
    return accountCashflowSummaries
        .where((summary) => summary.isShort)
        .toList();
  }

  bool get hasAccountShortage => shortAccountSummaries.isNotEmpty;

  List<AssetLiabilityIncomePlan> get unassignedDestinationIncomePlans {
    return incomePlans
        .where((plan) => !plan.received && plan.destinationAccountId == null)
        .toList();
  }

  bool get hasUnassignedDestinationIncomePlans {
    return unassignedDestinationIncomePlans.isNotEmpty;
  }

  List<AssetLiabilityDebtRow> get billingConfirmationPendingRows {
    return debtMasterRows
        .where(
          (row) =>
              row.isDirectCashflowTarget &&
              row.paymentAmountEstimated &&
              !row.billingConfirmed &&
              row.scheduledPaymentAmount > 0 &&
              !row.paid,
        )
        .toList();
  }

  bool get hasBillingConfirmationPendingRows {
    return billingConfirmationPendingRows.isNotEmpty;
  }

  double get billingConfirmationPendingTotal {
    return billingConfirmationPendingRows.fold<double>(
      0,
      (sum, row) => sum + row.scheduledPaymentAmount,
    );
  }

  /// 支払原資が未設定の支払い。支払済み行は除く。
  ///
  /// 原資未設定を警告する根拠は「どの口座の見込み残高からも差し引かれず、
  /// 残高不足を先読みできない」ことだが、口座別見込み残高は支払済み行を
  /// 最初から控除対象外にしている (`_buildAccountCashflowSummaries` の
  /// `!row.paid`) ため、支払済み行にその盲点は存在しない。`!row.paid` が
  /// 無いと支払済みにしてもバナー・アラート・合計金額が残り続け、「払い
  /// 終わった支払いに引落口座を後付けする」以外に消す手段が無くなる。
  /// 兄弟の [paymentSourceInvalidRows] / [billingConfirmationPendingRows] と
  /// 述語を揃える。
  List<AssetLiabilityDebtRow> get paymentSourceMissingRows {
    return debtMasterRows
        .where(
          (row) =>
              row.isDirectCashflowTarget &&
              row.scheduledPaymentAmount > 0 &&
              !row.paid &&
              (row.paymentSourceAccountId == null ||
                  row.paymentSourceAccountId!.trim().isEmpty),
        )
        .toList();
  }

  bool get hasPaymentSourceMissingRows {
    return paymentSourceMissingRows.isNotEmpty;
  }

  double get paymentSourceMissingTotal {
    return paymentSourceMissingRows.fold<double>(
      0,
      (sum, row) => sum + row.scheduledPaymentAmount,
    );
  }

  /// 支払原資が「設定はされているが、現金・預金の資産口座を指していない」支払い。
  ///
  /// 例: 原資が PayPay カード (creditCard) や、資産一覧に存在しない口座 ID
  /// (`paypay_card` 等の請求名フォールバック) を指しているケース。
  /// planner の無効化ガードは cardLoan しか見ないためこれらは非 null のまま残り、
  /// [paymentSourceMissingRows] にも入らないので原資未設定レビュー・一括設定・
  /// アラートのすべてから不可視になる。さらに口座別の見込み残高は
  /// 「原資 ID == 口座 ID」で突き合わせるため、どの口座からも差し引かれない
  /// (全体の資金繰りでは差し引かれるので口座別と全体で帳尻が食い違い、
  /// 口座残高が実態より多く見える)。
  ///
  /// 判定は「現金・預金として資産一覧に載っている口座 ID の集合」に含まれるか
  /// のみで行う。残高0の口座はそもそも資産一覧に載らない (スナップショットの
  /// 0 円除外) ため、その ID を指す行もここで拾われる。これは正しい: 集計対象の
  /// 口座が存在しない以上、その支払いはどの口座からも引かれていないため
  /// (口座ショート警告は資産一覧にある口座しか見ないので、この穴は埋めない)。
  ///
  /// 支払済み (`paid`) の行は除外する。支払済みはどの口座の見込み残高からも
  /// 引かれないのが正しい状態で、「残高が実際より多く見える」も成立しないため、
  /// 警告を出すと誤報になる (月中に支払済みチェックを付けると必ず踏む)。
  ///
  /// 照合は生の ID で行う (per-account 集計も生 ID の一致で突き合わせるため)。
  /// 空白混じりの ID は実際にどの口座とも一致せず引かれないので、拾うのが正しい。
  List<AssetLiabilityDebtRow> get paymentSourceInvalidRows {
    final cashLikeIds = <String>{
      for (final account in accounts)
        if (account.kind == AssetLiabilityAccountKind.cash ||
            account.kind == AssetLiabilityAccountKind.deposit)
          account.id,
    };
    return debtMasterRows
        .where(
          (row) =>
              row.isDirectCashflowTarget &&
              row.scheduledPaymentAmount > 0 &&
              !row.paid &&
              row.paymentSourceAccountId != null &&
              row.paymentSourceAccountId!.trim().isNotEmpty &&
              !cashLikeIds.contains(row.paymentSourceAccountId),
        )
        .toList();
  }

  bool get hasPaymentSourceInvalidRows {
    return paymentSourceInvalidRows.isNotEmpty;
  }

  double get paymentSourceInvalidTotal {
    return paymentSourceInvalidRows.fold<double>(
      0,
      (sum, row) => sum + row.scheduledPaymentAmount,
    );
  }

  double get monthlyScheduledPrincipalEstimateTotal {
    return debtMasterRows
        .where((row) => row.isDirectCashflowTarget)
        .fold<double>(0, (sum, row) => sum + row.principalPaymentEstimate);
  }

  double get monthlyScheduledInterestEstimateTotal {
    return debtMasterRows
        .where((row) => row.isDirectCashflowTarget)
        .fold<double>(
          0,
          (sum, row) =>
              sum +
              row.monthlyInterestEstimate
                  .clamp(0, row.scheduledPaymentAmount)
                  .toDouble(),
        );
  }
}

/// 口座名・ローン名の表記ゆれや類似名称による二重登録（例: 「じぶんローン」と「じぶん銀行カードローン」）の警告。
class AssetLiabilityDebtDuplicateWarning {
  final AssetLiabilityDebtRow rowA;
  final AssetLiabilityDebtRow rowB;
  final double similarity;
  final String message;

  const AssetLiabilityDebtDuplicateWarning({
    required this.rowA,
    required this.rowB,
    required this.similarity,
    required this.message,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
    'rowAId': rowA.id,
    'rowBId': rowB.id,
    'rowAName': rowA.name,
    'rowBName': rowB.name,
    'similarity': similarity,
    'message': message,
  };
}

/// 負債名称からストップワードを除去して正規化コアステムを抽出する。
String normalizeDebtStem(String name) {
  var s = name.toLowerCase().replaceAll(RegExp(r'[\s　・_-]'), '');
  s = s
      .replaceAll('（', '')
      .replaceAll('）', '')
      .replaceAll('(', '')
      .replaceAll(')', '');
  s = s.replaceAll('株式会社', '').replaceAll('合同会社', '');
  s = s.replaceAll('カードローン', '').replaceAll('ローン', '').replaceAll('loan', '');
  s = s.replaceAll('クレジットカード', '').replaceAll('カード', '').replaceAll('card', '');
  s = s.replaceAll('銀行', '').replaceAll('バンク', '').replaceAll('bank', '');
  s = s.replaceAll('リボ', '').replaceAll('割賦', '').replaceAll('キャッシング', '');
  return s.trim();
}

/// 2つの負債名間の類似度（0.0〜1.0）を計算する。
double calculateDebtNameSimilarity(String nameA, String nameB) {
  if (nameA.trim() == nameB.trim()) return 1.0;
  final stemA = normalizeDebtStem(nameA);
  final stemB = normalizeDebtStem(nameB);
  if (stemA.isEmpty || stemB.isEmpty) return 0.0;
  if (stemA == stemB) return 0.95;
  if (stemA.contains(stemB) || stemB.contains(stemA)) {
    final minLen = stemA.length < stemB.length ? stemA.length : stemB.length;
    if (minLen >= 2) return 0.85;
  }
  // Bigram Jaccard similarity
  final bigramsA = <String>{};
  for (var i = 0; i < stemA.length - 1; i++) {
    bigramsA.add(stemA.substring(i, i + 2));
  }
  final bigramsB = <String>{};
  for (var i = 0; i < stemB.length - 1; i++) {
    bigramsB.add(stemB.substring(i, i + 2));
  }
  if (bigramsA.isEmpty || bigramsB.isEmpty) return 0.0;
  final intersection = bigramsA.intersection(bigramsB).length;
  final union = bigramsA.union(bigramsB).length;
  return union == 0 ? 0.0 : intersection / union;
}

/// 口座名・ローン名の表記ゆれや類似名称による負債の重複を検出する。
List<AssetLiabilityDebtDuplicateWarning> detectDuplicateDebts(
  List<AssetLiabilityDebtRow> debtRows,
) {
  final warnings = <AssetLiabilityDebtDuplicateWarning>[];
  for (var i = 0; i < debtRows.length; i++) {
    for (var j = i + 1; j < debtRows.length; j++) {
      final a = debtRows[i];
      final b = debtRows[j];
      final sim = calculateDebtNameSimilarity(a.name, b.name);
      if (sim >= 0.75) {
        warnings.add(
          AssetLiabilityDebtDuplicateWarning(
            rowA: a,
            rowB: b,
            similarity: sim,
            message:
                '「${a.name}」と「${b.name}」は同一の借入・ローンである可能性があります。二重計上にご注意ください。',
          ),
        );
      }
    }
  }
  return warnings;
}
