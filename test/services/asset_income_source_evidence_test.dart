import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_income_source_evidence.dart';

IncomeSourceRecord _row(
  IncomeSourceKind kind,
  String? id, {
  String owner = 'synthetic-owner',
  String currency = 'JPY',
  String date = '2026-01-25',
  IncomeDatePrecision precision = IncomeDatePrecision.day,
  int amount = 1000,
  String? payslipId,
  bool requiresLink = false,
}) =>
    IncomeSourceRecord(
      kind: kind,
      id: id,
      ownerId: owner,
      currency: currency,
      date: date,
      datePrecision: precision,
      amount: amount,
      payslipId: payslipId,
      requiresPayslipLink: requiresLink,
    );

IncomeEvidenceProjection _project(
  List<IncomeSourceRecord> records, {
  List<IncomeRelationshipDecision> decisions = const [],
}) =>
    AssetIncomeSourceEvidence.project(
      ownerId: 'synthetic-owner',
      currency: 'JPY',
      records: records,
      decisions: decisions,
    );

void main() {
  test('existing FK resolves a payslip mirror without adding it twice', () {
    final result = _project([
      _row(IncomeSourceKind.payslip, 'p'),
      _row(IncomeSourceKind.salaryIncome, 's', payslipId: 'p'),
    ]);
    expect(result.combinedRecordedTotal, 1000);
    expect(result.matchedEventSubtotal, 1000);
    expect(result.sourceRecordedTotals.values, everyElement(1000));
    expect(result.issues, isEmpty);
    expect(
      result.matchedEvents.single.evidence,
      {IncomeLinkEvidence.existingPayslipFk},
    );
  });

  test('same amount across unlinked sources preserves both and has no total',
      () {
    final result = _project([
      _row(IncomeSourceKind.flow, 'f'),
      _row(IncomeSourceKind.payslip, 'p'),
    ]);
    expect(result.records, hasLength(2));
    expect(result.sourceRecordedTotals.values, everyElement(1000));
    expect(result.combinedRecordedTotal, isNull);
    expect(result.matchedEventSubtotal, isNull);
    expect(
      result.issues.single.recordKeys,
      containsAll(['flow:f', 'payslip:p']),
    );
  });

  test('distinct source IDs in the same source are not monetary duplicates',
      () {
    final result = _project([
      _row(IncomeSourceKind.receivedPlan, 'a'),
      _row(IncomeSourceKind.receivedPlan, 'b'),
    ]);
    expect(result.combinedRecordedTotal, 2000);
    expect(result.records, hasLength(2));
  });

  test('explicit session distinction resolves only current observations', () {
    final flow = _row(IncomeSourceKind.flow, 'f');
    final payslip = _row(IncomeSourceKind.payslip, 'p');
    final decision = IncomeRelationshipDecision(
      leftFingerprint: flow.fingerprint,
      rightFingerprint: payslip.fingerprint,
      relationship: IncomeRelationship.distinctEvents,
    );
    expect(
      _project([flow, payslip], decisions: [decision]).combinedRecordedTotal,
      2000,
    );
    final changed = _row(IncomeSourceKind.flow, 'f', amount: 1100);
    final stale = _project([changed, payslip], decisions: [decision]);
    expect(stale.combinedRecordedTotal, isNull);
    expect(
      stale.issues.map((issue) => issue.problem),
      contains(IncomeEvidenceProblem.staleDecision),
    );
  });

  test('explicit session same-event decision can collapse compatible records',
      () {
    final flow = _row(IncomeSourceKind.flow, 'f');
    final payslip = _row(IncomeSourceKind.payslip, 'p');
    final result = _project(
      [flow, payslip],
      decisions: [
        IncomeRelationshipDecision(
          leftFingerprint: flow.fingerprint,
          rightFingerprint: payslip.fingerprint,
          relationship: IncomeRelationship.sameEvent,
        ),
      ],
    );
    expect(result.combinedRecordedTotal, 1000);
    expect(result.matchedEventSubtotal, 1000);
    expect(
      result.matchedEvents.single.evidence,
      {IncomeLinkEvidence.sessionConfirmation},
    );
  });

  test('same source ID conflict blocks total and source subtotal', () {
    final result = _project([
      _row(IncomeSourceKind.flow, 'f'),
      _row(IncomeSourceKind.flow, 'f', amount: 1100),
    ]);
    expect(result.combinedRecordedTotal, isNull);
    expect(result.sourceRecordedTotals[IncomeSourceKind.flow], isNull);
    expect(
      result.issues.single.problem,
      IncomeEvidenceProblem.sameIdConflict,
    );
  });

  test('missing FK target is named without guessing by amount', () {
    final result = _project([
      _row(IncomeSourceKind.salaryIncome, 's', payslipId: 'missing'),
    ]);
    expect(result.combinedRecordedTotal, isNull);
    expect(result.issues.single.recordKeys, ['salaryIncome:s']);
  });

  test('owner mismatch discards foreign values and does not reveal IDs', () {
    final result = _project([
      _row(IncomeSourceKind.payslip, 'foreign-id', owner: 'foreign-owner'),
    ]);
    expect(result.records, isEmpty);
    expect(result.sourceRecordedTotals, isEmpty);
    expect(result.combinedRecordedTotal, isNull);
    expect(result.issues.single.recordKeys, isEmpty);
  });

  test('currency mismatch cannot be added as if converted', () {
    final result = _project([
      _row(IncomeSourceKind.flow, 'f', currency: 'USD'),
    ]);
    expect(result.combinedRecordedTotal, isNull);
    expect(result.sourceRecordedTotals[IncomeSourceKind.flow], isNull);
    expect(
      result.issues.single.problem,
      IncomeEvidenceProblem.currencyMismatch,
    );
  });

  test('day-only payslip never invents an instant for an FK mirror', () {
    final result = _project([
      _row(IncomeSourceKind.payslip, 'p'),
      _row(
        IncomeSourceKind.salaryIncome,
        's',
        payslipId: 'p',
        date: '2026-01-25T00:00:00Z',
        precision: IncomeDatePrecision.instant,
      ),
    ]);
    expect(result.combinedRecordedTotal, isNull);
    expect(result.matchedEventSubtotal, isNull);
    expect(
      result.issues.map((issue) => issue.problem),
      contains(IncomeEvidenceProblem.eventDatePrecisionConflict),
    );
  });

  test('invalid dates and missing IDs are missing evidence, not zero', () {
    final result = _project([
      _row(IncomeSourceKind.flow, null),
      _row(IncomeSourceKind.payslip, 'p', date: '2026-02-30'),
    ]);
    expect(result.combinedRecordedTotal, isNull);
    expect(result.sourceRecordedTotals.values, everyElement(isNull));
  });

  test('empty evidence differs from an explicit zero-valued record', () {
    expect(_project([]).combinedRecordedTotal, isNull);
    final zero = _project([_row(IncomeSourceKind.flow, 'f', amount: 0)]);
    expect(zero.combinedRecordedTotal, 0);
    expect(zero.allowsIncomeDerivedOutput, isTrue);
  });

  test('identical source retrieval is counted once without merging other IDs',
      () {
    final row = _row(IncomeSourceKind.flow, 'f');
    expect(_project([row, row]).combinedRecordedTotal, 1000);
  });

  test('FK amount conflict is not a matched subtotal', () {
    final result = _project([
      _row(IncomeSourceKind.payslip, 'p'),
      _row(IncomeSourceKind.salaryIncome, 's', payslipId: 'p', amount: 1100),
    ]);
    expect(result.combinedRecordedTotal, isNull);
    expect(result.matchedEventSubtotal, isNull);
    expect(result.sourceRecordedTotals[IncomeSourceKind.payslip], 1000);
    expect(result.sourceRecordedTotals[IncomeSourceKind.salaryIncome], 1100);
  });

  test('a declared mirror without its FK remains pending', () {
    final result = _project([
      _row(IncomeSourceKind.salaryIncome, 's', requiresLink: true),
    ]);
    expect(result.combinedRecordedTotal, isNull);
    expect(
      result.issues.single.problem,
      IncomeEvidenceProblem.missingPayslipTarget,
    );
  });

  test('distinct decision cannot contradict an existing FK', () {
    final p = _row(IncomeSourceKind.payslip, 'p');
    final s = _row(IncomeSourceKind.salaryIncome, 's', payslipId: 'p');
    final result = _project(
      [p, s],
      decisions: [
        IncomeRelationshipDecision(
          leftFingerprint: p.fingerprint,
          rightFingerprint: s.fingerprint,
          relationship: IncomeRelationship.distinctEvents,
        ),
      ],
    );
    expect(result.combinedRecordedTotal, isNull);
    expect(result.matchedEventSubtotal, isNull);
    expect(
      result.issues.single.problem,
      IncomeEvidenceProblem.contradictoryDecision,
    );
  });

  test('web-unsafe source amounts and aggregate sums never become totals', () {
    final oversized = _project([
      _row(IncomeSourceKind.flow, 'a', amount: 9007199254740992),
    ]);
    expect(oversized.combinedRecordedTotal, isNull);
    final overflowing = _project([
      _row(IncomeSourceKind.flow, 'a', amount: 9007199254740991),
      _row(IncomeSourceKind.flow, 'b', amount: 1),
    ]);
    expect(overflowing.combinedRecordedTotal, isNull);
    expect(overflowing.sourceRecordedTotals[IncomeSourceKind.flow], isNull);
  });
}
