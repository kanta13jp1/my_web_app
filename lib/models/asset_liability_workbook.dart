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

class AssetLiabilityAccount {
  final String id;
  final String name;
  final AssetLiabilityAccountKind kind;
  final double balance;
  final int? paymentDay;
  final String? paymentSourceAccountName;
  final String? paymentMethodLabel;
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
    this.paymentMethodLabel,
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
}

class AssetLiabilityDebtRow {
  final String id;
  final String name;
  final AssetLiabilityAccountKind kind;
  final double balance;
  final int? paymentDay;
  final String? paymentSourceAccountId;
  final String? paymentSourceAccountName;
  final String? paymentMethodLabel;
  final String? billingAccountId;
  final String? billingAccountName;
  final bool includedInBillingAccount;
  final double annualRate;
  final double minimumPaymentEstimate;
  final double? manualPaymentAmount;
  final double scheduledPaymentAmount;
  final double monthlyInterestEstimate;
  final double principalPaymentEstimate;
  final double balanceAfterPaymentEstimate;
  final double liabilityShare;
  final String priorityLabel;
  final bool paymentAmountEstimated;
  final bool paid;

  const AssetLiabilityDebtRow({
    required this.id,
    required this.name,
    required this.kind,
    required this.balance,
    required this.paymentDay,
    required this.paymentSourceAccountId,
    required this.paymentSourceAccountName,
    required this.paymentMethodLabel,
    required this.billingAccountId,
    required this.billingAccountName,
    required this.includedInBillingAccount,
    required this.annualRate,
    required this.minimumPaymentEstimate,
    required this.manualPaymentAmount,
    required this.scheduledPaymentAmount,
    required this.monthlyInterestEstimate,
    required this.principalPaymentEstimate,
    required this.balanceAfterPaymentEstimate,
    required this.liabilityShare,
    required this.priorityLabel,
    required this.paymentAmountEstimated,
    required this.paid,
  });

  bool get isDirectCashflowTarget => !includedInBillingAccount;
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
  final String? paymentMethodLabel;
  final String? billingAccountId;
  final String? billingAccountName;
  final bool includedInBillingAccount;
  final double paymentAmount;
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
    required this.paymentMethodLabel,
    required this.billingAccountId,
    required this.billingAccountName,
    required this.includedInBillingAccount,
    required this.paymentAmount,
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
  bool get isDirectCashflowTarget => !includedInBillingAccount;
}

class AssetLiabilityAccountCashflowSummary {
  final String accountId;
  final String accountName;
  final double currentBalance;
  final double upcomingPayments;
  final double upcomingIncome;
  final double projectedBalance;
  final AssetLiabilityCashRiskLevel riskLevel;

  const AssetLiabilityAccountCashflowSummary({
    required this.accountId,
    required this.accountName,
    required this.currentBalance,
    required this.upcomingPayments,
    required this.upcomingIncome,
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
  final int overduePaymentCount;

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
    required this.overduePaymentCount,
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

class AssetLiabilityCsvExportBundle {
  final String monthlyHistoryCsv;
  final String paymentScheduleCsv;
  final String incomePlansCsv;
  final String accountCashflowCsv;

  const AssetLiabilityCsvExportBundle({
    required this.monthlyHistoryCsv,
    required this.paymentScheduleCsv,
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
  final List<AssetLiabilityAccountCashflowSummary> accountCashflowSummaries;
  final List<AssetLiabilityTransferSuggestion> transferSuggestions;
  final double cashLikeTotal;
  final double securitiesTotal;
  final double positiveAssetTotal;
  final double liabilityTotal;
  final double netWorth;
  final double monthlyMinimumPaymentEstimateTotal;
  final double monthlyScheduledPaymentTotal;
  final double monthlyUnpaidPaymentTotal;
  final double monthlyUnreceivedIncomeTotal;
  final double cashAfterMinimumPayments;
  final double cashAfterScheduledPayments;
  final double debtToAssetRatio;
  final double topFourDebtShare;
  final int manualPaymentCount;
  final int estimatedPaymentCount;

  const AssetLiabilityWorkbook({
    required this.baseDate,
    required this.accounts,
    required this.debtMasterRows,
    required this.repaymentPriorityRows,
    required this.paymentDayRisks,
    required this.cashflowRows,
    required this.incomePlans,
    required this.accountCashflowSummaries,
    required this.transferSuggestions,
    required this.cashLikeTotal,
    required this.securitiesTotal,
    required this.positiveAssetTotal,
    required this.liabilityTotal,
    required this.netWorth,
    required this.monthlyMinimumPaymentEstimateTotal,
    required this.monthlyScheduledPaymentTotal,
    required this.monthlyUnpaidPaymentTotal,
    required this.monthlyUnreceivedIncomeTotal,
    required this.cashAfterMinimumPayments,
    required this.cashAfterScheduledPayments,
    required this.debtToAssetRatio,
    required this.topFourDebtShare,
    required this.manualPaymentCount,
    required this.estimatedPaymentCount,
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
}
