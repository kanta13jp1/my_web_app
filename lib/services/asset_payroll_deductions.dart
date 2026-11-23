/// Read-only projections of existing payslip fields. No new expense is posted.
class PayrollDeductions {
  PayrollDeductions._(
    this.sourceId,
    this.payDate,
    this.reviewStatus,
    this.grossYen,
    this.netYen,
    this.reportedSocialYen,
    this.items,
    this.conflictingCanonicalKeys,
  );

  final String sourceId;
  final DateTime payDate;
  final String reviewStatus;
  final int? grossYen;
  final int? netYen;
  final int? reportedSocialYen;
  final Map<String, int?> items;
  final Set<String> conflictingCanonicalKeys;

  static const taxKeys = ['income_tax', 'resident_tax'];
  static const socialKeys = [
    'health_insurance',
    'pension',
    'employment_insurance',
  ];
  static const optionalSocialKeys = [
    'long_term_care_insurance',
    'employees_pension_fund_contribution',
  ];
  static const Map<String, String> deductionAliases = {
    '所得税': 'income_tax',
    '住民税': 'resident_tax',
    '健康保険料': 'health_insurance',
    '健康保険': 'health_insurance',
    'employees_pension_insurance': 'pension',
    'employee_pension_insurance': 'pension',
    '厚生年金保険料': 'pension',
    '厚生年金保険': 'pension',
    '厚生年金': 'pension',
    '雇用保険料': 'employment_insurance',
    '雇用保険': 'employment_insurance',
    '介護保険料': 'long_term_care_insurance',
    '介護保険': 'long_term_care_insurance',
    'employee_pension_fund_contribution':
        'employees_pension_fund_contribution',
    '厚生年金基金掛金': 'employees_pension_fund_contribution',
    'IDECO': 'ideco',
    'iDeCo': 'ideco',
  };
  static const knownKeys = {
    ...taxKeys,
    ...socialKeys,
    ...optionalSocialKeys,
    'ideco',
    '所得税',
    '住民税',
    '健康保険料',
    '健康保険',
    'employees_pension_insurance',
    'employee_pension_insurance',
    '厚生年金保険料',
    '厚生年金保険',
    '厚生年金',
    '雇用保険料',
    '雇用保険',
    '介護保険料',
    '介護保険',
    'employee_pension_fund_contribution',
    '厚生年金基金掛金',
    'IDECO',
    'iDeCo',
  };

  static String canonicalKey(String key) => deductionAliases[key] ?? key;

  bool isFuturePayDate(DateTime asOfDate) {
    final today = DateTime(asOfDate.year, asOfDate.month, asOfDate.day);
    return payDate.isAfter(today);
  }

  bool get conflictingPensionAliases =>
      conflictingCanonicalKeys.contains('pension');
  bool get conflictingTaxAliases =>
      taxKeys.any(conflictingCanonicalKeys.contains);
  bool get conflictingSocialAliases =>
      conflictingPensionAliases ||
      socialKeys.any(conflictingCanonicalKeys.contains) ||
      optionalSocialKeys.any(conflictingCanonicalKeys.contains);
  bool get conflictingDeductionAliases => conflictingCanonicalKeys.isNotEmpty;

  bool get confirmed => reviewStatus == 'confirmed';
  bool get rejected => reviewStatus == 'rejected';

  int? _completeTotal(Iterable<String> keys) {
    var sum = 0;
    for (final key in keys) {
      final value = items[key];
      if (value == null) return null;
      sum += value;
    }
    return sum;
  }

  int? get taxTotalYen =>
      conflictingTaxAliases ? null : _completeTotal(taxKeys);
  int? get socialPartsTotalYen => conflictingSocialAliases
      ? null
      : _completeTotal([
          ...socialKeys,
          ...optionalSocialKeys,
        ]);
  int? get socialTotalYen => reportedSocialYen ?? socialPartsTotalYen;
  int? get socialMismatchYen =>
      reportedSocialYen == null || socialPartsTotalYen == null
          ? null
          : reportedSocialYen! - socialPartsTotalYen!;

  Map<String, int?> get unclassified => Map.unmodifiable(
        Map.fromEntries(items.entries.where((e) => !knownKeys.contains(e.key))),
      );

