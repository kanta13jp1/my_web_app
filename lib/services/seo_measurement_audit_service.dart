import 'dart:math' as math;

enum SeoAuditConditionStatus {
  verified,
  caveated,
  rejected,
}

class SeoDailyAggregate {
  const SeoDailyAggregate({
    required this.dateKey,
    required this.count,
    this.impressions,
  });

  final String dateKey;
  final int count;
  final int? impressions;
}

class SeoMatchedPair {
  const SeoMatchedPair({
    required this.label,
    required this.beforeCount,
    required this.afterCount,
  });

  final String label;
  final int beforeCount;
  final int afterCount;
}

class SeoCausalEvidence {
  const SeoCausalEvidence({
    required this.hasAssignmentRecords,
    required this.hasInterventionRecords,
    required this.excludesUrlOverrides,
    required this.hasFixedCopyVersions,
  });

  final bool hasAssignmentRecords;
  final bool hasInterventionRecords;
  final bool excludesUrlOverrides;
  final bool hasFixedCopyVersions;

  bool get isComplete =>
      hasAssignmentRecords &&
      hasInterventionRecords &&
      excludesUrlOverrides &&
      hasFixedCopyVersions;
}

class SeoSignTestResult {
  const SeoSignTestResult({
    required this.nonTiedPairs,
    required this.positiveCount,
    required this.negativeCount,
    required this.twoSidedPValue,
    required this.leaveOneOutPValues,
  });

  final int nonTiedPairs;
  final int positiveCount;
  final int negativeCount;
  final double twoSidedPValue;
  final List<double> leaveOneOutPValues;
}

class SeoMeasurementAuditReport {
  const SeoMeasurementAuditReport({
    required this.invalidInputErrors,
    required this.jstUtcBoundarySplitDetected,
    required this.unrecordedDeliveryDetected,
    required this.signTest,
    required this.completeWeeks,
    required this.hasSearchImpressions,
    required this.controlPageValid,
    required this.causalAttributionAccepted,
    required this.causalRejectionReasons,
    required this.conditionStatuses,
  });

  final List<String> invalidInputErrors;
  final bool jstUtcBoundarySplitDetected;
  final bool unrecordedDeliveryDetected;
  final SeoSignTestResult signTest;
  final int completeWeeks;
  final bool hasSearchImpressions;
  final bool controlPageValid;
  final bool causalAttributionAccepted;
  final List<String> causalRejectionReasons;
  final Map<String, SeoAuditConditionStatus> conditionStatuses;
}

/// Read-only, deterministic auditor for the 7 omitted SEO measurement
/// conditions tracked under Issue #5563. Operates strictly on anonymous
/// aggregates and never stores PII or mutates external state.
class SeoMeasurementAuditService {
  const SeoMeasurementAuditService();

  static final RegExp _isoDatePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');
  static final RegExp _tzOffsetPattern = RegExp(r'(Z|[+-]\d{2}:\d{2})$');

