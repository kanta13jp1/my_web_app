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
  );

  final String sourceId;
  final DateTime payDate;
  final String reviewStatus;
  final int? grossYen;
  final int? netYen;
  final int? reportedSocialYen;
  final Map<String, int?> items;

  static const taxKeys = ['income_tax', 'resident_tax'];
  static const socialKeys = [
    'health_insurance',
    'pension',
    'employment_insurance',
  ];
  static const knownKeys = {...taxKeys, ...socialKeys, 'ideco'};

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

  int? get taxTotalYen => _completeTotal(
        taxKeys,
      );
  int? get socialPartsTotalYen => _completeTotal(
        socialKeys,
      );
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
        if (items[key] != null) items[key]!,
      if (socialTotalYen != null)
        socialTotalYen!
      else
        for (final key in socialKeys)
          if (items[key] != null) items[key]!,
      if (items['ideco'] != null) items['ideco']!,
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
    );
  }
}

class PayrollMonthDeductions {
  const PayrollMonthDeductions(
    this.month,
    this.statements,
    this.conflicting,
  );
  final DateTime month;
  final List<PayrollDeductions> statements;

  /// Repeated source with different content must be corrected before totals.
  final bool conflicting;

  bool get confirmed =>
      !conflicting &&
      statements.isNotEmpty &&
      statements.every(
        (row) => row.confirmed && !row.rejected,
      );

  int? _sum(int? Function(PayrollDeductions) read) {
    if (!confirmed) return null;
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
        (row) => row.taxTotalYen,
      );
  int? get confirmedSocialYen => _sum(
        _socialForComparison,
      );

  static int? _socialForComparison(PayrollDeductions row) {
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
      a.items.length == b.items.length &&
      a.items.entries.every(
        (e) => b.items.containsKey(e.key) && b.items[e.key] == e.value,
      );
}