  /// Only known categories are subtotaled. Missing entries remain absent in
  /// [items]; this subtotal must never be labelled the full deduction amount.
  /// Reported social total replaces, rather than adds to, its component sum.
  int? get identifiedSubtotalYen {
    final values = <int>[
      for (final key in taxKeys)
        if (!conflictingCanonicalKeys.contains(key) && items[key] != null)
          items[key]!,
      if (socialTotalYen != null)
        socialTotalYen!
      else
        for (final key in [...socialKeys, ...optionalSocialKeys])
          if (!conflictingCanonicalKeys.contains(key) && items[key] != null)
            items[key]!,
      if (!conflictingCanonicalKeys.contains('ideco') && items['ideco'] != null)
        items['ideco']!,
    ];
    return values.isEmpty
        ? null
        : values.reduce(
            (a, b) => a + b,
          );
  }

  /// Gross minus net is a derived total, not another parsed source field.
  int? get derivedDeductionTotalYen =>
      grossYen == null || netYen == null ? null : grossYen! - netYen!;

  /// Residual against the identified subtotal. Nonzero can mean missing items,
  /// unknown categories, or a parsing error; it is not automatically an error.
  int? get unidentifiedDifferenceYen =>
      derivedDeductionTotalYen == null || identifiedSubtotalYen == null
          ? null
          : derivedDeductionTotalYen! - identifiedSubtotalYen!;

  static int? readYen(Object? value) {
    if (value is! num || !value.isFinite || value != value.roundToDouble()) {
      return null;
    }
    return value.toInt();
  }

  static PayrollDeductions? fromRow(Map<String, dynamic> row) {
    final sourceId = row['id'];
    final rawDate = row['pay_date'];
    if (sourceId is! String || sourceId.trim().isEmpty || rawDate is! String) {
      return null;
    }
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(
      rawDate,
    );
    if (match == null) return null;
    final year = int.parse(
      match[1]!,
    );
    final month = int.parse(
      match[2]!,
    );
    final day = int.parse(
      match[3]!,
    );
    final date = DateTime(
      year,
      month,
      day,
    );
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    final rawItems = row['deductions'];
    final items = <String, int?>{};
    if (rawItems is Map) {
      for (final entry in rawItems.entries) {
        if (entry.key is String) {
          items[entry.key as String] = readYen(
            entry.value,
          );
        }
      }
    }
    // AI extraction can preserve Japanese labels or singular/longer English
    // aliases while the deterministic parser emits canonical snake_case keys.
    // Normalize aliases only when all non-null values for a canonical key
    // agree, and preserve missing/null fields as unknown.
    final grouped = <String, List<MapEntry<String, int?>>>{};
    for (final entry in items.entries) {
      grouped.putIfAbsent(canonicalKey(entry.key), () => []).add(entry);
    }
    final conflicts = <String>{};
    for (final group in grouped.entries) {
      final canonical = group.key;
      final candidates = group.value;
      if (candidates.length > 1) {
        final firstValue = candidates.first.value;
        final hasConflict = firstValue == null ||
            candidates.any((candidate) => candidate.value != firstValue);
        if (hasConflict) {
          conflicts.add(canonical);
        } else if (!items.containsKey(canonical)) {
          items[canonical] = firstValue;
        }
      } else {
        final only = candidates.single;
        if (only.key != canonical && !items.containsKey(canonical)) {
          items[canonical] = only.value;
        }
      }
    }
    return PayrollDeductions._(
      sourceId,
      date,
      row['review_status'] is String
          ? row['review_status'] as String
          : 'unknown',
      readYen(row['gross_amount']),
      readYen(row['net_amount']),
      readYen(row['social_insurance_total']),
      Map.unmodifiable(items),
      Set.unmodifiable(conflicts),
    );
  }
}

class PayrollMonthDeductions {
  const PayrollMonthDeductions(
    this.month,
    this.statements,
    this.conflicting, {
    this.asOfDate,
  });
  final DateTime month;
  final List<PayrollDeductions> statements;

  /// Repeated source with different content must be corrected before totals.
  final bool conflicting;
  final DateTime? asOfDate;

  bool get hasFuturePayDate =>
      asOfDate != null &&
      statements.any((row) => row.isFuturePayDate(asOfDate!));

  bool get confirmed =>
      !conflicting &&
      statements.isNotEmpty &&
      statements.every(
        (row) => row.confirmed && !row.rejected,
      );

  int? _sum(int? Function(PayrollDeductions) read) {
    if (!confirmed || hasFuturePayDate) return null;
    var sum = 0;
    for (final row in statements) {
      final amount = read(
        row,
      );
      if (amount == null) return null;
      sum += amount;
    }
    return sum;
  }