  /// Validates anonymous daily aggregate rows (condition 1: invalid inputs).
  /// Rejects negative counts, non-int/NaN/non-finite values, invalid or
  /// duplicate ISO dates, and does not backfill missing dates as 0.
  List<String> validateDailyRows(List<Map<String, Object?>> rows) {
    final errors = <String>[];
    final seenDates = <String>{};
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final rawDate = row['date'];
      final rawCount = row['count'];
      if (rawDate is! String || !_isValidIsoDate(rawDate)) {
        errors.add('row[$i]: invalid date "$rawDate"');
      } else if (!seenDates.add(rawDate)) {
        errors.add('row[$i]: duplicate date "$rawDate"');
      }
      if (rawCount is! int || rawCount < 0) {
        errors.add('row[$i]: invalid count "$rawCount"');
      }
    }
    return errors;
  }

  /// Parses an ISO-8601 timestamp with explicit timezone offset (`Z` or
  /// `±HH:MM`) and returns its UTC and JST (`UTC+09:00`) calendar date keys
  /// (condition 2: timezone boundaries). Rejects naive timestamps without offset.
  ({String utcDate, String jstDate})? resolveUtcAndJstDates(String isoText) {
    final trimmed = isoText.trim();
    if (!_tzOffsetPattern.hasMatch(trimmed)) {
      return null;
    }
    final parsed = DateTime.tryParse(trimmed)?.toUtc();
    if (parsed == null) {
      return null;
    }
    final jst = parsed.add(const Duration(hours: 9));
    return (
      utcDate: _formatDate(parsed),
      jstDate: _formatDate(jst),
    );
  }

  /// Exact two-sided binomial sign test (`p = 0.5`) with leave-one-out
  /// sensitivity across all non-tied pairs (condition 4: random variation).
  SeoSignTestResult evaluateSignTest(List<SeoMatchedPair> pairs) {
    final nonTied = <int>[];
    for (final pair in pairs) {
      final diff = pair.afterCount - pair.beforeCount;
      if (diff != 0) {
        nonTied.add(diff > 0 ? 1 : -1);
      }
    }
    final pos = nonTied.where((d) => d > 0).length;
    final neg = nonTied.length - pos;
    final pValue = _twoSidedBinomialP(nonTied.length, math.min(pos, neg));
    final loo = <double>[];
    for (var i = 0; i < nonTied.length; i++) {
      final subPos = pos - (nonTied[i] > 0 ? 1 : 0);
      final subN = nonTied.length - 1;
      final subNeg = subN - subPos;
      loo.add(_twoSidedBinomialP(subN, math.min(subPos, subNeg)));
    }
    return SeoSignTestResult(
      nonTiedPairs: nonTied.length,
      positiveCount: pos,
      negativeCount: neg,
      twoSidedPValue: pValue,
      leaveOneOutPValues: loo,
    );
  }

  /// Evaluates all 7 omitted conditions deterministically without mutating
  /// production state or inferring unsupported causal effects.
  SeoMeasurementAuditReport audit({
    required List<Map<String, Object?>> rawDailyRows,
    required List<String> boundaryTimestamps,
    required int attemptedDeliveries,
    required int acceptedDeliveries,
    required List<SeoMatchedPair> matchedPairs,
    required int completeWeeks,
    required bool hasSearchImpressions,
    required int controlBaselineCount,
    required bool controlHasParallelPreTrend,
    required SeoCausalEvidence causalEvidence,
  }) {
    final inputErrors = validateDailyRows(rawDailyRows);

    var boundarySplit = false;
    for (final ts in boundaryTimestamps) {
      final dates = resolveUtcAndJstDates(ts);
      if (dates == null) {
        inputErrors.add('timestamp missing explicit offset: "$ts"');
      } else if (dates.utcDate != dates.jstDate) {
        boundarySplit = true;
      }
    }

    final unrecordedDetected = acceptedDeliveries < attemptedDeliveries;
    final signTest = evaluateSignTest(matchedPairs);
    final controlValid = controlBaselineCount > 0 && controlHasParallelPreTrend;

    final causalRejections = <String>[];
    if (!causalEvidence.hasAssignmentRecords) {
      causalRejections.add('missing_assignment_records');
    }
    if (!causalEvidence.hasInterventionRecords) {
      causalRejections.add('missing_intervention_records');
    }
    if (!causalEvidence.excludesUrlOverrides) {
      causalRejections.add('url_overrides_not_excluded');
    }
    if (!causalEvidence.hasFixedCopyVersions) {
      causalRejections.add('copy_versions_not_frozen');
    }

    final statuses = <String, SeoAuditConditionStatus>{
      'invalid_inputs': inputErrors.isEmpty
          ? SeoAuditConditionStatus.verified
          : SeoAuditConditionStatus.rejected,
      'timezone_boundaries': boundarySplit
          ? SeoAuditConditionStatus.caveated
          : SeoAuditConditionStatus.verified,
      'unrecorded_actions': unrecordedDetected
          ? SeoAuditConditionStatus.caveated
          : SeoAuditConditionStatus.verified,
      'random_variation':
          signTest.nonTiedPairs >= 7 && signTest.twoSidedPValue < 0.05
              ? SeoAuditConditionStatus.verified
              : SeoAuditConditionStatus.caveated,
      'seasonality_search_demand': completeWeeks >= 52 && hasSearchImpressions
          ? SeoAuditConditionStatus.verified
          : SeoAuditConditionStatus.caveated,
      'control_pages': controlValid
          ? SeoAuditConditionStatus.verified
          : SeoAuditConditionStatus.rejected,
      'causal_attribution': causalEvidence.isComplete
          ? SeoAuditConditionStatus.verified
          : SeoAuditConditionStatus.rejected,
    };

    return SeoMeasurementAuditReport(
      invalidInputErrors: inputErrors,
      jstUtcBoundarySplitDetected: boundarySplit,
      unrecordedDeliveryDetected: unrecordedDetected,
      signTest: signTest,
      completeWeeks: completeWeeks,
      hasSearchImpressions: hasSearchImpressions,
      controlPageValid: controlValid,
      causalAttributionAccepted: causalEvidence.isComplete,
      causalRejectionReasons: causalRejections,
      conditionStatuses: statuses,
    );
  }

  static bool _isValidIsoDate(String value) {
    if (!_isoDatePattern.hasMatch(value)) return false;
    final parts = value.split('-');
    final y = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final d = int.parse(parts[2]);
    final dt = DateTime.utc(y, m, d);
    return dt.year == y && dt.month == m && dt.day == d;
  }

  static String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static double _twoSidedBinomialP(int n, int kMin) {
    if (n <= 0) return 1.0;
    var tail = 0.0;
    for (var k = 0; k <= kMin; k++) {
      tail += _comb(n, k) * math.pow(0.5, n);
    }
    return math.min(1.0, 2.0 * tail);
  }

  static double _comb(int n, int k) {
    if (k < 0 || k > n) return 0;
    if (k == 0 || k == n) return 1;
    final m = math.min(k, n - k);
    var res = 1.0;
    for (var i = 1; i <= m; i++) {
      res = res * (n - m + i) / i;
    }
    return res;
  }
}
