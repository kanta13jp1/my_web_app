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
    final accountId = json['accountId']?.toString().trim() ??
        json['account_id']?.toString().trim();
    final fileName = json['fileName']?.toString().trim() ??
        json['file_name']?.toString().trim();
    final mimeType = json['mimeType']?.toString().trim() ??
        json['mime_type']?.toString().trim();
    final submittedAtText =
        json['submittedAt']?.toString() ?? json['submitted_at']?.toString();
    final submittedAt =
        submittedAtText == null ? null : DateTime.tryParse(submittedAtText);
    final submittedAnnualRate = _parseEvidenceDouble(
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
    final error =
        rawError == null || rawError.trim().isEmpty ? null : rawError.trim();
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
  });

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

class AssetLiabilityCardStatementReconciliationGroup {
  final String billingAccountId;
  final String billingAccountName;
  final double billedAmount;
  final double configuredDetailTotal;
  final double statementLineTotal;
  final List<AssetLiabilityCardBillingReviewItem> configuredItems;
  final List<AssetLiabilityCardStatementLine> statementLines;
  final List<String> alerts;

  const AssetLiabilityCardStatementReconciliationGroup({
    required this.billingAccountId,
    required this.billingAccountName,
    required this.billedAmount,
    required this.configuredDetailTotal,
    required this.statementLineTotal,
    required this.configuredItems,
    required this.statementLines,
    required this.alerts,
  });

  double get statementDifference => statementLineTotal - billedAmount;
  double get configuredDifference => configuredDetailTotal - billedAmount;
  bool get hasStatementLines => statementLines.isNotEmpty;
  bool get needsReview => alerts.isNotEmpty;
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

  List<AssetLiabilityDebtRow> get paymentSourceMissingRows {
    return debtMasterRows
        .where(
          (row) =>
              row.isDirectCashflowTarget &&
              row.scheduledPaymentAmount > 0 &&
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
