/// Consent-safe acquisition evidence for one source cohort.
///
/// Nullable cohort counts are intentional: the admin page currently receives
/// aggregate source signals, not user-level acquisition/activity joins. A
/// missing value must remain distinguishable from a measured zero.
class AdminAcquisitionCohortEvidence {
  final String source;
  final int? aggregateSignalCount;
  final int? acquiredUsers;
  final int? day7EligibleUsers;
  final int? day7RetainedUsers;
  final int? day30EligibleUsers;
  final int? day30RetainedUsers;
  final int? paidConvertedUsers;

  const AdminAcquisitionCohortEvidence({
    required this.source,
    this.aggregateSignalCount,
    this.acquiredUsers,
    this.day7EligibleUsers,
    this.day7RetainedUsers,
    this.day30EligibleUsers,
    this.day30RetainedUsers,
    this.paidConvertedUsers,
  });

  double? get day7RetentionRate =>
      _safeRate(day7RetainedUsers, day7EligibleUsers);

  double? get day30RetentionRate =>
      _safeRate(day30RetainedUsers, day30EligibleUsers);

  double? get paidConversionRate =>
      _safeRate(paidConvertedUsers, acquiredUsers);

  bool get hasCompleteDecisionEvidence =>
      day7RetentionRate != null &&
      day30RetentionRate != null &&
      paidConversionRate != null;

  List<String> get missingInputs {
    final missing = <String>[];
    if (day7RetentionRate == null) {
      missing.add('D7対象者・継続者');
    }
    if (day30RetentionRate == null) {
      missing.add('D30対象者・継続者');
    }
    if (paidConversionRate == null) {
      missing.add('獲得者・有料転換者');
    }
    return missing;
  }
}

/// Converts aggregate source signals into explicitly incomplete evidence rows.
/// These counts are not promoted to acquired-user counts because no joined
/// user-level cohort is available at this boundary.
List<AdminAcquisitionCohortEvidence>
    adminAcquisitionEvidenceFromAggregateSignals(
  Map<String, int> aggregateSourceSignals,
) {
  final entries = aggregateSourceSignals.entries
      .where((entry) => entry.key.trim().isNotEmpty && entry.value > 0)
      .toList()
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      return byCount != 0 ? byCount : a.key.compareTo(b.key);
    });
  return [
    for (final entry in entries)
      AdminAcquisitionCohortEvidence(
        source: entry.key,
        aggregateSignalCount: entry.value,
      ),
  ];
}

/// Inputs and derived unit economics for one subscription plan.
///
/// The model performs no estimation. Every derived value stays null until all
/// of its required measured inputs are present and its denominator is valid.
class AdminPlanEconomics {
  final String planName;
  final double? monthlyRevenueYen;
  final int? paidCustomers;
  final double? monthlyAiVariableCostYen;
  final double? monthlyOtherVariableCostYen;
  final double? monthlyAcquisitionSpendYen;
  final int? newPaidCustomers;
  final int? beginningPaidCustomers;
  final int? churnedCustomers;

  const AdminPlanEconomics({
    required this.planName,
    this.monthlyRevenueYen,
    this.paidCustomers,
    this.monthlyAiVariableCostYen,
    this.monthlyOtherVariableCostYen,
    this.monthlyAcquisitionSpendYen,
    this.newPaidCustomers,
    this.beginningPaidCustomers,
    this.churnedCustomers,
  });

  double? get grossMarginYen {
    final revenue = monthlyRevenueYen;
    final aiCost = monthlyAiVariableCostYen;
    final otherCost = monthlyOtherVariableCostYen;
    if (!_isNonNegative(revenue) ||
        !_isNonNegative(aiCost) ||
        !_isNonNegative(otherCost)) {
      return null;
    }
    return revenue! - aiCost! - otherCost!;
  }

  double? get grossMarginRate {
    final revenue = monthlyRevenueYen;
    final margin = grossMarginYen;
    if (revenue == null || revenue <= 0 || margin == null) return null;
    return margin / revenue;
  }

  double? get customerAcquisitionCostYen {
    final spend = monthlyAcquisitionSpendYen;
    final customers = newPaidCustomers;
    if (!_isNonNegative(spend) || customers == null || customers <= 0) {
      return null;
    }
    return spend! / customers;
  }

  double? get grossMarginPerCustomerYen {
    final margin = grossMarginYen;
    final customers = paidCustomers;
    if (margin == null || customers == null || customers <= 0) return null;
    return margin / customers;
  }

