import 'dart:math';

import 'package:my_web_app/services/debt_lockdown_service.dart';
import 'package:my_web_app/services/asset_revolving_credit_service.dart';

import '../models/asset_liability_workbook.dart';

/// ハードコードされた既定固定費 (家賃/KDDI/水道/ガス) をデータ駆動で表す内部記述子。
///
/// 金額/口座ID/名称は [AssetLiabilityPlanningService] の `static const` を単一の
/// 真実源として参照する。kind と既定の支払日 (25/25/22/12) は引き続き
/// `_classifyAccount` 側に置く (ユーザー手入力の同名口座も同じ経路で分類するため)。
class _BuiltInRecurringFixedCost {
  final String accountId;
  final String accountName;
  final double monthlyAmount;
  final AssetRecurringFixedCostCadence cadence;
  final String? sourceAccountId;

  /// 支払日(_classifyAccount が付与する日と一致)。給料日サイクルでどの暦月に
  /// 発生するかの判定(隔月の偶奇判定)に使う。毎月の固定費では実質影響しない。
  final int paymentDay;

  const _BuiltInRecurringFixedCost({
    required this.accountId,
    required this.accountName,
    required this.monthlyAmount,
    required this.paymentDay,
    this.cadence = AssetRecurringFixedCostCadence.monthly,
    this.sourceAccountId,
  });

  /// 指定した月 (1-12) にこの既定固定費が発生するか (隔月は偶数/奇数月のみ)。
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
}

class AssetLiabilityPlanningService {
  static const String directPaymentMethodId = 'direct';
  static const String directPaymentLabel = '直接支払い';
  static const String cardBillingNotice =
      'カード請求に含める支払いは、資金繰りでは請求先カード側だけを差し引きます。';
  static const String auAccountId = 'au';
  static const String auPayCardAccountId = 'aupay_card';
  static const String auPayCardAccountName = 'auPayカード';
  static const String auPayCardPaymentMethodLabel = 'auPayカード払い';
  static const String cardBillingIncludedLabel = 'カード請求に含む';
  static const String builtInPaymentMethodSettingLabel = '\u65e2\u5b9a\u5024';
  static const String defaultPaymentMethodSettingLabel =
      '\u30c7\u30d5\u30a9\u30eb\u30c8';
  static const String monthlyPaymentMethodSettingLabel =
      '\u4eca\u6708\u3060\u3051\u4e0a\u66f8\u304d';
  static const String saveAsDefaultPaymentMethodLabel =
      '\u30c7\u30d5\u30a9\u30eb\u30c8\u3068\u3057\u3066\u4fdd\u5b58';
  static const String saveAsMonthlyPaymentMethodLabel =
      '\u4eca\u6708\u3060\u3051\u4e0a\u66f8\u304d';
  static const String cardBillingReviewDirectLabel = '直接支払い';
  static const String cardBillingReviewIncludedLabel = 'カード請求に含める';
  static const String cardBillingReviewUnsetLabel = '請求先カード未設定';
  static const String cardBillingReviewNeedsReviewLabel = '設定確認が必要';
  static const String cardBillingReviewNoDoubleCountRiskLabel =
      '二重計上リスクは検出されていません';
  static const String cardBillingReviewDoubleCountRiskLabel = '二重計上リスクあり';
  static const String cardBillingReviewExcludedFromDirectCashflowLabel =
      '二重計上対象外';
  static const String cardBillingReviewDirectCashflowTargetLabel = '直接差し引き対象';
  static const String cardBillingReviewMissingBillingAccountAlert =
      '請求先カードが未設定です';
  static const String cardBillingReviewRemovedBillingAccountAlert =
      '請求先カードが見つかりません';
  static const String cardBillingReviewZeroAmountAlert =
      '金額が0円のため確認してください（請求が0円の月は今月支払予定額に0を入力すると確認対象外になります）';
  static const String cardStatementMissingImportAlert = 'カード明細の取り込みが未実施です';
  static const String cardStatementBillingAccountMissingAlert =
      '請求先カード口座が見つかりません';
  static const String cardStatementAmountMismatchAlert = 'カード明細合計が請求額と一致しません';
  static const String cardStatementConfiguredMismatchAlert =
      '設定済みカード内訳合計が請求額と一致しません';
  static const String cardStatementImportedConfiguredMismatchAlert =
      '取り込み明細合計が設定済み内訳合計と一致しません';
  static const String cardStatementFixImportLabel = 'カード明細を取り込む';
  static const String cardStatementFixAdjustBreakdownLabel = '設定内訳を修正する';
  static const String cardStatementFixReviewLinesLabel = '取込明細を確認する';
  static const String cardStatementFixAssignBillingLabel = '請求先カードを再設定する';
  static const String auCardBillingNotice =
      'auはauPayカード払いのため、資金繰りではauPayカード請求に含めて扱います。';
  static const String kddiProviderAccountId = 'kddi_provider';
  static const String kddiProviderAccountName = 'KDDI';
  static const double kddiProviderMonthlyPaymentAmount = 5764;
  static const String rentAccountId = 'rent';
  static const String rentAccountName = '\u5bb6\u8cc3';
  static const double rentMonthlyPaymentAmount = 63000;
  // \u6c34\u9053\u4ee3: 2\u30f6\u6708\u306b1\u56de(\u5076\u6570\u6708\u306e22\u65e5 / \u4e09\u4e95\u4f4f\u53cb\u9280\u884c\u5927\u585a\u652f\u5e97\u304b\u3089\u53e3\u5ea7\u632f\u66ff)\u3002
  // \u4f7f\u7528\u91cf\u3067\u5909\u52d5\u3059\u308b\u305f\u3081\u6982\u7b972,400\u5186(\u4eca\u6708\u652f\u6255\u4e88\u5b9a\u984d\u306e\u624b\u5165\u529b\u3067\u4e0a\u66f8\u304d\u53ef)\u3002
  static const String waterBillAccountId = 'water_bill';
  static const String waterBillAccountName = '\u6c34\u9053\u4ee3';
  static const double waterBillBimonthlyPaymentAmount = 2400;
  static const int waterBillPaymentDay = 22;
  // ガス代: 毎月12日 / 三井住友銀行大塚支店から口座振替。使用量で変動するため
  // 概算4,500円(3,000〜6,000円の中央値 / 今月支払予定額の手入力で上書き可)。
  static const String gasBillAccountId = 'gas_bill';
  static const String gasBillAccountName = 'ガス代';
  static const double gasBillMonthlyPaymentAmount = 4500;
  static const int gasBillPaymentDay = 12;
  static const String acomShoppingAccountId = 'acom_shopping';
  static const String anthropicAcomShoppingPaymentId =
      'anthropic_acom_shopping_repayment';
  static const String anthropicAcomShoppingPaymentName =
      'Anthropic\u30b5\u30d6\u30b9\u30af'
      '\uff08\u30a2\u30b3\u30e0\u30b7\u30e7\u30c3\u30d4\u30f3\u30b0'
      '\u8fd4\u6e08\uff09';
  static const int anthropicAcomShoppingPaymentDay = 26;
  static const double anthropicAcomShoppingPaymentAmount = 40000;
  static const String smbcOtsukaBranchAccountId = 'smbc_otsuka_branch';

  /// じぶん銀行 (預金 = 資産)。振替元/請求先/主口座になり得る cash-like 口座。
  static const String jibunBankAccountId = 'jibun_bank';

  /// じぶん銀行カードローン / じぶんローン (現金借入 = カードローン負債)。
  /// かつては [jibunBankAccountId] と同一 ID に潰れており、じぶん銀行(預金)を
  /// 振替元に選んでも保存 ID がこのカードローンを指して「原資未設定」に倒れる
  /// バグの原因だった (#part341)。両者は別 ID に分離する。
  static const String jibunBankCardLoanAccountId = 'jibun_bank_card_loan';
  // 旧・固定額(¥80,000)の組み込み資金移動タスクの ID。かつては毎ビルドで
  // 三井住友大塚→じぶん銀行の ¥80,000 移動を自動注入していたが、これは不足額と
  // 無関係の固定値で、給料の入金先がじぶん銀行のとき「給料入金 + 移動入金」の
  // 二重計上になり、逆に三井住友を ¥80,000 減らして幻の不足→逆方向の提案を
  // 生んでいた (ユーザー報告)。自動注入は撤去し、資金移動は不足額に上限が
  // 掛かる動的提案 (_buildTransferSuggestions) に一本化した。ID 定数は、過去に
  // 「完了」で退避された永続タスクを組み込み扱いと認識するためだけに残す。
  static const String auPayCardFundingTransferTaskId =
      'transfer_smbc_otsuka_to_jibun_aupay_card_funding';

  /// ハードコードされた既定固定費 (家賃/KDDI/水道/ガス) のデータ駆動定義。
  /// `buildWorkbook(includeDefaultFixedPayments: true)` で当月該当かつ未計上の
  /// ものだけを既定計上する。各値は上の `static const` を参照 (重複記述なし)。
  static const List<_BuiltInRecurringFixedCost> _builtInRecurringFixedCosts =
      <_BuiltInRecurringFixedCost>[
    _BuiltInRecurringFixedCost(
      accountId: kddiProviderAccountId,
      accountName: kddiProviderAccountName,
      monthlyAmount: kddiProviderMonthlyPaymentAmount,
      paymentDay: 25,
    ),
    _BuiltInRecurringFixedCost(
      accountId: rentAccountId,
      accountName: rentAccountName,
      monthlyAmount: rentMonthlyPaymentAmount,
      paymentDay: 25,
    ),
    _BuiltInRecurringFixedCost(
      accountId: waterBillAccountId,
      accountName: waterBillAccountName,
      monthlyAmount: waterBillBimonthlyPaymentAmount,
      paymentDay: waterBillPaymentDay,
      cadence: AssetRecurringFixedCostCadence.bimonthlyEvenMonth,
      sourceAccountId: smbcOtsukaBranchAccountId,
    ),
    _BuiltInRecurringFixedCost(
      accountId: gasBillAccountId,
      accountName: gasBillAccountName,
      monthlyAmount: gasBillMonthlyPaymentAmount,
      paymentDay: gasBillPaymentDay,
      sourceAccountId: smbcOtsukaBranchAccountId,
    ),
  ];

  const AssetLiabilityPlanningService();

