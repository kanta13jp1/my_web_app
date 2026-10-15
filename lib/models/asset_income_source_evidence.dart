import 'dart:convert';

enum IncomeSourceKind { flow, receivedPlan, payslip, salaryIncome }

enum IncomeDatePrecision { day, instant }

enum IncomeRelationship { sameEvent, distinctEvents }

enum IncomeLinkEvidence { existingPayslipFk, sessionConfirmation }

enum IncomeEvidenceProblem {
  ownerMismatch,
  currencyMismatch,
  missingRecordId,
  invalidDate,
  invalidAmount,
  sameIdConflict,
  missingPayslipTarget,
  eventAmountConflict,
  eventDateConflict,
  eventDatePrecisionConflict,
  staleDecision,
  contradictoryDecision,
  missingRelationship,
}

class IncomeSourceRecord {
  const IncomeSourceRecord({
    required this.kind,
    required this.id,
    required this.ownerId,
    required this.currency,
    required this.date,
    required this.datePrecision,
    required this.amount,
    this.payslipId,
    this.requiresPayslipLink = false,
  });

  final IncomeSourceKind kind;
  final String? id;
  final String ownerId;
  final String currency;
  final String date;
  final IncomeDatePrecision datePrecision;
  final int amount;
  final String? payslipId;
  final bool requiresPayslipLink;

  String? get key =>
      id == null || id!.trim().isEmpty ? null : '${kind.name}:$id';

  // A decision applies only to the exact source observation and owner.
  String get fingerprint => jsonEncode([
        key,
        ownerId,
        currency,
        date,
        datePrecision.name,
        amount,
        payslipId,
        requiresPayslipLink,
      ]);
}

class IncomeRelationshipDecision {
  const IncomeRelationshipDecision({
    required this.leftFingerprint,
    required this.rightFingerprint,
    required this.relationship,
  });

  final String leftFingerprint;
  final String rightFingerprint;
  final IncomeRelationship relationship;
}

class IncomeEvidenceIssue {
  const IncomeEvidenceIssue(this.problem, this.recordKeys);

  final IncomeEvidenceProblem problem;
  final List<String> recordKeys;
}

class IncomeEvidenceProjection {
  const IncomeEvidenceProjection({
    required this.records,
    required this.sourceRecordedTotals,
    required this.matchedEventSubtotal,
    required this.combinedRecordedTotal,
    required this.issues,
    required this.matchedEvents,
  });

  final List<IncomeSourceRecord> records;
  final Map<IncomeSourceKind, int?> sourceRecordedTotals;
  final int? matchedEventSubtotal;
  final int? combinedRecordedTotal;
  final List<IncomeEvidenceIssue> issues;
  final List<IncomeMatchedEvent> matchedEvents;

  bool get allowsIncomeDerivedOutput => combinedRecordedTotal != null;
}

class IncomeMatchedEvent {
  const IncomeMatchedEvent({
    required this.recordKeys,
    required this.amount,
    required this.evidence,
  });

  final List<String> recordKeys;
  final int amount;
  final Set<IncomeLinkEvidence> evidence;
}

/// Read-only projection. No monetary/name matching and no persistence.
class AssetIncomeSourceEvidence {
  const AssetIncomeSourceEvidence._();
  static const int _maxSafeInteger = 9007199254740991;