  double? get paybackMonths {
    final cac = customerAcquisitionCostYen;
    final marginPerCustomer = grossMarginPerCustomerYen;
    if (cac == null || marginPerCustomer == null || marginPerCustomer <= 0) {
      return null;
    }
    return cac / marginPerCustomer;
  }

  double? get monthlyChurnRate =>
      _safeRate(churnedCustomers, beginningPaidCustomers);

  double? get lifetimeValueYen {
    final marginPerCustomer = grossMarginPerCustomerYen;
    final churnRate = monthlyChurnRate;
    if (marginPerCustomer == null ||
        marginPerCustomer <= 0 ||
        churnRate == null ||
        churnRate <= 0) {
      return null;
    }
    return marginPerCustomer / churnRate;
  }

  bool get hasCompleteDecisionEvidence =>
      grossMarginRate != null &&
      customerAcquisitionCostYen != null &&
      paybackMonths != null &&
      monthlyChurnRate != null &&
      lifetimeValueYen != null;

  List<String> get missingInputs {
    final missing = <String>[];
    if (monthlyRevenueYen == null) missing.add('プラン別MRR');
    if (paidCustomers == null) missing.add('プラン別課金顧客数');
    if (monthlyAiVariableCostYen == null) missing.add('AI変動費');
    if (monthlyOtherVariableCostYen == null) missing.add('その他変動費');
    if (monthlyAcquisitionSpendYen == null) missing.add('獲得費');
    if (newPaidCustomers == null) missing.add('新規課金顧客数');
    if (beginningPaidCustomers == null) missing.add('月初課金顧客数');
    if (churnedCustomers == null) missing.add('解約顧客数');
    return missing;
  }
}

class AdminPaidConversionMetrics {
  final int paidCustomers;
  final int mrrYen;

  const AdminPaidConversionMetrics({
    required this.paidCustomers,
    required this.mrrYen,
  });

  static const empty = AdminPaidConversionMetrics(paidCustomers: 0, mrrYen: 0);

  double? conversionRate(int totalUsers) =>
      _safeRate(paidCustomers, totalUsers);
}

/// Builds the human-reviewed default text for the admin X-post dialog.
///
/// MRR is explicitly labelled as the active Pro/Team list-price calculation;
/// it is not collected revenue. Measured zero values remain visible instead of
/// being dropped as falsy values.
String buildAdminDailyXPostDraft({
  required Map<String, dynamic> digest,
  required AdminPaidConversionMetrics billing,
}) {
  final users = digest['users'] is Map
      ? Map<String, dynamic>.from(digest['users'] as Map)
      : <String, dynamic>{};
  final featureRequests = digest['featureRequests'] is Map
      ? Map<String, dynamic>.from(digest['featureRequests'] as Map)
      : <String, dynamic>{};
  final totalUsers = _toNonNegativeInt(users['total']);
  final newToday = _toNonNegativeInt(featureRequests['newToday']);
  final openCount = _toNonNegativeInt(featureRequests['openCount']);
  final paidCustomers = billing.paidCustomers < 0 ? 0 : billing.paidCustomers;
  final mrrYen = billing.mrrYen < 0 ? 0 : billing.mrrYen;

  return '今日の自分株式会社\n'
      '総ユーザー$totalUsers人、新規要望$newToday件、未対応要望$openCount件。\n'
      '課金ユーザー$paidCustomers人、MRR ${_formatYen(mrrYen)}'
      '（active Pro/Teamの定価換算）。\n'
      'https://my-web-app-b67f4.web.app/ #buildinpublic #FlutterWeb #Supabase';
}

class AdminBillingFunnelMetrics {
  final int billingViews;
  final int upgradeClicks;
  final int checkoutSuccesses;
  final int checkoutCancels;

  const AdminBillingFunnelMetrics({
    required this.billingViews,
    required this.upgradeClicks,
    required this.checkoutSuccesses,
    required this.checkoutCancels,
  });

  double? get viewToClickRate => _safeRate(upgradeClicks, billingViews);

  double? get clickToSuccessRate => _safeRate(checkoutSuccesses, upgradeClicks);
}

double? _safeRate(int? numerator, int? denominator) {
  if (numerator == null || numerator < 0) return null;
  if (denominator == null || denominator <= 0) return null;
  if (numerator > denominator) return null;
  return numerator / denominator;
}

bool _isNonNegative(double? value) => value != null && value >= 0;

int _toNonNegativeInt(dynamic value) {
  final parsed = value is int ? value : int.tryParse(value?.toString() ?? '');
  return parsed == null || parsed < 0 ? 0 : parsed;
}

String _formatYen(int value) {
  final digits = value.toString();
  final formatted = digits.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return '¥$formatted';
}