  AssetLiabilityWorkbook buildWorkbook({
    required Map<String, double> latestSnapshot,
    required DateTime baseDate,
    Map<String, double> monthlyPaymentOverrides = const <String, double>{},
    Map<String, double> actualPaymentAmounts = const <String, double>{},
    Map<String, String> paymentDifferenceReasons = const <String, String>{},
    Map<String, double> annualRateOverrides = const <String, double>{},
    Map<String, int> paymentDayOverrides = const <String, int>{},
    Set<String> paidAccountNames = const <String>{},
    Set<String> billingConfirmedAccountIds = const <String>{},
    Map<String, String> paymentSourceAccountIds = const <String, String>{},
    Map<String, String> defaultPaymentSourceAccountIds =
        const <String, String>{},
    Map<String, String> defaultCardBillingAccountIds = const <String, String>{},
    Map<String, String> cardBillingAccountIds = const <String, String>{},
    Map<String, AssetLiabilityRevolvingCreditConfig> revolvingConfigs =
        const <String, AssetLiabilityRevolvingCreditConfig>{},
    Map<String, AssetCardUsagePolicy> cardUsagePolicies =
        const <String, AssetCardUsagePolicy>{},
    List<AssetLiabilityIncomePlan> incomePlans =
        const <AssetLiabilityIncomePlan>[],
    List<AssetLiabilityTransferTask> transferTasks =
        const <AssetLiabilityTransferTask>[],
    List<AssetLiabilityCardStatementLine> cardStatementLines =
        const <AssetLiabilityCardStatementLine>[],
    List<AssetRecurringFixedCost> recurringFixedCosts =
        const <AssetRecurringFixedCost>[],
    bool includeDefaultFixedPayments = false,
    // 給料日サイクルの基準日。null のとき従来どおり baseDate の暦月で集計(後方互換)。
    int? salaryDay,
  }) {
    // 既定固定費 (家賃/KDDI/水道/ガス) を当月該当の周期かつ未計上 (残高<0 の同 ID
    // 負債が無い) のものだけ抽出する。残高<0 限定の判定で正残高の同名資産
    // (家賃保証金/KDDIポイント/ガスト 等) が既定を誤抑止しないようにする。
    final applicableDefaultFixedCosts = includeDefaultFixedPayments
        ? _builtInRecurringFixedCosts
            .where(
              (cost) =>
                  cost.appliesToMonth(
                    _cycleTargetMonth(baseDate, salaryDay, cost.paymentDay),
                  ) &&
                  !_hasLiabilityAccountFor(latestSnapshot, cost.accountId),
            )
            .toList(growable: false)
        : const <_BuiltInRecurringFixedCost>[];
    final effectiveSnapshot = applicableDefaultFixedCosts.isEmpty
        ? latestSnapshot
        : _withDefaultFixedPayments(
            latestSnapshot,
            applicableDefaultFixedCosts,
          );
    final effectiveMonthlyPaymentOverrides = _withDefaultFixedPaymentOverrides(
      monthlyPaymentOverrides: monthlyPaymentOverrides,
      applicableDefaults: applicableDefaultFixedCosts,
    );
    final accounts = effectiveSnapshot.entries
        .where((entry) => entry.key.trim().isNotEmpty && entry.value != 0)
        .map(
          (entry) => _applyPaymentDayOverride(
            account: _classifyAccount(
              name: entry.key.trim(),
              balance: entry.value,
            ),
            paymentDayOverrides: paymentDayOverrides,
          ),
        )
        .toList()
      ..sort(_compareAccounts);
    // UI 登録の定期固定費を負債 (全額支払いの utility) として計上する。既定固定費
    // (家賃/KDDI/水道/ガス) と同じ扱いで、当月に該当する周期かつ同名/同IDの口座が
    // まだ無いものだけを追加する (手動計上や既定との二重計上を防ぐ)。
    final injectedFixedCosts = _buildRecurringFixedCostInjections(
      recurringFixedCosts: recurringFixedCosts,
      existingAccounts: accounts,
      baseDate: baseDate,
      salaryDay: salaryDay,
    );
    // 実際に注入されたサブスク区分の固定費口座 ID (dedup / 当月該当を反映済み)。
    // トリアージの「生命線を優先確保」から除外する。名前の再解決ではなく実注入
    // 口座 ID を使うことで、組み込み生命線 ID (rent/gas_bill 等) との部分一致衝突で
    // 本物の生命線を過剰除外する事故を避ける。
    final subscriptionFixedCostAccountIds = <String>{
      for (final injected in injectedFixedCosts)
        if (injected.isSubscription) injected.account.id,
    };
    if (injectedFixedCosts.isNotEmpty) {
      accounts
        ..addAll(injectedFixedCosts.map((injected) => injected.account))
        ..sort(_compareAccounts);
      // 利用者が金額を入力済み = 推定ではない (請求確認待ちにしない)。今月の手入力
      // 上書きがある場合はそれを優先する。
      for (final injected in injectedFixedCosts) {
        effectiveMonthlyPaymentOverrides.putIfAbsent(
          injected.account.id,
          () => injected.account.balance.abs(),
        );
      }
    }
    final accountsById = <String, AssetLiabilityAccount>{
      for (final account in accounts) account.id: account,
    };
    final resolvedIncomePlans = _resolveIncomePlans(
      incomePlans: incomePlans,
      accountsById: accountsById,
    );
    final resolvedTransferTasks = _resolveTransferTasks(
      transferTasks: transferTasks,
      accounts: accounts,
      accountsById: accountsById,
    );
    final effectivePaymentSourceAccountIds = <String, String>{
      // 既定固定費 (水道/ガス) の既定振替元は三井住友銀行大塚支店(ユーザー設定があれば下で上書き)。
      for (final cost in applicableDefaultFixedCosts)
        if (cost.sourceAccountId != null) cost.accountId: cost.sourceAccountId!,
      // UI 登録の定期固定費の振替元 (任意 / ユーザー個別設定があれば下で上書き)。
      for (final injected in injectedFixedCosts)
        if (injected.sourceAccountId != null &&
            injected.sourceAccountId!.isNotEmpty)
          injected.account.id: injected.sourceAccountId!,
      for (final e in defaultPaymentSourceAccountIds.entries)
        e.key: _migrateCollidedJibunSourceId(e.value, accountsById),
      for (final e in paymentSourceAccountIds.entries)
        e.key: _migrateCollidedJibunSourceId(e.value, accountsById),
    };

    final positiveAssetTotal = accounts.fold<double>(
      0,
      (sum, account) => account.balance > 0 ? sum + account.balance : sum,
    );
    final liabilityTotal = accounts.fold<double>(
      0,
      (sum, account) => account.balance < 0 ? sum + account.balance : sum,
    );
    final netWorth = positiveAssetTotal + liabilityTotal;
    final cashLikeTotal = accounts.fold<double>(
      0,
      (sum, account) => _isCashLike(account) ? sum + account.balance : sum,
    );
    final securitiesTotal = accounts.fold<double>(
      0,
      (sum, account) => account.kind == AssetLiabilityAccountKind.securities
          ? sum + account.balance
          : sum,
    );

    // リボカードの新規利用額は取込明細を正とする。明細が無いカードだけ設定の
    // 手入力値へフォールバックし、同じ利用額を二重加算しない。
    final cardStatementTotalsByBillingId = <String, double>{};
    for (final line in cardStatementLines) {
      final billingAccountId = line.billingAccountId.trim();
      if (billingAccountId.isEmpty) {
        continue;
      }
      cardStatementTotalsByBillingId.update(
        billingAccountId,
        (current) => current + line.amount,
        ifAbsent: () => line.amount,
      );
    }

    final debtMasterRows = accounts
        .where((account) => account.isLiability)
        .map(
          (account) => _buildDebtRow(
            account: account,
            liabilityTotal: liabilityTotal,
            monthlyPaymentOverrides: effectiveMonthlyPaymentOverrides,
            actualPaymentAmounts: actualPaymentAmounts,
            paymentDifferenceReasons: paymentDifferenceReasons,
            annualRateOverrides: annualRateOverrides,
            paidAccountNames: paidAccountNames,
            billingConfirmedAccountIds: billingConfirmedAccountIds,
            paymentSourceAccountIds: effectivePaymentSourceAccountIds,
            defaultCardBillingAccountIds: defaultCardBillingAccountIds,
            cardBillingAccountIds: cardBillingAccountIds,
            revolvingConfigs: revolvingConfigs,
            cardStatementTotalsByBillingId: cardStatementTotalsByBillingId,
            accountsById: accountsById,
          ),
        )
        .toList()
      ..sort((a, b) => b.balance.abs().compareTo(a.balance.abs()));

    final repaymentPriorityRows = List<AssetLiabilityDebtRow>.from(
      debtMasterRows,
    )..sort(_compareDebtPriority);

    final directDebtRows = debtMasterRows
        .where((row) => row.isDirectCashflowTarget)
        .toList(growable: false);
    final paymentDayRisks = _buildPaymentDayRisks(
      rows: directDebtRows,
      baseDate: baseDate,
      salaryDay: salaryDay,
    );
    final cashflowRows = _buildCashflowRows(
      rows: debtMasterRows,
      incomePlans: resolvedIncomePlans,
      baseDate: baseDate,
      salaryDay: salaryDay,
      startingCash: cashLikeTotal,
      paidAccountNames: paidAccountNames,
      paymentSourceAccountIds: effectivePaymentSourceAccountIds,
      accountsById: accountsById,
    );
    final accountCashflowSummaries = _buildAccountCashflowSummaries(
      accounts: accounts,
      cashflowRows: cashflowRows,
      transferTasks: resolvedTransferTasks,
    );
    final transferSuggestions = _buildTransferSuggestions(
      summaries: accountCashflowSummaries,
      cashflowRows: cashflowRows,
    );
    final cardBillingReview = _buildCardBillingReview(
      rows: debtMasterRows,
      accountsById: accountsById,
    );
    final cardStatementReconciliation = _buildCardStatementReconciliation(
      rows: debtMasterRows,
      cardBillingGroups: cardBillingReview.cardBillingGroups,
      cardStatementLines: cardStatementLines,
      accountsById: accountsById,
    );

    final monthlyMinimumPaymentEstimateTotal = directDebtRows.fold<double>(
      0,
      (sum, row) => sum + row.minimumPaymentEstimate,
    );
    final directPaymentCashflowRows = cashflowRows
        .where((row) => row.isPayment && row.isDirectCashflowTarget)
        .toList(growable: false);
    final monthlyScheduledPaymentTotal = directPaymentCashflowRows.fold<double>(
      0,
      (sum, row) => sum + row.paymentAmount,
    );
    final monthlyUnpaidPaymentTotal = directPaymentCashflowRows.fold<double>(
      0,
      (sum, row) => row.paid ? sum : sum + row.paymentAmount,
    );
    final monthlyActualPaymentTotal = directPaymentCashflowRows.fold<double>(
      0,
      (sum, row) =>
          row.paid ? sum + (row.actualPaymentAmount ?? row.paymentAmount) : sum,
    );
    final monthlyPaymentDifferenceTotal =
        directPaymentCashflowRows.fold<double>(
      0,
      (sum, row) => sum + (row.paymentDifferenceAmount ?? 0),
    );
    final monthlyUnreceivedIncomeTotal = resolvedIncomePlans.fold<double>(
      0,
      (sum, plan) => plan.received ? sum : sum + plan.amount,
    );
    final topFourDebtTotal = debtMasterRows
        .take(4)
        .fold<double>(0, (sum, row) => sum + row.balance.abs());
    final manualPaymentCount =
        directDebtRows.where((row) => !row.paymentAmountEstimated).length;
    final estimatedPaymentCount =
        directDebtRows.where((row) => row.paymentAmountEstimated).length;
    final cashAfterScheduledPayments = cashLikeTotal -
        monthlyUnpaidPaymentTotal +
        monthlyUnreceivedIncomeTotal;

    return AssetLiabilityWorkbook(
      baseDate: baseDate,
      accounts: accounts,
      debtMasterRows: debtMasterRows,
      repaymentPriorityRows: repaymentPriorityRows,
      paymentDayRisks: paymentDayRisks,
      cashflowRows: cashflowRows,
      incomePlans: resolvedIncomePlans,
      transferTasks: resolvedTransferTasks,
      accountCashflowSummaries: accountCashflowSummaries,
      transferSuggestions: transferSuggestions,
      cardBillingReview: cardBillingReview,
      cardStatementReconciliation: cardStatementReconciliation,
      cashLikeTotal: cashLikeTotal,
      securitiesTotal: securitiesTotal,
      positiveAssetTotal: positiveAssetTotal,
      liabilityTotal: liabilityTotal,
      netWorth: netWorth,
      monthlyMinimumPaymentEstimateTotal: monthlyMinimumPaymentEstimateTotal,
      monthlyScheduledPaymentTotal: monthlyScheduledPaymentTotal,
      monthlyUnpaidPaymentTotal: monthlyUnpaidPaymentTotal,
      monthlyActualPaymentTotal: monthlyActualPaymentTotal,
      monthlyPaymentDifferenceTotal: monthlyPaymentDifferenceTotal,
      monthlyUnreceivedIncomeTotal: monthlyUnreceivedIncomeTotal,
      cashAfterMinimumPayments: cashAfterScheduledPayments,
      cashAfterScheduledPayments: cashAfterScheduledPayments,
      debtToAssetRatio: positiveAssetTotal <= 0
          ? double.infinity
          : liabilityTotal.abs() / positiveAssetTotal,
      topFourDebtShare:
          liabilityTotal == 0 ? 0 : topFourDebtTotal / liabilityTotal.abs(),
      manualPaymentCount: manualPaymentCount,
      estimatedPaymentCount: estimatedPaymentCount,
      subscriptionFixedCostAccountIds: subscriptionFixedCostAccountIds,
      cardUsagePolicies: cardUsagePolicies,
    );
  }

