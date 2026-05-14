import 'dart:math';

import '../models/asset_liability_workbook.dart';

class AssetLiabilityPlanningService {
  static const String auAccountId = 'au';
  static const String auPayCardAccountId = 'aupay_card';
  static const String auPayCardAccountName = 'auPayカード';
  static const String auPayCardPaymentMethodLabel = 'auPayカード払い';
  static const String cardBillingIncludedLabel = 'カード請求に含む';
  static const String auCardBillingNotice =
      'auはauPayカード払いのため、資金繰りではauPayカード請求に含めて扱います。';
  static const String kddiProviderAccountId = 'kddi_provider';
  static const String kddiProviderAccountName = 'KDDI';
  static const double kddiProviderMonthlyPaymentAmount = 5764;

  const AssetLiabilityPlanningService();

  AssetLiabilityWorkbook buildWorkbook({
    required Map<String, double> latestSnapshot,
    required DateTime baseDate,
    Map<String, double> monthlyPaymentOverrides = const <String, double>{},
    Set<String> paidAccountNames = const <String>{},
    Map<String, String> paymentSourceAccountIds = const <String, String>{},
    Map<String, String> defaultPaymentSourceAccountIds =
        const <String, String>{},
    List<AssetLiabilityIncomePlan> incomePlans =
        const <AssetLiabilityIncomePlan>[],
    bool includeDefaultFixedPayments = false,
  }) {
    final shouldIncludeDefaultKddiProvider =
        includeDefaultFixedPayments && !_hasKddiProvider(latestSnapshot);
    final effectiveSnapshot = shouldIncludeDefaultKddiProvider
        ? _withDefaultFixedPayments(latestSnapshot)
        : latestSnapshot;
    final effectiveMonthlyPaymentOverrides = _withDefaultFixedPaymentOverrides(
      monthlyPaymentOverrides: monthlyPaymentOverrides,
      includeDefaultKddiProvider: shouldIncludeDefaultKddiProvider,
    );
    final accounts = effectiveSnapshot.entries
        .where((entry) => entry.key.trim().isNotEmpty && entry.value != 0)
        .map(
          (entry) => _classifyAccount(
            name: entry.key.trim(),
            balance: entry.value,
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
    final effectivePaymentSourceAccountIds = <String, String>{
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
            paidAccountNames: paidAccountNames,
            paymentSourceAccountIds: effectivePaymentSourceAccountIds,
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
    );
    final accountCashflowSummaries = _buildAccountCashflowSummaries(
      accounts: accounts,
      cashflowRows: cashflowRows,
    );
    final transferSuggestions = _buildTransferSuggestions(
      summaries: accountCashflowSummaries,
      cashflowRows: cashflowRows,
    );

    final monthlyMinimumPaymentEstimateTotal = directDebtRows.fold<double>(
      0,
      (sum, row) => sum + row.minimumPaymentEstimate,
    );
    final monthlyScheduledPaymentTotal = directDebtRows.fold<double>(
      0,
      (sum, row) => sum + row.scheduledPaymentAmount,
    );
    final monthlyUnpaidPaymentTotal = directDebtRows.fold<double>(
      0,
      (sum, row) => row.paid ? sum : sum + row.scheduledPaymentAmount,
    );
    final monthlyUnreceivedIncomeTotal = resolvedIncomePlans.fold<double>(
      0,
      (sum, plan) => plan.received ? sum : sum + plan.amount,
    );
    final topFourDebtTotal = debtMasterRows.take(4).fold<double>(
          0,
          (sum, row) => sum + row.balance.abs(),
        );
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
      accountCashflowSummaries: accountCashflowSummaries,
      transferSuggestions: transferSuggestions,
      cashLikeTotal: cashLikeTotal,
      securitiesTotal: securitiesTotal,
      positiveAssetTotal: positiveAssetTotal,
      liabilityTotal: liabilityTotal,
      netWorth: netWorth,
      monthlyMinimumPaymentEstimateTotal: monthlyMinimumPaymentEstimateTotal,
      monthlyScheduledPaymentTotal: monthlyScheduledPaymentTotal,
      monthlyUnpaidPaymentTotal: monthlyUnpaidPaymentTotal,
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
      return _consumerFinance(
        name: name,
        balance: balance,
        paymentDay: 8,
      );
    }
    if (_containsAny(key, const <String>['モビット', 'mobit'])) {
      return _consumerFinance(
        name: name,
        balance: balance,
        paymentDay: 15,
      );
    }
    if (_containsAny(key, const <String>['じぶん', 'jibun'])) {
      return _bankLoan(
        name: name,
        balance: balance,
        paymentDay: 27,
      );
    }
    if (_accountIdForName(name) == 'smbc_card_loan') {
      return _bankLoan(
        name: name,
        balance: balance,
        paymentDay: 15,
      );
    }
    if (_containsAll(key, const <String>['三井住友', 'cl'])) {
      return _bankLoan(
        name: name,
        balance: balance,
        paymentDay: 15,
      );
    }
    if (_containsAny(key, const <String>['横浜銀行'])) {
      return _bankLoan(
        name: name,
        balance: balance,
        paymentDay: 15,
      );
    }
    if (_containsAny(key, const <String>['aupay', 'aupayカード'])) {
      return _creditCard(
        name: name,
        balance: balance,
        paymentDay: 10,
      );
    }
    if (_containsAny(key, const <String>['paypay'])) {
      return _creditCard(
        name: name,
        balance: balance,
        paymentDay: 27,
      );
    }
    if (_containsAny(key, const <String>['ファミペイ', 'famipay'])) {
      return _creditCard(
        name: name,
        balance: balance,
        paymentDay: 27,
      );
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
    if (key == 'au' || _containsAny(key, const <String>['通信', '携帯'])) {
      return _liability(
        name: name,
        balance: balance,
        kind: AssetLiabilityAccountKind.utility,
        paymentDay: 11,
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
      return _creditCard(
        name: name,
        balance: balance,
        paymentDay: null,
      );
    }
    if (_containsAny(key, const <String>['ローン', 'loan', '銀行'])) {
      return _bankLoan(
        name: name,
        balance: balance,
        paymentDay: null,
      );
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
    String? paymentMethodLabel,
    String? billingAccountId,
    String? billingAccountName,
    bool includedInBillingAccount = false,
  }) =>
      AssetLiabilityAccount(
        id: _accountIdForName(name),
        name: name,
        kind: kind,
        balance: balance,
        paymentDay: paymentDay,
        paymentMethodLabel: paymentMethodLabel,
        billingAccountId: billingAccountId,
        billingAccountName: billingAccountName,
        includedInBillingAccount: includedInBillingAccount,
        annualRate: annualRate,
        minimumPaymentRate: minimumPaymentRate,
        minimumPaymentFloor: minimumPaymentFloor,
        fullPaymentEstimate: fullPaymentEstimate,
      );

  AssetLiabilityDebtRow _buildDebtRow({
    required AssetLiabilityAccount account,
    required double liabilityTotal,
    required Map<String, double> monthlyPaymentOverrides,
    required Set<String> paidAccountNames,
    required Map<String, String> paymentSourceAccountIds,
    required Map<String, AssetLiabilityAccount> accountsById,
  }) {
    final principal = account.liabilityBalance;
    final interest = principal * account.annualRate / 12;
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
    final scheduledPayment = manualPayment ?? minimumPayment;
    final principalPayment = max(0.0, scheduledPayment - interest);
    final afterPayment = -max(0.0, principal + interest - scheduledPayment);
    final paymentSourceAccountId = paymentSourceAccountIds[account.id];
    final paymentSourceAccountName = paymentSourceAccountId == null
        ? null
        : accountsById[paymentSourceAccountId]?.name;

    return AssetLiabilityDebtRow(
      id: account.id,
      name: account.name,
      kind: account.kind,
      balance: account.balance,
      paymentDay: account.paymentDay,
      paymentSourceAccountId: paymentSourceAccountId,
      paymentSourceAccountName: paymentSourceAccountName,
      paymentMethodLabel: account.paymentMethodLabel,
      billingAccountId: account.billingAccountId,
      billingAccountName: account.billingAccountName,
      includedInBillingAccount: account.includedInBillingAccount,
      annualRate: account.annualRate,
      minimumPaymentEstimate: minimumPayment,
      manualPaymentAmount: manualPayment,
      scheduledPaymentAmount: scheduledPayment,
      monthlyInterestEstimate: interest,
      principalPaymentEstimate: principalPayment,
      balanceAfterPaymentEstimate: afterPayment,
      liabilityShare:
          liabilityTotal == 0 ? 0 : principal / liabilityTotal.abs(),
      priorityLabel: _priorityLabel(account.annualRate),
      paymentAmountEstimated: manualPayment == null,
      paid: paidAccountNames.contains(account.id) ||
          paidAccountNames.contains(account.name.trim()) ||
          paidAccountNames.contains(account.name),
    );
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
      byDay.putIfAbsent(day, () => <AssetLiabilityDebtRow>[]).add(row);
    }

    final result = <AssetLiabilityPaymentDayRisk>[];
    for (final entry in byDay.entries) {
      final day = entry.key;
      final lastDay = DateTime(baseDate.year, baseDate.month + 1, 0).day;
      final resolvedDay = day.clamp(1, lastDay).toInt();
      final paymentDate = DateTime(
        baseDate.year,
        baseDate.month,
        resolvedDay,
      );
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
          paymentMethodLabel: null,
          billingAccountId: null,
          billingAccountName: null,
          includedInBillingAccount: false,
          paymentAmount: plan.amount,
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
      final paymentDate = DateTime(
        baseDate.year,
        baseDate.month,
        resolvedDay,
      );
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
          paymentMethodLabel: row.paymentMethodLabel,
          billingAccountId: row.billingAccountId,
          billingAccountName: row.billingAccountName,
          includedInBillingAccount: row.includedInBillingAccount,
          paymentAmount: row.scheduledPaymentAmount,
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
            paymentMethodLabel: row.paymentMethodLabel,
            billingAccountId: row.billingAccountId,
            billingAccountName: row.billingAccountName,
            includedInBillingAccount: row.includedInBillingAccount,
            paymentAmount: row.paymentAmount,
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

  List<AssetLiabilityAccountCashflowSummary> _buildAccountCashflowSummaries({
    required List<AssetLiabilityAccount> accounts,
    required List<AssetLiabilityCashflowRow> cashflowRows,
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
          final projected = account.balance - payments + income;
          return AssetLiabilityAccountCashflowSummary(
            accountId: account.id,
            accountName: account.name,
            currentBalance: account.balance,
            upcomingPayments: payments,
            upcomingIncome: income,
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

  int _compareAccounts(
    AssetLiabilityAccount a,
    AssetLiabilityAccount b,
  ) {
    if (a.isAsset != b.isAsset) {
      return a.isAsset ? -1 : 1;
    }
    return b.balance.abs().compareTo(a.balance.abs());
  }

  int _compareDebtPriority(
    AssetLiabilityDebtRow a,
    AssetLiabilityDebtRow b,
  ) {
    final rate = b.annualRate.compareTo(a.annualRate);
    if (rate != 0) {
      return rate;
    }
    return b.balance.abs().compareTo(a.balance.abs());
  }

  String _accountIdForName(String name) {
    final key = _normalize(name);

    if (_containsAll(key, const <String>['アコム', 'ショッピング'])) {
      return 'acom_shopping';
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
    if (_containsAny(
          key,
          const <String>['smbcカードローン', 'smbccardloan', 'smbccl'],
        ) ||
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
    Map<String, double> latestSnapshot,
  ) {
    final result = Map<String, double>.from(latestSnapshot);
    if (!_hasKddiProvider(result)) {
      result[kddiProviderAccountName] = -kddiProviderMonthlyPaymentAmount;
    }
    return result;
  }

  Map<String, double> _withDefaultFixedPaymentOverrides({
    required Map<String, double> monthlyPaymentOverrides,
    required bool includeDefaultKddiProvider,
  }) {
    if (!includeDefaultKddiProvider ||
        monthlyPaymentOverrides.containsKey(kddiProviderAccountId) ||
        monthlyPaymentOverrides.containsKey(kddiProviderAccountName)) {
      return monthlyPaymentOverrides;
    }
    return <String, double>{
      kddiProviderAccountId: kddiProviderMonthlyPaymentAmount,
      ...monthlyPaymentOverrides,
    };
  }

  bool _hasKddiProvider(Map<String, double> snapshot) {
    return snapshot.keys.any(
      (name) => _accountIdForName(name) == kddiProviderAccountId,
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