  static IncomeEvidenceProjection project({
    required String ownerId,
    required String currency,
    required List<IncomeSourceRecord> records,
    List<IncomeRelationshipDecision> decisions = const [],
  }) {
    final issues = <IncomeEvidenceIssue>[];
    final owned = <IncomeSourceRecord>[];
    final byKey = <String, IncomeSourceRecord>{};
    final totals = <IncomeSourceKind, int?>{};
    final brokenSources = <IncomeSourceKind>{};
    final conflictedKeys = <String>{};
    void issue(IncomeEvidenceProblem problem, [List<String> keys = const []]) {
      issues.add(IncomeEvidenceIssue(problem, List.unmodifiable(keys)));
      if ({
        IncomeEvidenceProblem.sameIdConflict,
        IncomeEvidenceProblem.currencyMismatch,
        IncomeEvidenceProblem.invalidDate,
        IncomeEvidenceProblem.invalidAmount,
        IncomeEvidenceProblem.eventAmountConflict,
        IncomeEvidenceProblem.eventDateConflict,
        IncomeEvidenceProblem.eventDatePrecisionConflict,
        IncomeEvidenceProblem.contradictoryDecision,
      }.contains(problem)) {
        conflictedKeys.addAll(keys);
      }
    }

    for (final row in records) {
      if (ownerId.isEmpty || row.ownerId != ownerId) {
        // Do not disclose another owner's IDs, amounts, dates or source rows.
        issue(IncomeEvidenceProblem.ownerMismatch);
        continue;
      }
      owned.add(row);
      final key = row.key;
      if (key == null) {
        brokenSources.add(row.kind);
        issue(IncomeEvidenceProblem.missingRecordId);
        continue;
      }
      if (row.currency != currency || currency.isEmpty) {
        brokenSources.add(row.kind);
        issue(IncomeEvidenceProblem.currencyMismatch, [key]);
        continue;
      }
      if (!_validDate(row)) {
        brokenSources.add(row.kind);
        issue(IncomeEvidenceProblem.invalidDate, [key]);
        continue;
      }
      if (row.amount < 0 || row.amount > _maxSafeInteger) {
        brokenSources.add(row.kind);
        issue(IncomeEvidenceProblem.invalidAmount, [key]);
        continue;
      }
      final previous = byKey[key];
      if (previous != null) {
        if (previous.fingerprint != row.fingerprint) {
          brokenSources.add(row.kind);
          issue(IncomeEvidenceProblem.sameIdConflict, [key]);
        }
        continue;
      }
      byKey[key] = row;
      totals[row.kind] = (totals[row.kind] ?? 0) + row.amount;
      if (totals[row.kind]! > _maxSafeInteger) {
        brokenSources.add(row.kind);
        issue(IncomeEvidenceProblem.invalidAmount, [key]);
      }
    }
    for (final kind in brokenSources) {
      totals[kind] = null;
    }

    final parent = {for (final key in byKey.keys) key: key};
    final linkEvidence = <String, Set<IncomeLinkEvidence>>{};
    String root(String key) {
      while (parent[key] != key) {
        key = parent[key]!;
      }
      return key;
    }

    bool merge(String left, String right, IncomeLinkEvidence evidence) {
      final a = byKey[left]!;
      final b = byKey[right]!;
      if (a.amount != b.amount) {
        issue(IncomeEvidenceProblem.eventAmountConflict, [left, right]);
        return false;
      }
      if (a.datePrecision != b.datePrecision) {
        issue(IncomeEvidenceProblem.eventDatePrecisionConflict, [left, right]);
        return false;
      }
      final sameDate = a.datePrecision == IncomeDatePrecision.day
          ? a.date == b.date
          : DateTime.parse(a.date).isAtSameMomentAs(DateTime.parse(b.date));
      if (!sameDate) {
        issue(IncomeEvidenceProblem.eventDateConflict, [left, right]);
        return false;
      }
      parent[root(right)] = root(left);
      linkEvidence.putIfAbsent(left, () => {}).add(evidence);
      linkEvidence.putIfAbsent(right, () => {}).add(evidence);
      return true;
    }

    for (final row in byKey.values) {
      if (row.kind != IncomeSourceKind.salaryIncome) continue;
      final id = row.payslipId;
      if (id == null || id.isEmpty) {
        if (row.requiresPayslipLink) {
          issue(IncomeEvidenceProblem.missingPayslipTarget, [row.key!]);
        }
        continue;
      }
      final target = 'payslip:$id';
      if (!byKey.containsKey(target)) {
        issue(IncomeEvidenceProblem.missingPayslipTarget, [row.key!]);
      } else {
        merge(target, row.key!, IncomeLinkEvidence.existingPayslipFk);
      }
    }

    final fingerprintRows = {
      for (final row in byKey.values) row.fingerprint: row
    };
    final distinct = <List<String>>[];
    for (final decision in decisions) {
      final left = fingerprintRows[decision.leftFingerprint];
      final right = fingerprintRows[decision.rightFingerprint];
      if (left == null || right == null || left.key == right.key) {
        issue(IncomeEvidenceProblem.staleDecision);
        continue;
      }
      if (decision.relationship == IncomeRelationship.sameEvent) {
        merge(left.key!, right.key!, IncomeLinkEvidence.sessionConfirmation);
      } else {
        distinct.add([left.key!, right.key!]);
      }
    }
    for (final pair in distinct) {
      if (root(pair[0]) == root(pair[1])) {
        issue(IncomeEvidenceProblem.contradictoryDecision, pair);
      }
    }

    final groups = <String, List<IncomeSourceRecord>>{};
    for (final row in byKey.values) {
      groups.putIfAbsent(root(row.key!), () => []).add(row);
    }
    final groupList = groups.values.toList();
    for (var i = 0; i < groupList.length; i++) {
      for (var j = i + 1; j < groupList.length; j++) {
        final left = groupList[i];
        final right = groupList[j];
        // Different rows in the same source remain separate recorded events.
        if (left.any((a) => right.any((b) => a.kind == b.kind))) continue;
        final decidedDistinct = distinct.any((pair) =>
            (root(pair[0]) == root(left.first.key!) &&
                root(pair[1]) == root(right.first.key!)) ||
            (root(pair[1]) == root(left.first.key!) &&
                root(pair[0]) == root(right.first.key!)));
        if (!decidedDistinct) {
          issue(
            IncomeEvidenceProblem.missingRelationship,
            [...left, ...right].map((row) => row.key!).toList(),
          );
        }
      }
    }
    final matched = groupList
        .where((group) =>
            group.length > 1 &&
            group.every((row) => !conflictedKeys.contains(row.key)))
        .toList();
    var matchedTotal = matched.isEmpty
        ? null
        : matched.fold<int>(0, (sum, group) => sum + group.first.amount);
    var combinedTotal = issues.isNotEmpty || byKey.isEmpty
        ? null
        : groupList.fold<int>(0, (sum, group) => sum + group.first.amount);
    if ((matchedTotal ?? 0) > _maxSafeInteger ||
        (combinedTotal ?? 0) > _maxSafeInteger) {
      issue(IncomeEvidenceProblem.invalidAmount);
      matchedTotal = null;
      combinedTotal = null;
    }
    return IncomeEvidenceProjection(
      records: List.unmodifiable(owned),
      sourceRecordedTotals: Map.unmodifiable(totals),
      matchedEventSubtotal: matchedTotal,
      combinedRecordedTotal: combinedTotal,
      issues: List.unmodifiable(issues),
      matchedEvents: List.unmodifiable([
        for (final group in matched)
          IncomeMatchedEvent(
            recordKeys: List.unmodifiable(group.map((row) => row.key!)),
            amount: group.first.amount,
            evidence: Set.unmodifiable({
              for (final row in group) ...?linkEvidence[row.key!],
            }),
          ),
      ]),
    );
  }

  static bool _validDate(IncomeSourceRecord row) {
    final parsed = DateTime.tryParse(row.date);
    if (parsed == null) return false;
    if (row.datePrecision == IncomeDatePrecision.day) {
      if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(row.date)) return false;
      return '${parsed.year.toString().padLeft(4, '0')}-'
              '${parsed.month.toString().padLeft(2, '0')}-'
              '${parsed.day.toString().padLeft(2, '0')}' ==
          row.date;
    }
    return RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(row.date);
  }
}