  AssetLiabilityAccount _applyPaymentDayOverride({
    required AssetLiabilityAccount account,
    required Map<String, int> paymentDayOverrides,
  }) {
    if (!account.isLiability) {
      return account;
    }
    final override = paymentDayOverrides[account.id] ??
        paymentDayOverrides[account.name.trim()] ??
        paymentDayOverrides[account.name];
    if (override == null || override < 1 || override > 31) {
      return account;
    }
    return account.copyWith(paymentDay: override);
  }

  AssetLiabilityAccount _classifyAccount({
    required String name,
    required double balance,
  }) {
    final key = _normalize(name);

    if (balance > 0) {
      if (_containsAny(key, const <String>['証券', 'securities', 'stock'])) {
        return AssetLiabilityAccount(
          id: _accountIdForName(name),
          name: name,
          kind: AssetLiabilityAccountKind.securities,
          balance: balance,
        );
      }
      if (_containsAny(key, const <String>['財布', '現金', 'cash'])) {
        return AssetLiabilityAccount(
          id: _accountIdForName(name),
          name: name,
          kind: AssetLiabilityAccountKind.cash,
          balance: balance,
        );
      }
      if (_containsAny(key, const <String>['銀行', '支店', 'bank'])) {
        return AssetLiabilityAccount(
          id: _accountIdForName(name),
          name: name,
          kind: AssetLiabilityAccountKind.deposit,
          balance: balance,
        );
      }
      return AssetLiabilityAccount(
        id: _accountIdForName(name),
        name: name,
        kind: AssetLiabilityAccountKind.otherAsset,
        balance: balance,
      );
    }

    if (_containsAll(key, const <String>['アコム', 'ショッピング'])) {
      return _liability(
        name: name,
        balance: balance,
        kind: AssetLiabilityAccountKind.shoppingDebt,
        paymentDay: 8,
        annualRate: 0.15,
        minimumPaymentRate: 0.03,
        minimumPaymentFloor: 3000,
      );
    }
    if (_containsAll(key, const <String>['アコム', 'ローン'])) {
      return _consumerFinance(name: name, balance: balance, paymentDay: 8);
    }
    if (_containsAny(key, const <String>['モビット', 'mobit'])) {
      return _consumerFinance(name: name, balance: balance, paymentDay: 15);
    }
    if (_containsAny(key, const <String>['じぶん', 'jibun'])) {
      return _bankLoan(name: name, balance: balance, paymentDay: 27);
    }
    if (_accountIdForName(name) == 'smbc_card_loan') {
      return _bankLoan(name: name, balance: balance, paymentDay: 15);
    }
    if (_containsAll(key, const <String>['三井住友', 'cl'])) {
      return _bankLoan(name: name, balance: balance, paymentDay: 15);
    }
    if (_containsAny(key, const <String>['横浜銀行'])) {
      return _bankLoan(name: name, balance: balance, paymentDay: 15);
    }
    if (_containsAny(key, const <String>['aupay', 'aupayカード'])) {
      return _creditCard(name: name, balance: balance, paymentDay: 10);
    }
    if (_containsAny(key, const <String>['paypay'])) {
      return _creditCard(name: name, balance: balance, paymentDay: 27);
    }
    if (_containsAny(key, const <String>['ファミペイ', 'famipay'])) {
      return _creditCard(name: name, balance: balance, paymentDay: 27);
    }
    if (_accountIdForName(name) == kddiProviderAccountId) {
      return _liability(
        name: name,
        balance: balance,
        kind: AssetLiabilityAccountKind.utility,
        paymentDay: 25,
        annualRate: 0,
        minimumPaymentRate: 1,
        minimumPaymentFloor: balance.abs(),
        fullPaymentEstimate: true,
      );
    }
    if (_accountIdForName(name) == rentAccountId) {
      return _liability(
        name: name,
        balance: balance,
        kind: AssetLiabilityAccountKind.otherLiability,
        paymentDay: 25,
        annualRate: 0,
        minimumPaymentRate: 1,
        minimumPaymentFloor: balance.abs(),
        fullPaymentEstimate: true,
      );
    }
    if (_accountIdForName(name) == waterBillAccountId) {
      return _liability(
        name: name,
        balance: balance,
        kind: AssetLiabilityAccountKind.utility,
        paymentDay: waterBillPaymentDay,
        annualRate: 0,
        minimumPaymentRate: 1,
        minimumPaymentFloor: balance.abs(),
        fullPaymentEstimate: true,
      );
    }
    if (_accountIdForName(name) == gasBillAccountId) {
      return _liability(
        name: name,
        balance: balance,
        kind: AssetLiabilityAccountKind.utility,
        paymentDay: gasBillPaymentDay,
        annualRate: 0,
        minimumPaymentRate: 1,
        minimumPaymentFloor: balance.abs(),
        fullPaymentEstimate: true,
      );
    }
    if (key == 'au' || _containsAny(key, const <String>['通信', '携帯'])) {
      return _liability(
        name: name,
        balance: balance,
        kind: AssetLiabilityAccountKind.utility,
        paymentDay: 11,
        paymentMethod: AssetLiabilityPaymentMethod.includedInCard,
        paymentMethodLabel: auPayCardPaymentMethodLabel,
        billingAccountId: auPayCardAccountId,
        billingAccountName: auPayCardAccountName,
        includedInBillingAccount: true,
        annualRate: 0,
        minimumPaymentRate: 1,
        minimumPaymentFloor: balance.abs(),
        fullPaymentEstimate: true,
      );
    }
    if (_containsAny(key, const <String>['カード', 'card', 'クレカ'])) {
      return _creditCard(name: name, balance: balance, paymentDay: null);
    }
    if (_containsAny(key, const <String>['ローン', 'loan', '銀行'])) {
      return _bankLoan(name: name, balance: balance, paymentDay: null);
    }

    return _liability(
      name: name,
      balance: balance,
      kind: AssetLiabilityAccountKind.otherLiability,
      annualRate: 0.12,
      minimumPaymentRate: 0.03,
      minimumPaymentFloor: 3000,
    );
  }

  AssetLiabilityAccount _consumerFinance({
    required String name,
    required double balance,
    required int? paymentDay,
  }) =>
      _liability(
        name: name,
        balance: balance,
        kind: AssetLiabilityAccountKind.cardLoan,
        paymentDay: paymentDay,
        annualRate: 0.18,
        minimumPaymentRate: 0.04,
        minimumPaymentFloor: 4000,
      );

  AssetLiabilityAccount _bankLoan({
    required String name,
    required double balance,
    required int? paymentDay,
  }) =>
      _liability(
        name: name,
        balance: balance,
        kind: AssetLiabilityAccountKind.cardLoan,
        paymentDay: paymentDay,
        annualRate: 0.145,
        minimumPaymentRate: 0.03,
        minimumPaymentFloor: 3000,
      );

  AssetLiabilityAccount _creditCard({
    required String name,
    required double balance,
    required int? paymentDay,
  }) =>
      _liability(
        name: name,
        balance: balance,
        kind: AssetLiabilityAccountKind.creditCard,
        paymentDay: paymentDay,
        annualRate: 0.15,
        minimumPaymentRate: 0.03,
        minimumPaymentFloor: 3000,
      );

  AssetLiabilityAccount _liability({
    required String name,
    required double balance,
    required AssetLiabilityAccountKind kind,
    int? paymentDay,
    required double annualRate,
    required double minimumPaymentRate,
    required double minimumPaymentFloor,
    bool fullPaymentEstimate = false,
    AssetLiabilityPaymentMethod paymentMethod =
        AssetLiabilityPaymentMethod.direct,
    String? paymentMethodLabel,
    AssetLiabilityPaymentMethodSettingSource paymentMethodSettingSource =
        AssetLiabilityPaymentMethodSettingSource.builtInDefault,
    String? billingAccountId,
    String? billingAccountName,
    bool includedInBillingAccount = false,
  }) {
    final resolvedPaymentMethod = includedInBillingAccount
        ? AssetLiabilityPaymentMethod.includedInCard
        : paymentMethod;
    return AssetLiabilityAccount(
      id: _accountIdForName(name),
      name: name,
      kind: kind,
      balance: balance,
      paymentDay: paymentDay,
      paymentMethod: resolvedPaymentMethod,
      paymentMethodLabel: paymentMethodLabel,
      paymentMethodSettingSource: paymentMethodSettingSource,
      billingAccountId: billingAccountId,
      billingAccountName: billingAccountName,
      includedInBillingAccount:
          resolvedPaymentMethod == AssetLiabilityPaymentMethod.includedInCard,
      annualRate: annualRate,
      minimumPaymentRate: minimumPaymentRate,
      minimumPaymentFloor: minimumPaymentFloor,
      fullPaymentEstimate: fullPaymentEstimate,
    );
  }