  int? get confirmedTaxYen => _sum(
        _taxForComparison,
      );
  int? get confirmedSocialYen => _sum(
        _socialForComparison,
      );

  /// Availability and verification are independent: parsed is not confirmed.
  String summaryStatus({required bool social}) {
    if (statements.isEmpty) return '明細なし';
    if (conflicting) return '同じ明細の内容が競合・要確認';
    final reasons = <String>[];
    if (!confirmed) reasons.add('取得済み・本人未確認');
    if (hasFuturePayDate) reasons.add('支給日未到来');
    if (!social && statements.any((row) => row.conflictingTaxAliases)) {
      reasons.add('税金の項目名違いが競合');
    }
    if (social && statements.any((row) => row.conflictingPensionAliases)) {
      reasons.add('厚生年金の項目名違いが競合');
    } else if (social &&
        statements.any((row) => row.conflictingSocialAliases)) {
      reasons.add('社会保険の項目名違いが競合');
    }
    if (social &&
        statements.any(
          (row) => row.socialMismatchYen != null && row.socialMismatchYen != 0,
        )) {
      reasons.add('社会保険の記載合計と内訳が不一致');
    }
    if (statements.any(
      (row) => (social ? row.socialTotalYen : row.taxTotalYen) == null,
    )) {
      reasons.add('必要項目の記載なし');
    }
    if (reasons.isNotEmpty) {
      final prefix = confirmed ? '取得済み・本人確認済み／' : '';
      return '$prefix${reasons.join('／')}（確定累計対象外）';
    }
    return '本人確認済み';
  }

  static int? _taxForComparison(PayrollDeductions row) {
    if (row.conflictingTaxAliases) return null;
    return row.taxTotalYen;
  }

  static int? _socialForComparison(PayrollDeductions row) {
    if (row.conflictingSocialAliases) return null;
    if (row.socialMismatchYen != null && row.socialMismatchYen != 0) {
      return null;
    }
    return row.socialTotalYen;
  }
}

class AssetPayrollDeductions {
  const AssetPayrollDeductions._();

  /// Explicit owner filtering supplements, but cannot replace, database RLS.
  /// Months follow pay_date; this does not infer salary accrual months.
  static List<PayrollMonthDeductions> months({
    required String ownerId,
    required int year,
    required Iterable<Map<String, dynamic>> rows,
    DateTime? asOfDate,
  }) {
    if (ownerId.trim().isEmpty) {
      throw ArgumentError(
        'Owner is required.',
      );
    }
    final byMonth = <int, List<PayrollDeductions>>{};
    final byId = <String, Map<String, dynamic>>{};
    final conflictMonths = <int>{};
    for (final raw in rows) {
      if (raw['user_id'] != ownerId) continue;
      final row = PayrollDeductions.fromRow(
        raw,
      );
      if (row == null || row.payDate.year != year || row.rejected) continue;
      final previous = byId[row.sourceId];
      if (previous != null) {
        // Do not pick the latest copy or silently double-count repeated data.
        final prior = PayrollDeductions.fromRow(previous)!;
        if (!_same(prior, row)) {
          conflictMonths.add(
            prior.payDate.month,
          );
          conflictMonths.add(
            row.payDate.month,
          );
        }
        continue;
      }
      byId[row.sourceId] = raw;
      byMonth.putIfAbsent(row.payDate.month, () => []).add(
            row,
          );
    }
    return List.generate(
      12,
      (index) {
        final month = index + 1;
        return PayrollMonthDeductions(
          DateTime(year, month),
          List.unmodifiable(byMonth[month] ?? const <PayrollDeductions>[]),
          conflictMonths.contains(month),
          asOfDate: asOfDate,
        );
      },
    );
  }

  static bool _same(PayrollDeductions a, PayrollDeductions b) =>
      a.payDate == b.payDate &&
      a.reviewStatus == b.reviewStatus &&
      a.grossYen == b.grossYen &&
      a.netYen == b.netYen &&
      a.reportedSocialYen == b.reportedSocialYen &&
      a.conflictingCanonicalKeys.length == b.conflictingCanonicalKeys.length &&
      a.conflictingCanonicalKeys.every(b.conflictingCanonicalKeys.contains) &&
      a.items.length == b.items.length &&
      a.items.entries.every(
        (e) => b.items.containsKey(e.key) && b.items[e.key] == e.value,
      );
}
