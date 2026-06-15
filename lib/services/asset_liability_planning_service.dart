import 'dart:math';

import 'package:my_web_app/services/debt_lockdown_service.dart';
import 'package:my_web_app/services/asset_revolving_credit_service.dart';

import '../models/asset_liability_workbook.dart';

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
  static const String jibunBankAccountId = 'jibun_bank_card_loan';
  static const String auPayCardFundingTransferTaskId =
      'transfer_smbc_otsuka_to_jibun_aupay_card_funding';
  static const int auPayCardFundingTransferDay = 26;
  static const double auPayCardFundingTransferAmount = 80000;

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
    List<AssetLiabilityIncomePlan> incomePlans =
        const <AssetLiabilityIncomePlan>[],
    List<AssetLiabilityTransferTask> transferTasks =
        const <AssetLiabilityTransferTask>[],
    List<AssetLiabilityCardStatementLine> cardStatementLines =
        const <AssetLiabilityCardStatementLine>[],
    bool includeDefaultFixedPayments = false,
  }) {
    final shouldIncludeDefaultKddiProvider =
        includeDefaultFixedPayments && !_hasKddiProvider(latestSnapshot);
    final shouldIncludeDefaultRent =
        includeDefaultFixedPayments && !_hasRent(latestSnapshot);
    // 水道代は2ヶ月に1回(偶数月の22日)。偶数月のみ既定で計上する。
    final shouldIncludeDefaultWaterBill = includeDefaultFixedPayments &&
        baseDate.month.isEven &&
        !_hasWaterBill(latestSnapshot);
    // ガス代は毎月12日。未計上時のみ既定で計上する。
    final shouldIncludeDefaultGasBill =
        includeDefaultFixedPayments && !_hasGasBill(latestSnapshot);
    final effectiveSnapshot = shouldIncludeDefaultKddiProvider ||
            shouldIncludeDefaultRent ||
            shouldIncludeDefaultWaterBill ||
            shouldIncludeDefaultGasBill
        ? _withDefaultFixedPayments(
            latestSnapshot,
            includeKddiProvider: shouldIncludeDefaultKddiProvider,
            includeRent: shouldIncludeDefaultRent,
            includeWaterBill: shouldIncludeDefaultWaterBill,
            includeGasBill: shouldIncludeDefaultGasBill,
          )
        : latestSnapshot;
    final effectiveMonthlyPaymentOverrides = _withDefaultFixedPaymentOverrides(
      monthlyPaymentOverrides: monthlyPaymentOverrides,
      includeDefaultKddiProvider: shouldIncludeDefaultKddiProvider,
      includeDefaultRent: shouldIncludeDefaultRent,
      includeDefaultWaterBill: shouldIncludeDefaultWaterBill,
      includeDefaultGasBill: shouldIncludeDefaultGasBill,
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
    final accountsById = <String, AssetLiabilityAccount>{
      for (final account in accounts) account.id: account,
    };
    final resolvedIncomePlans = _resolveIncomePlans(
      incomePlans: incomePlans,
      accountsById: accountsById,
    );
    final effectiveTransferTasks = _withDefaultAuPayCardFundingTransfer(
      transferTasks: transferTasks,
      accounts: accounts,
      baseDate: baseDate,
    );
    final resolvedTransferTasks = _resolveTransferTasks(
      transferTasks: effectiveTransferTasks,
      accounts: accounts,
      accountsById: accountsById,
    );
    final effectivePaymentSourceAccountIds = <String, String>{
      // 水道代・ガス代の既定振替元は三井住友銀行大塚支店(ユーザー設定があれば下で上書き)。
      if (shouldIncludeDefaultWaterBill)
        waterBillAccountId: smbcOtsukaBranchAccountId,
      if (shouldIncludeDefaultGasBill)
        gasBillAccountId: smbcOtsukaBranchAccountId,
      ...defaultPaymentSourceAccountIds,
      ...paymentSourceAccountIds,
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
    );
    final cashflowRows = _buildCashflowRows(
      rows: debtMasterRows,
      incomePlans: resolvedIncomePlans,
      baseDate: baseDate,
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
    required Map<String, AssetLiabilityAccount> accountsById,
  }) {
    final principal = account.liabilityBalance;
    final annualRate = _annualRateFor(
      account: account,
      annualRateOverrides: annualRateOverrides,
    );
    final interest = principal * annualRate / 12;
    final minimumPayment = account.fullPaymentEstimate
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
    // リボ払いカードは 請求額 = 設定額 + max(0, リボ残高 − 利用限度額) で確定する。
    // リボ残高は負債残高 (principal) を用い、手入力/推定額より優先する。
    final revolvingConfig = _revolvingConfigFor(
      account: account,
      revolvingConfigs: revolvingConfigs,
    );
    final revolvingBilling = revolvingConfig == null
        ? null
        : const AssetRevolvingCreditService().computeBilling(
            balance: principal,
            config: revolvingConfig,
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
    final paymentSourceAccountId = paymentSourceAccountIds[account.id];
    final paymentSourceAccountName = paymentSourceAccountId == null
        ? null
        : accountsById[paymentSourceAccountId]?.name;
    final paymentRouting = _paymentRoutingFor(
      account: account,
      defaultCardBillingAccountIds: defaultCardBillingAccountIds,
      cardBillingAccountIds: cardBillingAccountIds,
      accountsById: accountsById,
    );

    return AssetLiabilityDebtRow(
      id: account.id,
      name: account.name,
      kind: account.kind,
      balance: account.balance,
      paymentDay: account.paymentDay,
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
      paid: paidAccountNames.contains(account.id) ||
          paidAccountNames.contains(account.name.trim()) ||
          paidAccountNames.contains(account.name),
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

  AssetLiabilityCardBillingReviewData _buildCardBillingReview({
    required List<AssetLiabilityDebtRow> rows,
    required Map<String, AssetLiabilityAccount> accountsById,
  }) {
    final creditCardAccountIds = accountsById.values
        .where(
          (account) => account.kind == AssetLiabilityAccountKind.creditCard,
        )
        .map((account) => account.id)
        .toSet();
    final items = [
      for (final row in rows)
        _cardBillingReviewItemFor(
          row: row,
          creditCardAccountIds: creditCardAccountIds,
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
    required Set<String> creditCardAccountIds,
  }) {
    final alerts = <String>[];
    if (row.includedInBillingAccount) {
      final billingAccountId = row.billingAccountId?.trim();
      if (billingAccountId == null || billingAccountId.isEmpty) {
        alerts.add(cardBillingReviewMissingBillingAccountAlert);
      } else if (!creditCardAccountIds.contains(billingAccountId)) {
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
      // リボ払いカードは 請求額 = 設定額 + 限度額超過分 で決まり、利用明細(新規利用)は
      // リボ残高に積み増されるだけなので「明細合計 ≠ 請求額」が正常。一括払い前提の
      // 不一致アラートは抑止し、内訳は revolvingBilling で表示する。
      final revolvingBilling = billingRow?.revolvingBilling;
      final isRevolving = revolvingBilling != null;
      final alerts = <String>[];

      if (billingRow == null) {
        alerts.add(cardStatementBillingAccountMissingAlert);
      }
      if (!isRevolving && lines.isEmpty && group != null) {
        alerts.add(cardStatementMissingImportAlert);
      }
      if (!isRevolving &&
          lines.isNotEmpty &&
          _moneyDiffers(statementLineTotal, billedAmount)) {
        alerts.add(cardStatementAmountMismatchAlert);
      }
      if (!isRevolving &&
          group != null &&
          billingRow != null &&
          _moneyDiffers(configuredDetailTotal, billedAmount)) {
        alerts.add(cardStatementConfiguredMismatchAlert);
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
  }) {
    final byDay = <int, List<AssetLiabilityDebtRow>>{};
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
      byDay.putIfAbsent(day, () => <AssetLiabilityDebtRow>[]).add(row);
    }

    final result = <AssetLiabilityPaymentDayRisk>[];
    for (final entry in byDay.entries) {
      final day = entry.key;
      final lastDay = DateTime(baseDate.year, baseDate.month + 1, 0).day;
      final resolvedDay = day.clamp(1, lastDay).toInt();
      final paymentDate = DateTime(baseDate.year, baseDate.month, resolvedDay);
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
          isPast: paymentDate.isBefore(_dateOnly(baseDate)),
          isToday: paymentDate == _dateOnly(baseDate),
        ),
      );
    }

    result.sort((a, b) => a.paymentDay.compareTo(b.paymentDay));
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
  }) {
    final lastDay = DateTime(baseDate.year, baseDate.month + 1, 0).day;
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
      final resolvedDay = paymentDay.clamp(1, lastDay).toInt();
      final paymentDate = DateTime(baseDate.year, baseDate.month, resolvedDay);
      final overdue = row.isDirectCashflowTarget &&
          !row.paid &&
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
      final resolvedDay = paymentDay.clamp(1, lastDay).toInt();
      final paymentDate = DateTime(baseDate.year, baseDate.month, resolvedDay);
      final paid = paidAccountNames.contains(anthropicAcomShoppingPaymentId) ||
          paidAccountNames.contains(anthropicAcomShoppingPaymentName);
      final sourceAccountId =
          paymentSourceAccountIds[anthropicAcomShoppingPaymentId] ??
              acomShoppingRow.paymentSourceAccountId;
      final sourceAccountName = sourceAccountId == null
          ? acomShoppingRow.paymentSourceAccountName
          : accountsById[sourceAccountId]?.name ??
              acomShoppingRow.paymentSourceAccountName;
      result.add(
        AssetLiabilityCashflowRow(
          eventType: AssetLiabilityCashflowEventType.payment,
          accountId: anthropicAcomShoppingPaymentId,
          accountName: anthropicAcomShoppingPaymentName,
          paymentDay: paymentDay,
          paymentDate: paymentDate,
          paymentSourceAccountId: sourceAccountId,
          paymentSourceAccountName: sourceAccountName,
          destinationAccountId: acomShoppingRow.id,
          destinationAccountName: acomShoppingRow.name,
          paymentMethod: AssetLiabilityPaymentMethod.direct,
          paymentMethodLabel: acomShoppingRow.paymentMethodLabel,
          paymentMethodSettingSource:
              AssetLiabilityPaymentMethodSettingSource.builtInDefault,
          billingAccountId: null,
          billingAccountName: null,
          includedInBillingAccount: false,
          paymentAmount: anthropicAcomShoppingPaymentAmount,
          actualPaymentAmount: null,
          paymentDifferenceAmount: null,
          paymentDifferenceReason: null,
          paymentAmountEstimated: false,
          paid: paid,
          received: false,
          overdue: !paid && !paymentDate.isAfter(_dateOnly(baseDate)),
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

  List<AssetLiabilityTransferTask> _withDefaultAuPayCardFundingTransfer({
    required List<AssetLiabilityTransferTask> transferTasks,
    required List<AssetLiabilityAccount> accounts,
    required DateTime baseDate,
  }) {
    if (transferTasks.any(
      (task) => task.id == auPayCardFundingTransferTaskId,
    )) {
      return transferTasks;
    }

    final fromAccount = _findCashLikeAccountById(
      accounts,
      smbcOtsukaBranchAccountId,
    );
    final toAccount = _findCashLikeAccountById(accounts, jibunBankAccountId);
    if (fromAccount == null || toAccount == null) {
      return transferTasks;
    }

    final lastDay = DateTime(baseDate.year, baseDate.month + 1, 0).day;
    final resolvedDay = auPayCardFundingTransferDay.clamp(1, lastDay).toInt();
    return <AssetLiabilityTransferTask>[
      ...transferTasks,
      AssetLiabilityTransferTask(
        id: auPayCardFundingTransferTaskId,
        fromAccountId: fromAccount.id,
        fromAccountName: fromAccount.name,
        toAccountId: toAccount.id,
        toAccountName: toAccount.name,
        amount: auPayCardFundingTransferAmount,
        dueDate: DateTime(baseDate.year, baseDate.month, resolvedDay),
      ),
    ];
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

  List<AssetLiabilityTransferSuggestion> _buildTransferSuggestions({
    required List<AssetLiabilityAccountCashflowSummary> summaries,
    required List<AssetLiabilityCashflowRow> cashflowRows,
  }) {
    final donors = summaries
        .where((summary) => summary.projectedBalance > 30000)
        .toList()
      ..sort((a, b) => b.projectedBalance.compareTo(a.projectedBalance));
    final shortages = summaries.where((summary) => summary.isShort).toList()
      ..sort((a, b) => a.projectedBalance.compareTo(b.projectedBalance));

    final suggestions = <AssetLiabilityTransferSuggestion>[];
    for (final shortage in shortages) {
      final donor = donors.firstWhere(
        (summary) => summary.accountId != shortage.accountId,
        orElse: () => const AssetLiabilityAccountCashflowSummary(
          accountId: '',
          accountName: '',
          currentBalance: 0,
          upcomingPayments: 0,
          upcomingIncome: 0,
          projectedBalance: 0,
          riskLevel: AssetLiabilityCashRiskLevel.short,
        ),
      );
      if (donor.accountId.isEmpty) {
        continue;
      }
      final donorSurplus = donor.projectedBalance - 30000;
      if (donorSurplus <= 0) {
        continue;
      }
      final amount = min(shortage.shortfall, donorSurplus);
      if (amount <= 0) {
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
      return 'jibun_bank_card_loan';
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

  Map<String, double> _withDefaultFixedPayments(
    Map<String, double> latestSnapshot, {
    required bool includeKddiProvider,
    required bool includeRent,
    required bool includeWaterBill,
    required bool includeGasBill,
  }) {
    final result = Map<String, double>.from(latestSnapshot);
    if (includeKddiProvider && !_hasKddiProvider(result)) {
      result[kddiProviderAccountName] = -kddiProviderMonthlyPaymentAmount;
    }
    if (includeRent && !_hasRent(result)) {
      result[rentAccountName] = -rentMonthlyPaymentAmount;
    }
    if (includeWaterBill && !_hasWaterBill(result)) {
      result[waterBillAccountName] = -waterBillBimonthlyPaymentAmount;
    }
    if (includeGasBill && !_hasGasBill(result)) {
      result[gasBillAccountName] = -gasBillMonthlyPaymentAmount;
    }
    return result;
  }

  Map<String, double> _withDefaultFixedPaymentOverrides({
    required Map<String, double> monthlyPaymentOverrides,
    required bool includeDefaultKddiProvider,
    required bool includeDefaultRent,
    required bool includeDefaultWaterBill,
    required bool includeDefaultGasBill,
  }) {
    final result = <String, double>{...monthlyPaymentOverrides};
    if (includeDefaultKddiProvider &&
        !result.containsKey(kddiProviderAccountId) &&
        !result.containsKey(kddiProviderAccountName)) {
      result[kddiProviderAccountId] = kddiProviderMonthlyPaymentAmount;
    }
    if (includeDefaultRent &&
        !result.containsKey(rentAccountId) &&
        !result.containsKey(rentAccountName)) {
      result[rentAccountId] = rentMonthlyPaymentAmount;
    }
    if (includeDefaultWaterBill &&
        !result.containsKey(waterBillAccountId) &&
        !result.containsKey(waterBillAccountName)) {
      result[waterBillAccountId] = waterBillBimonthlyPaymentAmount;
    }
    if (includeDefaultGasBill &&
        !result.containsKey(gasBillAccountId) &&
        !result.containsKey(gasBillAccountName)) {
      result[gasBillAccountId] = gasBillMonthlyPaymentAmount;
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

  bool _hasKddiProvider(Map<String, double> snapshot) {
    return _hasLiabilityAccountFor(snapshot, kddiProviderAccountId);
  }

  bool _hasRent(Map<String, double> snapshot) {
    return _hasLiabilityAccountFor(snapshot, rentAccountId);
  }

  bool _hasWaterBill(Map<String, double> snapshot) {
    return _hasLiabilityAccountFor(snapshot, waterBillAccountId);
  }

  bool _hasGasBill(Map<String, double> snapshot) {
    return _hasLiabilityAccountFor(snapshot, gasBillAccountId);
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