  AssetLiabilityDebtRow _buildDebtRow({
    required AssetLiabilityAccount account,
    required double liabilityTotal,
    required Map<String, double> monthlyPaymentOverrides,
    required Map<String, double> actualPaymentAmounts,
    required Map<String, String> paymentDifferenceReasons,
    required Map<String, double> annualRateOverrides,
    required Set<String> paidAccountNames,
    required Set<String> billingConfirmedAccountIds,
    required Map<String, String> paymentSourceAccountIds,
    required Map<String, String> defaultCardBillingAccountIds,
    required Map<String, String> cardBillingAccountIds,
    required Map<String, AssetLiabilityRevolvingCreditConfig> revolvingConfigs,
    required Map<String, double> cardStatementTotalsByBillingId,
    required Map<String, AssetLiabilityAccount> accountsById,
  }) {
    final principal = account.liabilityBalance;
    final annualRate = _annualRateFor(
      account: account,
      annualRateOverrides: annualRateOverrides,
    );
    final interest = principal * annualRate / 12;
    final isBorrowing = account.kind == AssetLiabilityAccountKind.cardLoan ||
        account.kind == AssetLiabilityAccountKind.shoppingDebt ||
        account.kind == AssetLiabilityAccountKind.creditCard ||
        account.kind == AssetLiabilityAccountKind.mortgage;
    final minimumPayment = (!isBorrowing && account.fullPaymentEstimate)
        ? principal + interest
        : min(
            principal + interest,
            max(
              account.minimumPaymentFloor,
              principal * account.minimumPaymentRate,
            ),
          );
    final manualPayment = _manualPaymentAmountFor(
      account: account,
      monthlyPaymentOverrides: monthlyPaymentOverrides,
    );
    // リボ払いカードは「最低返済額 + 当月新規利用額」を25日に返す。
    // 既存残高は一括返済へ跳ね上げず、明細がある場合は新規利用額を自動反映する。
    final revolvingConfig = _revolvingConfigFor(
      account: account,
      revolvingConfigs: revolvingConfigs,
    );
    final importedNewUsage = cardStatementTotalsByBillingId[account.id] ??
        cardStatementTotalsByBillingId[account.name.trim()];
    final revolvingBilling = revolvingConfig == null
        ? null
        : const AssetRevolvingCreditService().computeBilling(
            balance: principal,
            config: revolvingConfig,
            newUsageAmount: importedNewUsage,
          );
    final scheduledPayment =
        revolvingBilling?.billedAmount ?? manualPayment ?? minimumPayment;
    final actualPayment = _actualPaymentAmountFor(
      account: account,
      actualPaymentAmounts: actualPaymentAmounts,
    );
    final paymentDifferenceReason = _paymentDifferenceReasonFor(
      account: account,
      paymentDifferenceReasons: paymentDifferenceReasons,
    );
    final principalPayment = max(0.0, scheduledPayment - interest);
    final afterPayment = -max(0.0, principal + interest - scheduledPayment);
    final rawPaymentSourceAccountId = paymentSourceAccountIds[account.id];
    // 振替元が自分自身を指す設定は不正 (ローンを自分自身からは返済できない) なので
    // 未設定扱いにする。これにより「支払原資口座の未設定」セクションに表示され、正しい
    // 口座 (例: じぶん銀行) へ修正できるようになり、見込み残高の自己宛て誤ルーティングも防ぐ。
    var paymentSourceAccountId = rawPaymentSourceAccountId == account.id
        ? null
        : rawPaymentSourceAccountId;
    // 振替元がカードローン (現金借入) を指す設定も不正扱いで未設定に落とす。
    // cardLoan はどの振替元セレクタにも候補として出ない (請求先になれない) のに、
    // legacy キー移行の名前衝突 (じぶん銀行→じぶんローン等) で保存され得る。
    // 非 null のままだと「原資未設定」レビューに出ず、現金系口座の見込み残高
    // からも静かに消える盲点になるため、未設定へ倒して修正導線に乗せる。
    if (paymentSourceAccountId != null &&
        accountsById[paymentSourceAccountId]?.kind ==
            AssetLiabilityAccountKind.cardLoan) {
      paymentSourceAccountId = null;
    }
    final paymentSourceAccountName = paymentSourceAccountId == null
        ? null
        : accountsById[paymentSourceAccountId]?.name;
    final paymentRouting = _paymentRoutingFor(
      account: account,
      defaultCardBillingAccountIds: defaultCardBillingAccountIds,
      cardBillingAccountIds: cardBillingAccountIds,
      accountsById: accountsById,
    );
    final paid = paidAccountNames.contains(account.id) ||
        paidAccountNames.contains(account.name.trim()) ||
        paidAccountNames.contains(account.name);
    final requiresAction = minimumPayment > 0 && scheduledPayment > 0 && !paid;

    return AssetLiabilityDebtRow(
      id: account.id,
      name: account.name,
      kind: account.kind,
      balance: account.balance,
      paymentDay: revolvingBilling?.paymentDay ?? account.paymentDay,
      paymentSourceAccountId: paymentSourceAccountId,
      paymentSourceAccountName: paymentSourceAccountName,
      paymentMethod: paymentRouting.paymentMethod,
      paymentMethodLabel: paymentRouting.paymentMethodLabel,
      paymentMethodSettingSource: paymentRouting.paymentMethodSettingSource,
      billingAccountId: paymentRouting.billingAccountId,
      billingAccountName: paymentRouting.billingAccountName,
      includedInBillingAccount: paymentRouting.includedInBillingAccount,
      annualRate: annualRate,
      minimumPaymentEstimate: minimumPayment,
      manualPaymentAmount: manualPayment,
      scheduledPaymentAmount: scheduledPayment,
      actualPaymentAmount: actualPayment,
      paymentDifferenceReason: paymentDifferenceReason,
      monthlyInterestEstimate: interest,
      principalPaymentEstimate: principalPayment,
      balanceAfterPaymentEstimate: afterPayment,
      liabilityShare:
          liabilityTotal == 0 ? 0 : principal / liabilityTotal.abs(),
      priorityLabel: _priorityLabel(annualRate),
      paymentAmountEstimated: revolvingBilling == null && manualPayment == null,
      fullPaymentEstimate: account.fullPaymentEstimate,
      revolvingBilling: revolvingBilling,
      billingConfirmed: _containsAccountKey(
        billingConfirmedAccountIds,
        account,
      ),
      paid: paid,
      requiresAction: requiresAction,
    );
  }

  bool _containsAccountKey(
    Set<String> accountKeys,
    AssetLiabilityAccount account,
  ) {
    return accountKeys.contains(account.id) ||
        accountKeys.contains(account.name.trim()) ||
        accountKeys.contains(account.name);
  }

  double _annualRateFor({
    required AssetLiabilityAccount account,
    required Map<String, double> annualRateOverrides,
  }) {
    final byId = annualRateOverrides[account.id];
    if (byId != null && DebtLockdownService.isRegistrableAnnualRate(byId)) {
      return byId;
    }
    final byTrimmedName = annualRateOverrides[account.name.trim()];
    if (byTrimmedName != null &&
        DebtLockdownService.isRegistrableAnnualRate(byTrimmedName)) {
      return byTrimmedName;
    }
    final byName = annualRateOverrides[account.name];
    if (byName != null && DebtLockdownService.isRegistrableAnnualRate(byName)) {
      return byName;
    }
    return account.annualRate;
  }

  _AssetLiabilityPaymentRouting _paymentRoutingFor({
    required AssetLiabilityAccount account,
    required Map<String, String> defaultCardBillingAccountIds,
    required Map<String, String> cardBillingAccountIds,
    required Map<String, AssetLiabilityAccount> accountsById,
  }) {
    final configuredBillingAccount = _configuredBillingAccountFor(
      account: account,
      defaultCardBillingAccountIds: defaultCardBillingAccountIds,
      cardBillingAccountIds: cardBillingAccountIds,
    );
    final configuredBillingAccountId = configuredBillingAccount?.accountId;
    if (configuredBillingAccountId == directPaymentMethodId) {
      return _AssetLiabilityPaymentRouting(
        paymentMethod: AssetLiabilityPaymentMethod.direct,
        paymentMethodSettingSource: configuredBillingAccount?.source ??
            AssetLiabilityPaymentMethodSettingSource.builtInDefault,
      );
    }

    final billingAccountId = configuredBillingAccountId ??
        (account.paymentMethod == AssetLiabilityPaymentMethod.includedInCard
            ? account.billingAccountId
            : null);
    if (billingAccountId == null || billingAccountId.trim().isEmpty) {
      return const _AssetLiabilityPaymentRouting(
        paymentMethod: AssetLiabilityPaymentMethod.direct,
      );
    }

    final billingAccountName = _billingAccountNameFor(
      billingAccountId: billingAccountId,
      accountsById: accountsById,
      fallbackName: account.billingAccountName,
    );
    final paymentMethodLabel = billingAccountId == auPayCardAccountId
        ? auPayCardPaymentMethodLabel
        : '${billingAccountName ?? billingAccountId}払い';
    return _AssetLiabilityPaymentRouting(
      paymentMethod: AssetLiabilityPaymentMethod.includedInCard,
      paymentMethodLabel: paymentMethodLabel,
      paymentMethodSettingSource: configuredBillingAccount?.source ??
          AssetLiabilityPaymentMethodSettingSource.builtInDefault,
      billingAccountId: billingAccountId,
      billingAccountName: billingAccountName,
    );
  }

  _ConfiguredCardBillingAccount? _configuredBillingAccountFor({
    required AssetLiabilityAccount account,
    required Map<String, String> defaultCardBillingAccountIds,
    required Map<String, String> cardBillingAccountIds,
  }) {
    final monthlyAccountId = _configuredBillingAccountIdFor(
      account: account,
      cardBillingAccountIds: cardBillingAccountIds,
    );
    if (monthlyAccountId != null) {
      return _ConfiguredCardBillingAccount(
        accountId: monthlyAccountId,
        source: AssetLiabilityPaymentMethodSettingSource.monthlyOverride,
      );
    }

    final defaultAccountId = _configuredBillingAccountIdFor(
      account: account,
      cardBillingAccountIds: defaultCardBillingAccountIds,
    );
    if (defaultAccountId != null) {
      return _ConfiguredCardBillingAccount(
        accountId: defaultAccountId,
        source: AssetLiabilityPaymentMethodSettingSource.defaultSetting,
      );
    }

    return null;
  }

  String? _configuredBillingAccountIdFor({
    required AssetLiabilityAccount account,
    required Map<String, String> cardBillingAccountIds,
  }) {
    for (final key in <String>[account.id, account.name.trim(), account.name]) {
      final value = cardBillingAccountIds[key]?.trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  static String paymentMethodSettingSourceLabel(
    AssetLiabilityPaymentMethodSettingSource source,
  ) {
    return switch (source) {
      AssetLiabilityPaymentMethodSettingSource.builtInDefault =>
        builtInPaymentMethodSettingLabel,
      AssetLiabilityPaymentMethodSettingSource.defaultSetting =>
        defaultPaymentMethodSettingLabel,
      AssetLiabilityPaymentMethodSettingSource.monthlyOverride =>
        monthlyPaymentMethodSettingLabel,
    };
  }

  String? _billingAccountNameFor({
    required String billingAccountId,
    required Map<String, AssetLiabilityAccount> accountsById,
    String? fallbackName,
  }) {
    final accountName = accountsById[billingAccountId]?.name;
    if (accountName != null && accountName.trim().isNotEmpty) {
      return accountName;
    }
    if (fallbackName != null && fallbackName.trim().isNotEmpty) {
      return fallbackName;
    }
    return switch (billingAccountId) {
      auPayCardAccountId => auPayCardAccountName,
      'paypay_card' => 'PayPayカード',
      'famipay_card' => 'ファミペイカード',
      _ => null,
    };
  }

  /// カード請求のまとめ先（請求ホスト）になれる口座種別か。
  /// クレジットカードに加え、アコムショッピング等のショッピング枠
  /// (shoppingDebt) も複数購入をまとめて請求するためホストとして許可する。
  static bool isCardBillingHostKind(AssetLiabilityAccountKind kind) =>
      kind == AssetLiabilityAccountKind.creditCard ||
      kind == AssetLiabilityAccountKind.shoppingDebt;

  AssetLiabilityCardBillingReviewData _buildCardBillingReview({
    required List<AssetLiabilityDebtRow> rows,
    required Map<String, AssetLiabilityAccount> accountsById,
  }) {
    final billingHostAccountIds = accountsById.values
        .where((account) => isCardBillingHostKind(account.kind))
        .map((account) => account.id)
        .toSet();
    final items = [
      for (final row in rows)
        _cardBillingReviewItemFor(
          row: row,
          billingHostAccountIds: billingHostAccountIds,
        ),
    ]..sort(_compareCardBillingReviewItems);

    final directPaymentItems = items
        .where((item) => item.directCashflowTarget)
        .toList(growable: false);
    final missingBillingAccountItems = items
        .where((item) => item.hasMissingBillingAccount)
        .toList(growable: false);
    final needsReviewItems =
        items.where((item) => item.needsReview).toList(growable: false);
    final cardBillingGroups = _cardBillingReviewGroups(items);
    final doubleCountingRiskItems = _doubleCountingRiskItems(items);

    return AssetLiabilityCardBillingReviewData(
      directPaymentItems: directPaymentItems,
      cardBillingGroups: cardBillingGroups,
      missingBillingAccountItems: missingBillingAccountItems,
      needsReviewItems: needsReviewItems,
      doubleCountingRiskItems: doubleCountingRiskItems,
    );
  }

  AssetLiabilityCardBillingReviewItem _cardBillingReviewItemFor({
    required AssetLiabilityDebtRow row,
    required Set<String> billingHostAccountIds,
  }) {
    final alerts = <String>[];
    if (row.includedInBillingAccount) {
      final billingAccountId = row.billingAccountId?.trim();
      if (billingAccountId == null || billingAccountId.isEmpty) {
        alerts.add(cardBillingReviewMissingBillingAccountAlert);
      } else if (!billingHostAccountIds.contains(billingAccountId)) {
        alerts.add(cardBillingReviewRemovedBillingAccountAlert);
      }
    }
    // 手入力の0円 (請求なし月) は正常値として許容し、推定値が0以下の場合のみ確認を促す。
    if (row.scheduledPaymentAmount <= 0 && row.paymentAmountEstimated) {
      alerts.add(cardBillingReviewZeroAmountAlert);
    }

    return AssetLiabilityCardBillingReviewItem(
      accountId: row.id,
      accountName: row.name,
      amount: row.scheduledPaymentAmount,
      paymentDay: row.paymentDay,
      paymentMethod: row.paymentMethod,
      paymentMethodLabel: row.includedInBillingAccount
          ? (row.paymentMethodLabel ?? cardBillingReviewIncludedLabel)
          : directPaymentLabel,
      paymentMethodSettingSource: row.paymentMethodSettingSource,
      billingAccountId: row.billingAccountId,
      billingAccountName: row.billingAccountName,
      includedInBillingAccount: row.includedInBillingAccount,
      directCashflowTarget: row.isDirectCashflowTarget,
      paid: row.paid,
      alerts: alerts,
    );
  }

  List<AssetLiabilityCardBillingGroup> _cardBillingReviewGroups(
    List<AssetLiabilityCardBillingReviewItem> items,
  ) {
    final grouped = <String, List<AssetLiabilityCardBillingReviewItem>>{};
    for (final item in items.where((item) => item.includedInBillingAccount)) {
      final key = item.billingAccountId?.trim().isNotEmpty ?? false
          ? item.billingAccountId!.trim()
          : cardBillingReviewUnsetLabel;
      grouped
          .putIfAbsent(key, () => <AssetLiabilityCardBillingReviewItem>[])
          .add(item);
    }

    final groups = [
      for (final entry in grouped.entries)
        AssetLiabilityCardBillingGroup(
          billingAccountId:
              entry.key == cardBillingReviewUnsetLabel ? '' : entry.key,
          billingAccountName: entry.value.first.billingAccountName ??
              cardBillingReviewUnsetLabel,
          items: entry.value..sort(_compareCardBillingReviewItems),
        ),
    ];
    groups.sort((a, b) => a.billingAccountName.compareTo(b.billingAccountName));
    return groups;
  }

  List<AssetLiabilityCardBillingReviewItem> _doubleCountingRiskItems(
    List<AssetLiabilityCardBillingReviewItem> items,
  ) {
    final itemsByAccountId =
        <String, List<AssetLiabilityCardBillingReviewItem>>{};
    for (final item in items) {
      itemsByAccountId
          .putIfAbsent(
            item.accountId,
            () => <AssetLiabilityCardBillingReviewItem>[],
          )
          .add(item);
    }

    final result = <AssetLiabilityCardBillingReviewItem>[];
    for (final accountItems in itemsByAccountId.values) {
      final hasDirect = accountItems.any((item) => item.directCashflowTarget);
      final hasCardBilled = accountItems.any(
        (item) => item.includedInBillingAccount,
      );
      if (hasDirect && hasCardBilled) {
        result.addAll(accountItems);
      }
    }
    result.sort(_compareCardBillingReviewItems);
    return result;
  }

  AssetLiabilityCardStatementReconciliationData
      _buildCardStatementReconciliation({
    required List<AssetLiabilityDebtRow> rows,
    required List<AssetLiabilityCardBillingGroup> cardBillingGroups,
    required List<AssetLiabilityCardStatementLine> cardStatementLines,
    required Map<String, AssetLiabilityAccount> accountsById,
  }) {
    final rowsById = <String, AssetLiabilityDebtRow>{
      for (final row in rows) row.id: row,
    };
    final groupsByBillingId = <String, AssetLiabilityCardBillingGroup>{
      for (final group in cardBillingGroups)
        if (group.billingAccountId.trim().isNotEmpty)
          group.billingAccountId: group,
    };
    final linesByBillingId = <String, List<AssetLiabilityCardStatementLine>>{};
    final unmatchedLines = <AssetLiabilityCardStatementLine>[];

    for (final line in cardStatementLines) {
      final billingAccountId = line.billingAccountId.trim();
      if (billingAccountId.isEmpty) {
        unmatchedLines.add(line);
        continue;
      }
      final billingAccountName = line.billingAccountName ??
          rowsById[billingAccountId]?.name ??
          accountsById[billingAccountId]?.name;
      final resolvedLine = line.copyWith(
        billingAccountId: billingAccountId,
        billingAccountName: billingAccountName,
      );
      linesByBillingId
          .putIfAbsent(
            billingAccountId,
            () => <AssetLiabilityCardStatementLine>[],
          )
          .add(resolvedLine);
    }

    final billingAccountIds =
        <String>{...groupsByBillingId.keys, ...linesByBillingId.keys}.toList()
          ..sort((a, b) {
            final nameA = rowsById[a]?.name ?? accountsById[a]?.name ?? a;
            final nameB = rowsById[b]?.name ?? accountsById[b]?.name ?? b;
            return nameA.compareTo(nameB);
          });

    final reconciliationGroups =
        <AssetLiabilityCardStatementReconciliationGroup>[];
    for (final billingAccountId in billingAccountIds) {
      final billingRow = rowsById[billingAccountId];
      final billingAccountName = billingRow?.name ??
          accountsById[billingAccountId]?.name ??
          groupsByBillingId[billingAccountId]?.billingAccountName ??
          billingAccountId;
      final group = groupsByBillingId[billingAccountId];
      final lines = List<AssetLiabilityCardStatementLine>.from(
        linesByBillingId[billingAccountId] ??
            const <AssetLiabilityCardStatementLine>[],
      )..sort(_compareCardStatementLines);
      final billedAmount = billingRow?.scheduledPaymentAmount ?? 0;
      final configuredDetailTotal = group?.totalAmount ?? 0;
      final statementLineTotal = lines.fold<double>(
        0,
        (sum, line) => sum + line.amount,
      );
      // リボ払いカードは最低返済額へ新規利用額を全額上乗せする。明細がある場合は
      // その合計が上乗せ額の正となるため、一括払い前提の不一致アラートは抑止し、
      // 内訳は revolvingBilling で説明する。
      final revolvingBilling = billingRow?.revolvingBilling;
      final isRevolving = revolvingBilling != null;
      final alerts = <String>[];
      // アラートは「何がずれているか」しか伝えないため、対応する修正
      // アクション（何をすれば解消するか＋差分金額）を同時に算出する。
      final fixActions = <AssetLiabilityCardStatementFixAction>[];

      if (billingRow == null) {
        alerts.add(cardStatementBillingAccountMissingAlert);
        fixActions.add(
          const AssetLiabilityCardStatementFixAction(
            kind: AssetLiabilityCardStatementFixActionKind.assignBillingAccount,
            title: cardStatementFixAssignBillingLabel,
            description: '請求先カード口座が見つかりません。負債マスタで請求先カードを選び直してください。',
          ),
        );
      }
      if (!isRevolving && lines.isEmpty && group != null) {
        alerts.add(cardStatementMissingImportAlert);
        // 請求先カード口座が無い(billingRow == null)場合、請求額はプレース
        // ホルダ0のため取り込みより先に請求先の再設定(assignBillingAccount)
        // を促す。取り込みアクションは請求額が実在するときだけ出す。
        if (billingRow != null) {
          fixActions.add(
            AssetLiabilityCardStatementFixAction(
              kind: AssetLiabilityCardStatementFixActionKind.importStatement,
              title: cardStatementFixImportLabel,
              description: 'カード明細を貼り付けて取り込むと、'
                  '請求額${_formatFixActionAbsoluteYen(billedAmount)}と内訳の照合ができます。',
            ),
          );
        }
      }
      if (!isRevolving &&
          lines.isNotEmpty &&
          _moneyDiffers(statementLineTotal, billedAmount)) {
        alerts.add(cardStatementAmountMismatchAlert);
        if (billingRow != null) {
          fixActions.add(
            AssetLiabilityCardStatementFixAction(
              kind:
                  AssetLiabilityCardStatementFixActionKind.reviewStatementLines,
              title: cardStatementFixReviewLinesLabel,
              description: '取込明細合計が請求額と'
                  '${_formatFixActionYen(statementLineTotal - billedAmount)}'
                  'ずれています。取り込み漏れ・重複行・対象月違いの明細を確認してください。',
              amount: statementLineTotal - billedAmount,
            ),
          );
        }
      }
      if (!isRevolving &&
          group != null &&
          billingRow != null &&
          _moneyDiffers(configuredDetailTotal, billedAmount)) {
        alerts.add(cardStatementConfiguredMismatchAlert);
        fixActions.add(
          AssetLiabilityCardStatementFixAction(
            kind: AssetLiabilityCardStatementFixActionKind
                .adjustConfiguredBreakdown,
            title: cardStatementFixAdjustBreakdownLabel,
            description: '設定済みカード内訳合計が請求額と'
                '${_formatFixActionYen(configuredDetailTotal - billedAmount)}'
                'ずれています。負債マスタの「支払い方式」で内訳の追加・除外、'
                '各行の今月支払予定額、またはカード側の請求額を見直してください。',
            amount: configuredDetailTotal - billedAmount,
          ),
        );
      }
      if (!isRevolving &&
          lines.isNotEmpty &&
          group != null &&
          _moneyDiffers(statementLineTotal, configuredDetailTotal)) {
        alerts.add(cardStatementImportedConfiguredMismatchAlert);
      }

      reconciliationGroups.add(
        AssetLiabilityCardStatementReconciliationGroup(
          billingAccountId: billingAccountId,
          billingAccountName: billingAccountName,
          billedAmount: billedAmount,
          configuredDetailTotal: configuredDetailTotal,
          statementLineTotal: statementLineTotal,
          configuredItems:
              group?.items ?? const <AssetLiabilityCardBillingReviewItem>[],
          statementLines: lines,
          alerts: alerts,
          fixActions: fixActions,
          revolvingBilling: revolvingBilling,
        ),
      );
    }

    return AssetLiabilityCardStatementReconciliationData(
      groups: reconciliationGroups,
      unmatchedStatementLines: unmatchedLines,
    );
  }

  bool _moneyDiffers(double a, double b) => (a - b).abs() >= 0.5;

  /// 修正アクションの説明文に使う符号付き差分円表記（例: +1,853円 / -947円）。
  String _formatFixActionYen(double value) {
    return '${value.round() < 0 ? '-' : '+'}'
        '${_formatFixActionAbsoluteYen(value)}';
  }

  /// 修正アクションの説明文に使う絶対額の円表記（例: 20,000円）。
  String _formatFixActionAbsoluteYen(double value) {
    final digits = value.round().abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(digits[i]);
    }
    return '$buffer円';
  }

  int _compareCardStatementLines(
    AssetLiabilityCardStatementLine a,
    AssetLiabilityCardStatementLine b,
  ) {
    final dateA = a.postedAt;
    final dateB = b.postedAt;
    if (dateA != null && dateB != null) {
      final date = dateA.compareTo(dateB);
      if (date != 0) {
        return date;
      }
    } else if (dateA != null) {
      return -1;
    } else if (dateB != null) {
      return 1;
    }
    return a.description.compareTo(b.description);
  }

  int _compareCardBillingReviewItems(
    AssetLiabilityCardBillingReviewItem a,
    AssetLiabilityCardBillingReviewItem b,
  ) {
    final day = (a.paymentDay ?? 99).compareTo(b.paymentDay ?? 99);
    if (day != 0) {
      return day;
    }
    return b.amount.compareTo(a.amount);
  }

  List<AssetLiabilityPaymentDayRisk> _buildPaymentDayRisks({
    required List<AssetLiabilityDebtRow> rows,
    required DateTime baseDate,
    int? salaryDay,
  }) {
    final byDayAndAction = <(int, bool), List<AssetLiabilityDebtRow>>{};
    for (final row in rows) {
      final day = row.paymentDay;
      if (day == null) {
        continue;
      }
      // 支払済みは当月分の支払いが完了済みのため、支払日別リスク(期限超過/要支払い)
      // からは物理除外する。アクションアイテム層が overdue を !row.paid で判定するのと
      // 整合させ、AI ナラティブが支払済みの負債を「期限超過」として指摘しないようにする。
      if (row.paid) {
        continue;
      }
      byDayAndAction.putIfAbsent((
        day,
        row.requiresAction,
        // ignore: require_trailing_commas
      ), () => <AssetLiabilityDebtRow>[]).add(row);
    }

    final result = <AssetLiabilityPaymentDayRisk>[];
    for (final entry in byDayAndAction.entries) {
      final day = entry.key.$1;
      final requiresAction = entry.key.$2;
      final paymentDate = _resolveCyclePaymentDate(baseDate, salaryDay, day);
      final rowsForDay = entry.value
        ..sort((a, b) => b.balance.abs().compareTo(a.balance.abs()));
      result.add(
        AssetLiabilityPaymentDayRisk(
          paymentDay: day,
          paymentDate: paymentDate,
          accountNames: rowsForDay.map((row) => row.name).toList(),
          balanceTotal: rowsForDay.fold<double>(
            0,
            (sum, row) => sum + row.balance,
          ),
          minimumPaymentEstimateTotal: rowsForDay.fold<double>(
            0,
            (sum, row) => sum + row.minimumPaymentEstimate,
          ),
          scheduledPaymentTotal: rowsForDay.fold<double>(
            0,
            (sum, row) => sum + row.scheduledPaymentAmount,
          ),
          manualPaymentTotal: rowsForDay.fold<double>(
            0,
            (sum, row) => sum + (row.manualPaymentAmount ?? 0),
          ),
          interestEstimateTotal: rowsForDay.fold<double>(
            0,
            (sum, row) => sum + row.monthlyInterestEstimate,
          ),
          manualPaymentCount:
              rowsForDay.where((row) => !row.paymentAmountEstimated).length,
          estimatedPaymentCount:
              rowsForDay.where((row) => row.paymentAmountEstimated).length,
          requiresAction: requiresAction,
          isPast: paymentDate.isBefore(_dateOnly(baseDate)),
          isToday: paymentDate == _dateOnly(baseDate),
        ),
      );
    }

    result.sort((a, b) {
      final dayComparison = a.paymentDay.compareTo(b.paymentDay);
      if (dayComparison != 0) {
        return dayComparison;
      }
      if (a.requiresAction == b.requiresAction) {
        return 0;
      }
      return a.requiresAction ? -1 : 1;
    });
    return result;
  }

  List<AssetLiabilityCashflowRow> _buildCashflowRows({
    required List<AssetLiabilityDebtRow> rows,
    required List<AssetLiabilityIncomePlan> incomePlans,
    required DateTime baseDate,
    required double startingCash,
    required Set<String> paidAccountNames,
    required Map<String, String> paymentSourceAccountIds,
    required Map<String, AssetLiabilityAccount> accountsById,
    int? salaryDay,
  }) {
    final result = <AssetLiabilityCashflowRow>[];
    for (final plan in incomePlans) {
      final paymentDate = _dateOnly(plan.date);
      result.add(
        AssetLiabilityCashflowRow(
          eventType: AssetLiabilityCashflowEventType.income,
          accountId: plan.id,
          accountName: plan.name,
          paymentDay: paymentDate.day,
          paymentDate: paymentDate,
          paymentSourceAccountId: null,
          paymentSourceAccountName: null,
          destinationAccountId: plan.destinationAccountId,
          destinationAccountName: plan.destinationAccountName,
          paymentMethod: AssetLiabilityPaymentMethod.direct,
          paymentMethodLabel: null,
          paymentMethodSettingSource:
              AssetLiabilityPaymentMethodSettingSource.builtInDefault,
          billingAccountId: null,
          billingAccountName: null,
          includedInBillingAccount: false,
          paymentAmount: plan.amount,
          actualPaymentAmount: null,
          paymentDifferenceAmount: null,
          paymentDifferenceReason: null,
          paymentAmountEstimated: false,
          paid: false,
          received: plan.received,
          overdue: !plan.received && !paymentDate.isAfter(_dateOnly(baseDate)),
          cashBeforePayment: 0,
          cashAfterPayment: 0,
          riskLevel: AssetLiabilityCashRiskLevel.normal,
        ),
      );
    }

    for (final row in rows.where((row) => row.paymentDay != null)) {
      final paymentDay = row.paymentDay!;
      final paymentDate = _resolveCyclePaymentDate(
        baseDate,
        salaryDay,
        paymentDay,
      );
      final overdue = row.isDirectCashflowTarget &&
          row.requiresAction &&
          !paymentDate.isAfter(_dateOnly(baseDate));
      result.add(
        AssetLiabilityCashflowRow(
          eventType: AssetLiabilityCashflowEventType.payment,
          accountId: row.id,
          accountName: row.name,
          paymentDay: paymentDay,
          paymentDate: paymentDate,
          paymentSourceAccountId: row.paymentSourceAccountId,
          paymentSourceAccountName: row.paymentSourceAccountName,
          destinationAccountId: null,
          destinationAccountName: row.includedInBillingAccount
              ? (row.paymentMethodLabel ?? row.billingAccountName)
              : null,
          paymentMethod: row.paymentMethod,
          paymentMethodLabel: row.paymentMethodLabel,
          paymentMethodSettingSource: row.paymentMethodSettingSource,
          billingAccountId: row.billingAccountId,
          billingAccountName: row.billingAccountName,
          includedInBillingAccount: row.includedInBillingAccount,
          paymentAmount: row.scheduledPaymentAmount,
          actualPaymentAmount: row.actualPaymentAmount,
          paymentDifferenceAmount: row.paymentDifferenceAmount,
          paymentDifferenceReason: row.paymentDifferenceReason,
          paymentAmountEstimated: row.paymentAmountEstimated,
          paid: row.paid,
          received: false,
          overdue: overdue,
          cashBeforePayment: 0,
          cashAfterPayment: 0,
          riskLevel: AssetLiabilityCashRiskLevel.normal,
        ),
      );
    }
    final acomShoppingRow = _findAcomShoppingDebtRow(rows);
    if (acomShoppingRow != null && acomShoppingRow.isDirectCashflowTarget) {
      const paymentDay = anthropicAcomShoppingPaymentDay;
      final paymentDate = _resolveCyclePaymentDate(
        baseDate,
        salaryDay,
        paymentDay,
      );
      final paid = paidAccountNames.contains(anthropicAcomShoppingPaymentId) ||
          paidAccountNames.contains(anthropicAcomShoppingPaymentName);
      // Anthropic サブスクはアコムショッピング枠に乗る購入であり、現金で別途
      // 返済しない (アコム最低返済で吸収される)。アコムショッピング請求に含む
      // 扱いにして、直接の現金支出として二重計上しないようにする。
      final acomBillingLabel = '${acomShoppingRow.name}払い';
      result.add(
        AssetLiabilityCashflowRow(
          eventType: AssetLiabilityCashflowEventType.payment,
          accountId: anthropicAcomShoppingPaymentId,
          accountName: anthropicAcomShoppingPaymentName,
          paymentDay: paymentDay,
          paymentDate: paymentDate,
          paymentSourceAccountId: null,
          paymentSourceAccountName: null,
          destinationAccountId: null,
          destinationAccountName: acomBillingLabel,
          paymentMethod: AssetLiabilityPaymentMethod.includedInCard,
          paymentMethodLabel: acomBillingLabel,
          paymentMethodSettingSource:
              AssetLiabilityPaymentMethodSettingSource.builtInDefault,
          billingAccountId: acomShoppingRow.id,
          billingAccountName: acomShoppingRow.name,
          includedInBillingAccount: true,
          paymentAmount: anthropicAcomShoppingPaymentAmount,
          actualPaymentAmount: null,
          paymentDifferenceAmount: null,
          paymentDifferenceReason: null,
          paymentAmountEstimated: false,
          paid: paid,
          received: false,
          overdue: false,
          cashBeforePayment: 0,
          cashAfterPayment: 0,
          riskLevel: AssetLiabilityCashRiskLevel.normal,
        ),
      );
    }

    result.sort((a, b) {
      final date = a.paymentDate.compareTo(b.paymentDate);
      if (date != 0) {
        return date;
      }
      if (a.eventType != b.eventType) {
        return a.isIncome ? -1 : 1;
      }
      return b.paymentAmount.compareTo(a.paymentAmount);
    });

    var runningCash = startingCash;
    return [
      for (final row in result)
        () {
          final before = runningCash;
          final delta = row.isIncome
              ? (row.received ? 0 : row.paymentAmount)
              : (!row.isDirectCashflowTarget || row.paid
                  ? 0
                  : -row.paymentAmount);
          final after = before + delta;
          runningCash = after;
          return AssetLiabilityCashflowRow(
            eventType: row.eventType,
            accountId: row.accountId,
            accountName: row.accountName,
            paymentDay: row.paymentDay,
            paymentDate: row.paymentDate,
            paymentSourceAccountId: row.paymentSourceAccountId,
            paymentSourceAccountName: row.paymentSourceAccountName,
            destinationAccountId: row.destinationAccountId,
            destinationAccountName: row.destinationAccountName,
            paymentMethod: row.paymentMethod,
            paymentMethodLabel: row.paymentMethodLabel,
            paymentMethodSettingSource: row.paymentMethodSettingSource,
            billingAccountId: row.billingAccountId,
            billingAccountName: row.billingAccountName,
            includedInBillingAccount: row.includedInBillingAccount,
            paymentAmount: row.paymentAmount,
            actualPaymentAmount: row.actualPaymentAmount,
            paymentDifferenceAmount: row.paymentDifferenceAmount,
            paymentDifferenceReason: row.paymentDifferenceReason,
            paymentAmountEstimated: row.paymentAmountEstimated,
            paid: row.paid,
            received: row.received,
            overdue: row.overdue,
            cashBeforePayment: before,
            cashAfterPayment: after,
            riskLevel: _cashRiskLevel(after),
          );
        }(),
    ];
  }

  AssetLiabilityDebtRow? _findAcomShoppingDebtRow(
    List<AssetLiabilityDebtRow> rows,
  ) {
    for (final row in rows) {
      if (row.id == acomShoppingAccountId) {
        return row;
      }
    }
    return null;
  }

  AssetLiabilityCashRiskLevel _cashRiskLevel(double cashAfterPayment) {
    if (cashAfterPayment < 0) {
      return AssetLiabilityCashRiskLevel.short;
    }
    if (cashAfterPayment < 10000) {
      return AssetLiabilityCashRiskLevel.caution;
    }
    if (cashAfterPayment < 30000) {
      return AssetLiabilityCashRiskLevel.watch;
    }
    return AssetLiabilityCashRiskLevel.normal;
  }

  List<AssetLiabilityIncomePlan> _resolveIncomePlans({
    required List<AssetLiabilityIncomePlan> incomePlans,
    required Map<String, AssetLiabilityAccount> accountsById,
  }) {
    final result = <AssetLiabilityIncomePlan>[];
    for (final plan in incomePlans) {
      final destination = plan.destinationAccountId == null
          ? null
          : accountsById[plan.destinationAccountId];
      result.add(
        AssetLiabilityIncomePlan(
          id: plan.id,
          date: _dateOnly(plan.date),
          name: plan.name,
          amount: plan.amount,
          destinationAccountId: plan.destinationAccountId,
          destinationAccountName:
              destination?.name ?? plan.destinationAccountName,
          received: plan.received,
        ),
      );
    }
    result.sort((a, b) => a.date.compareTo(b.date));
    return result;
  }

  List<AssetLiabilityTransferTask> _resolveTransferTasks({
    required List<AssetLiabilityTransferTask> transferTasks,
    required List<AssetLiabilityAccount> accounts,
    required Map<String, AssetLiabilityAccount> accountsById,
  }) {
    final result = <AssetLiabilityTransferTask>[];
    for (final task in transferTasks) {
      if (task.id.trim().isEmpty ||
          task.fromAccountId.trim().isEmpty ||
          task.toAccountId.trim().isEmpty ||
          task.fromAccountId == task.toAccountId ||
          task.amount <= 0) {
        continue;
      }
      final fromAccount =
          _findCashLikeAccountById(accounts, task.fromAccountId) ??
              accountsById[task.fromAccountId];
      final toAccount = _findCashLikeAccountById(accounts, task.toAccountId) ??
          accountsById[task.toAccountId];
      result.add(
        AssetLiabilityTransferTask(
          id: task.id,
          fromAccountId: task.fromAccountId,
          fromAccountName: fromAccount?.name ?? task.fromAccountName,
          toAccountId: task.toAccountId,
          toAccountName: toAccount?.name ?? task.toAccountName,
          amount: task.amount,
          dueDate: task.dueDate == null ? null : _dateOnly(task.dueDate!),
          completed: task.completed,
          completedAt: task.completedAt,
          completionMemo: task.completionMemo,
          canceled: task.canceled,
          canceledAt: task.canceledAt,
          cancellationReason: task.cancellationReason,
        ),
      );
    }
    result.sort((a, b) {
      final aDate = a.dueDate;
      final bDate = b.dueDate;
      if (aDate != null && bDate != null) {
        final date = aDate.compareTo(bDate);
        if (date != 0) {
          return date;
        }
      } else if (aDate != null) {
        return -1;
      } else if (bDate != null) {
        return 1;
      }
      return a.id.compareTo(b.id);
    });
    return result;
  }

  AssetLiabilityAccount? _findCashLikeAccountById(
    List<AssetLiabilityAccount> accounts,
    String accountId,
  ) {
    for (final account in accounts) {
      if (account.id == accountId && _isCashLike(account)) {
        return account;
      }
    }
    return null;
  }

  List<AssetLiabilityAccountCashflowSummary> _buildAccountCashflowSummaries({
    required List<AssetLiabilityAccount> accounts,
    required List<AssetLiabilityCashflowRow> cashflowRows,
    required List<AssetLiabilityTransferTask> transferTasks,
  }) {
    final cashLikeAccounts = accounts.where(_isCashLike).toList()
      ..sort((a, b) => b.balance.compareTo(a.balance));
    return [
      for (final account in cashLikeAccounts)
        () {
          final payments = cashflowRows.fold<double>(
            0,
            (sum, row) => row.isPayment &&
                    row.isDirectCashflowTarget &&
                    !row.paid &&
                    row.paymentSourceAccountId == account.id
                ? sum + row.paymentAmount
                : sum,
          );
          final income = cashflowRows.fold<double>(
            0,
            (sum, row) => row.isIncome &&
                    !row.received &&
                    row.destinationAccountId == account.id
                ? sum + row.paymentAmount
                : sum,
          );
          final pendingTransferIn = transferTasks.fold<double>(
            0,
            (sum, task) => !task.completed &&
                    !task.canceled &&
                    task.toAccountId == account.id
                ? sum + task.amount
                : sum,
          );
          final pendingTransferOut = transferTasks.fold<double>(
            0,
            (sum, task) => !task.completed &&
                    !task.canceled &&
                    task.fromAccountId == account.id
                ? sum + task.amount
                : sum,
          );
          final projected = account.balance -
              payments +
              income +
              pendingTransferIn -
              pendingTransferOut;
          return AssetLiabilityAccountCashflowSummary(
            accountId: account.id,
            accountName: account.name,
            currentBalance: account.balance,
            upcomingPayments: payments,
            upcomingIncome: income,
            pendingTransferIn: pendingTransferIn,
            pendingTransferOut: pendingTransferOut,
            projectedBalance: projected,
            riskLevel: _cashRiskLevel(projected),
          );
        }(),
    ];
  }

  /// 口座間移動の提案で、移動元に残しておく最低額。この額を割り込む提案は
  /// しない (移動元を新たな残高不足にしないため)。
  static const double _transferDonorReserve = 30000;

  List<AssetLiabilityTransferSuggestion> _buildTransferSuggestions({
    required List<AssetLiabilityAccountCashflowSummary> summaries,
    required List<AssetLiabilityCashflowRow> cashflowRows,
  }) {
    final donors = summaries
        .where(
          (summary) => summary.projectedBalance > _transferDonorReserve,
        )
        .toList()
      ..sort((a, b) => b.projectedBalance.compareTo(a.projectedBalance));
    final shortages = summaries.where((summary) => summary.isShort).toList()
      ..sort((a, b) => a.projectedBalance.compareTo(b.projectedBalance));

    final suggestions = <AssetLiabilityTransferSuggestion>[];
    for (final shortage in shortages) {
      // 移動元は「見込み残高に余裕がある」だけでは不十分で、**今この口座に
      // 実際にいくらあるか**で上限を掛ける必要がある。projectedBalance は
      // 未着金の収入 (給料/入金予定) を含むため、それだけで決めると
      // 「残高が無いのに移動を提案する」実行不能な提案になる (ユーザー報告:
      // じぶん銀行 現在¥18,918 に対し ¥50,041 の移動を提案していた)。
      // さらに移動予約済み (pendingTransferOut) は既に他へ約束済みなので、
      // 同じ資金を二重に当て込まないよう差し引く。
      AssetLiabilityAccountCashflowSummary? donor;
      var amount = 0.0;
      for (final candidate in donors) {
        if (candidate.accountId == shortage.accountId) {
          continue;
        }
        final donorSurplus = candidate.projectedBalance - _transferDonorReserve;
        if (donorSurplus <= 0) {
          continue;
        }
        final movableNow =
            candidate.currentBalance - candidate.pendingTransferOut;
        if (movableNow <= 0) {
          continue;
        }
        final feasible = min(min(shortage.shortfall, donorSurplus), movableNow);
        if (feasible <= 0) {
          continue;
        }
        donor = candidate;
        amount = feasible;
        break;
      }
      if (donor == null || amount <= 0) {
        continue;
      }
      suggestions.add(
        AssetLiabilityTransferSuggestion(
          fromAccountId: donor.accountId,
          fromAccountName: donor.accountName,
          toAccountId: shortage.accountId,
          toAccountName: shortage.accountName,
          amount: amount,
          neededBy: _firstNeededDateForAccount(
            shortage.accountId,
            cashflowRows,
          ),
        ),
      );
    }
    return suggestions;
  }

  DateTime? _firstNeededDateForAccount(
    String accountId,
    List<AssetLiabilityCashflowRow> cashflowRows,
  ) {
    for (final row in cashflowRows) {
      if (row.isPayment &&
          row.isDirectCashflowTarget &&
          !row.paid &&
          row.paymentSourceAccountId == accountId) {
        return row.paymentDate;
      }
    }
    return null;
  }

  int _compareAccounts(AssetLiabilityAccount a, AssetLiabilityAccount b) {
    if (a.isAsset != b.isAsset) {
      return a.isAsset ? -1 : 1;
    }
    return b.balance.abs().compareTo(a.balance.abs());
  }

  int _compareDebtPriority(AssetLiabilityDebtRow a, AssetLiabilityDebtRow b) {
    final rate = b.annualRate.compareTo(a.annualRate);
    if (rate != 0) {
      return rate;
    }
    return b.balance.abs().compareTo(a.balance.abs());
  }

  /// 旧 ID 衝突の移行: じぶん銀行(預金)がカードローンと同一 ID だった名残で、
  /// 振替元に旧衝突 ID (= 現在のカードローン ID) が保存されている場合、預金口座が
  /// 存在すればそちらへ読み替える。カードローンは支払原資になり得ないため、
  /// 保存値がカードローン ID を指すのは「じぶん銀行(預金)を選んだつもり」の
  /// 名残と解釈できる (#part341)。預金が無ければ元の値のまま
  /// (round-2 の cardLoan→未設定 正規化に委ねる)。
  String _migrateCollidedJibunSourceId(
    String sourceAccountId,
    Map<String, AssetLiabilityAccount> accountsById,
  ) {
    if (sourceAccountId == jibunBankCardLoanAccountId &&
        accountsById.containsKey(jibunBankAccountId)) {
      return jibunBankAccountId;
    }
    return sourceAccountId;
  }

  String _accountIdForName(String name) {
    final key = _normalize(name);

    if (_containsAll(key, const <String>['アコム', 'ショッピング'])) {
      return acomShoppingAccountId;
    }
    if (_containsAll(key, const <String>['アコム', 'ローン'])) {
      return 'acom_card_loan';
    }
    if (_containsAny(key, const <String>['モビット', 'mobit'])) {
      return 'mobit';
    }
    if (_containsAny(key, const <String>['じぶん', 'jibun'])) {
      // 「じぶん銀行」(預金) と「じぶん銀行カードローン/じぶんローン」(現金借入) は
      // 別口座。ローン語を含むものだけカードローン ID、それ以外は預金 ID にする。
      // 同一 ID だと accountsById で片方に潰れ、預金を振替元に選べない (#part341)。
      if (_containsAny(key, const <String>['ローン', 'loan'])) {
        return jibunBankCardLoanAccountId;
      }
      return jibunBankAccountId;
    }
    if (_containsAny(key, const <String>[
          'smbcカードローン',
          'smbccardloan',
          'smbccl',
        ]) ||
        _containsAll(key, const <String>['三井住友', 'cl']) ||
        _containsAll(key, const <String>['三井住友', 'カードローン'])) {
      return 'smbc_card_loan';
    }
    if (_containsAny(key, const <String>['横浜銀行'])) {
      return 'yokohama_bank';
    }
    if (_containsAny(key, const <String>['aupay'])) {
      return 'aupay_card';
    }
    if (_containsAny(key, const <String>['paypay'])) {
      return 'paypay_card';
    }
    if (_containsAny(key, const <String>['ファミペイ', 'famipay'])) {
      return 'famipay_card';
    }
    if (_containsAny(key, const <String>['kddi'])) {
      return kddiProviderAccountId;
    }
    if (key == 'rent' || _containsAny(key, const <String>['家賃'])) {
      return rentAccountId;
    }
    if (_containsAny(key, const <String>['水道', 'すいどう', 'water'])) {
      return waterBillAccountId;
    }
    if (_containsAny(key, const <String>['ガス', 'gas'])) {
      return gasBillAccountId;
    }
    if (key == 'au' || _containsAny(key, const <String>['通信', '携帯'])) {
      return 'au';
    }
    if (_containsAny(key, const <String>['三菱ufjeスマート証券', 'eスマート証券'])) {
      return 'mufg_esmart_securities';
    }
    if (_containsAny(key, const <String>['財布', 'wallet'])) {
      return 'wallet_cash';
    }
    if (_containsAll(key, const <String>['三井住友', '大塚'])) {
      return 'smbc_otsuka_branch';
    }
    if (_containsAll(key, const <String>['三井住友', '神田'])) {
      return 'smbc_kanda_branch';
    }

    return _fallbackAccountId(name);
  }

  /// UI 登録の定期固定費を、計上対象の負債口座 (+ 振替元口座 ID) へ変換する。
  ///
  /// 当月に該当する周期 (毎月/隔月) かつ金額>0 で、まだ同名/同IDの口座が無いものだけ
  /// を返す。`_liability` 経由で既定固定費 (水道/ガス) と同じ全額支払いの utility 負債
  /// として作る。振替元は呼び出し側で `effectivePaymentSourceAccountIds` に反映する。
  List<
      ({
        AssetLiabilityAccount account,
        String? sourceAccountId,
        bool isSubscription,
      })> _buildRecurringFixedCostInjections({
    required List<AssetRecurringFixedCost> recurringFixedCosts,
    required List<AssetLiabilityAccount> existingAccounts,
    required DateTime baseDate,
    int? salaryDay,
  }) {
    if (recurringFixedCosts.isEmpty) {
      return const <({
        AssetLiabilityAccount account,
        String? sourceAccountId,
        bool isSubscription,
      })>[];
    }
    final takenIds = existingAccounts.map((account) => account.id).toSet();
    final takenNames =
        existingAccounts.map((account) => _normalize(account.name)).toSet();
    final result = <({
      AssetLiabilityAccount account,
      String? sourceAccountId,
      bool isSubscription,
    })>[];
    for (final cost in recurringFixedCosts) {
      if (cost.amount <= 0 ||
          !cost.appliesToMonth(
            _cycleTargetMonth(baseDate, salaryDay, cost.paymentDay),
          )) {
        continue;
      }
      final account = _liability(
        name: cost.name,
        balance: -cost.amount,
        kind: AssetLiabilityAccountKind.utility,
        paymentDay: cost.paymentDay,
        annualRate: 0,
        minimumPaymentRate: 1,
        minimumPaymentFloor: cost.amount,
        fullPaymentEstimate: true,
      );
      if (takenIds.contains(account.id) ||
          takenNames.contains(_normalize(account.name))) {
        continue;
      }
      takenIds.add(account.id);
      takenNames.add(_normalize(account.name));
      result.add((
        account: account,
        sourceAccountId: cost.sourceAccountId,
        isSubscription:
            cost.category == AssetRecurringFixedCostCategory.subscription,
        // ignore: require_trailing_commas
      ));
    }
    return result;
  }

  Map<String, double> _withDefaultFixedPayments(
    Map<String, double> latestSnapshot,
    List<_BuiltInRecurringFixedCost> applicableDefaults,
  ) {
    final result = Map<String, double>.from(latestSnapshot);
    for (final cost in applicableDefaults) {
      result[cost.accountName] = -cost.monthlyAmount;
    }
    return result;
  }

  Map<String, double> _withDefaultFixedPaymentOverrides({
    required Map<String, double> monthlyPaymentOverrides,
    required List<_BuiltInRecurringFixedCost> applicableDefaults,
  }) {
    final result = <String, double>{...monthlyPaymentOverrides};
    for (final cost in applicableDefaults) {
      // ID キーでも名称キーでもユーザー上書きが無いときだけ既定額を補う
      // (名称キー上書きを既定額で shadow しないための両キーガード)。
      if (!result.containsKey(cost.accountId) &&
          !result.containsKey(cost.accountName)) {
        result[cost.accountId] = cost.monthlyAmount;
      }
    }
    return result;
  }

  // 同名の資産口座(例: 「家賃保証金」「KDDIポイント」「ガスト」)が既定固定費を
  // 誤って抑止しないよう、実際に負債(残高<0)の口座だけを「既存の請求あり」とみなす。
  // _accountIdForName の名寄せは部分一致で語境界を持たないため、残高の符号で
  // 本物の請求口座に限定する。既定固定費(家賃/KDDI/水道/ガス)は負債として計上される。
  bool _hasLiabilityAccountFor(Map<String, double> snapshot, String accountId) {
    return snapshot.entries.any(
      (entry) => entry.value < 0 && _accountIdForName(entry.key) == accountId,
    );
  }

  String _fallbackAccountId(String name) {
    final ascii = _normalize(name)
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    if (ascii.isNotEmpty) {
      return 'custom_$ascii';
    }

    var hash = 0x811c9dc5;
    for (final codeUnit in name.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return 'custom_${hash.toRadixString(16).padLeft(8, '0')}';
  }

  bool _isCashLike(AssetLiabilityAccount account) {
    return account.balance > 0 &&
        (account.kind == AssetLiabilityAccountKind.cash ||
            account.kind == AssetLiabilityAccountKind.deposit);
  }

  double? _manualPaymentAmountFor({
    required AssetLiabilityAccount account,
    required Map<String, double> monthlyPaymentOverrides,
  }) {
    final trimmedName = account.name.trim();
    final amount = monthlyPaymentOverrides[account.id] ??
        monthlyPaymentOverrides[trimmedName] ??
        monthlyPaymentOverrides[account.name];
    if (amount == null || amount < 0) {
      return null;
    }
    return amount;
  }

  AssetLiabilityRevolvingCreditConfig? _revolvingConfigFor({
    required AssetLiabilityAccount account,
    required Map<String, AssetLiabilityRevolvingCreditConfig> revolvingConfigs,
  }) {
    if (revolvingConfigs.isEmpty) {
      return null;
    }
    final trimmedName = account.name.trim();
    return revolvingConfigs[account.id] ??
        revolvingConfigs[trimmedName] ??
        revolvingConfigs[account.name];
  }

  double? _actualPaymentAmountFor({
    required AssetLiabilityAccount account,
    required Map<String, double> actualPaymentAmounts,
  }) {
    final trimmedName = account.name.trim();
    final amount = actualPaymentAmounts[account.id] ??
        actualPaymentAmounts[trimmedName] ??
        actualPaymentAmounts[account.name];
    if (amount == null || amount < 0) {
      return null;
    }
    return amount;
  }

  String? _paymentDifferenceReasonFor({
    required AssetLiabilityAccount account,
    required Map<String, String> paymentDifferenceReasons,
  }) {
    final trimmedName = account.name.trim();
    final reason = paymentDifferenceReasons[account.id] ??
        paymentDifferenceReasons[trimmedName] ??
        paymentDifferenceReasons[account.name];
    final trimmed = reason?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  String _priorityLabel(double annualRate) {
    if (annualRate >= 0.18) {
      return '最優先';
    }
    if (annualRate >= 0.15) {
      return '高';
    }
    if (annualRate > 0) {
      return '確認';
    }
    return '期日優先';
  }

  String _normalize(String source) {
    return source
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll('　', '');
  }

  bool _containsAny(String source, List<String> keywords) {
    for (final keyword in keywords) {
      if (source.contains(_normalize(keyword))) {
        return true;
      }
    }
    return false;
  }

  bool _containsAll(String source, List<String> keywords) {
    for (final keyword in keywords) {
      if (!source.contains(_normalize(keyword))) {
        return false;
      }
    }
    return true;
  }

  DateTime _dateOnly(DateTime source) {
    return DateTime(source.year, source.month, source.day);
  }

  /// 支払日 [dayOfMonth] の実日付を、[baseDate] を含む期間内で解決する。
  ///
  /// [salaryDay] が null のとき従来どおり [baseDate] の暦月で算出(後方互換)。
  /// 指定時は給料日サイクル `[salaryDay 〜 翌salaryDay-1]` で算出する:
  /// サイクルは 2 暦月にまたがり、支払日 >= salaryDay は第1暦月、未満は第2暦月に発生する
  /// (例 salaryDay=25 のサイクル 5/25〜6/24: 27日→5/27、10日→6/10)。
  /// 月末差異は対象暦月の末日にクランプする。
  DateTime _resolveCyclePaymentDate(
    DateTime baseDate,
    int? salaryDay,
    int dayOfMonth,
  ) {
    if (salaryDay == null) {
      final lastDay = DateTime(baseDate.year, baseDate.month + 1, 0).day;
      return DateTime(
        baseDate.year,
        baseDate.month,
        dayOfMonth.clamp(1, lastDay).toInt(),
      );
    }
    final anchor = salaryDay.clamp(1, 28).toInt();
    // サイクルの第1暦月 (baseDate.day >= anchor なら当月、未満なら前月)。
    final firstMonth = baseDate.day >= anchor
        ? DateTime(baseDate.year, baseDate.month)
        : DateTime(baseDate.year, baseDate.month - 1);
    final monthOffset = dayOfMonth >= anchor ? 0 : 1;
    final targetMonth = DateTime(
      firstMonth.year,
      firstMonth.month + monthOffset,
    );
    final lastDay = DateTime(targetMonth.year, targetMonth.month + 1, 0).day;
    return DateTime(
      targetMonth.year,
      targetMonth.month,
      dayOfMonth.clamp(1, lastDay).toInt(),
    );
  }

  /// 支払日 [dayOfMonth] が発生する暦月 (1-12) を返す。隔月固定費の偶奇判定に使う。
  /// [salaryDay] が null のとき [baseDate] の暦月。
  int _cycleTargetMonth(DateTime baseDate, int? salaryDay, int dayOfMonth) {
    if (salaryDay == null) {
      return baseDate.month;
    }
    return _resolveCyclePaymentDate(baseDate, salaryDay, dayOfMonth).month;
  }
}

class _AssetLiabilityPaymentRouting {
  final AssetLiabilityPaymentMethod paymentMethod;
  final String? paymentMethodLabel;
  final AssetLiabilityPaymentMethodSettingSource paymentMethodSettingSource;
  final String? billingAccountId;
  final String? billingAccountName;

  const _AssetLiabilityPaymentRouting({
    required this.paymentMethod,
    this.paymentMethodLabel,
    this.paymentMethodSettingSource =
        AssetLiabilityPaymentMethodSettingSource.builtInDefault,
    this.billingAccountId,
    this.billingAccountName,
  });

  bool get includedInBillingAccount =>
      paymentMethod == AssetLiabilityPaymentMethod.includedInCard;
}

class _ConfiguredCardBillingAccount {
  final String accountId;
  final AssetLiabilityPaymentMethodSettingSource source;

  const _ConfiguredCardBillingAccount({
    required this.accountId,
    required this.source,
  });
}
