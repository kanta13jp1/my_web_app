import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_income_source_evidence.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_salary_spending_entries.dart';
import 'package:my_web_app/services/salary_spending_breakdown_service.dart';

IncomeEvidenceProjection project({
  List<Map<String, dynamic>> flows = const [],
  List<Map<String, dynamic>> salaries = const [],
  List<Map<String, dynamic>> payslips = const [],
  List<Map<String, dynamic>> references = const [],
  List<AssetLiabilityIncomePlan> plans = const [],
  List<IncomeRelationshipDecision> decisions = const [],
}) => AssetSalarySpendingEntries.projectCycle(
  ownerId: 'owner-a', flowOwnerId: 'owner-a', financeOwnerId: 'owner-a',
  reference: DateTime(2026, 6, 20), salaryDay: 25,
  recentFlows: flows, payslipSalaryIncomes: salaries, payslipRows: payslips,
  referencedPayslips: references, monthlyIncomePlans: plans, decisions: decisions,
);

void main() {
  test('same-source same-day amount observations with different IDs both count', () {
    final value = project(salaries: [
      {'id': 's1', 'pay_date': '2026-06-20', 'amount': 100},
      {'id': 's2', 'pay_date': '2026-06-20', 'amount': 100},
    ]);
    expect(value.combinedRecordedTotal, 200);
    expect(value.records, hasLength(2));
  });
  test('explicit FK matches once; supplement does not add an independent subtotal', () {
    final value = project(salaries: [
      {'id': 's1', 'pay_date': '2026-06-20', 'amount': 100, 'payslip_id': 'p1'},
    ], references: [
      {'id': 'p1', 'pay_date': '2026-06-20', 'net_amount': 100},
    ]);
    expect(value.combinedRecordedTotal, 100);
    expect(value.sourceRecordedTotals[IncomeSourceKind.payslip], isNull);
    expect(value.sourceRecordedTotals[IncomeSourceKind.salaryIncome], 100);
    expect(value.records.singleWhere((row) => row.evidenceOnly).id, 'p1');
  });
  test('cycle-external FK is evidence only and date conflict blocks total', () {
    final value = project(salaries: [
      {'id': 's1', 'pay_date': '2026-06-20', 'amount': 100, 'payslip_id': 'p1'},
    ], references: [
      {'id': 'p1', 'pay_date': '2026-05-20', 'net_amount': 100},
    ]);
    expect(value.combinedRecordedTotal, isNull);
    expect(value.sourceRecordedTotals[IncomeSourceKind.payslip], isNull);
    expect(value.issues.any((issue) => issue.problem == IncomeEvidenceProblem.eventDateConflict), isTrue);
  });
  test('ownerless local received plan is never relabelled as current user', () {
    final value = project(plans: [AssetLiabilityIncomePlan(
      id: 'legacy-local', date: DateTime(2026, 6, 20), name: 'Synthetic', amount: 100,
      destinationAccountId: null, destinationAccountName: null, received: true,
    )]);
    expect(value.combinedRecordedTotal, isNull);
    expect(value.records, isEmpty);
    expect(value.issues.any((issue) => issue.problem == IncomeEvidenceProblem.ownerMismatch), isTrue);
  });
  test('noninteger original amount remains an invalid observation, not rounded', () {
    final value = project(salaries: [{'id': 's1', 'pay_date': '2026-06-20', 'amount': 100.5}]);
    expect(value.combinedRecordedTotal, isNull);
    expect(value.records.single.observedAmount, '100.5');
    expect(value.issues.any((issue) => issue.problem == IncomeEvidenceProblem.invalidAmount), isTrue);
  });
  test('unknown relationship never creates a zero or old monetary fallback', () {
    final value = project(flows: [{'id': 'f1', 'action_type': 'conquer', 'occurred_at': '2026-06-20', 'amount': 100}],
      salaries: [{'id': 's1', 'pay_date': '2026-06-20', 'amount': 100}],);
    expect(value.combinedRecordedTotal, isNull);
    final breakdown = const SalarySpendingBreakdownService().build(
      referenceDate: DateTime(2026, 6, 20), incomeEvidence: value,
      expenses: [SalarySpendingEntry(date: DateTime(2026, 6, 20), amount: 10, description: '食費', sourceLabel: '支出')],
      incomes: [SalaryIncomeEntry(date: DateTime(2026, 6, 20), amount: 999, description: '給料')],
    );
    expect(breakdown.totalExpense, 10);
    expect(breakdown.salaryIncomeTotal, isNull);
    expect(breakdown.remainingAfterExpense, isNull);
  });
  test('confirmed distinct events unlock total; cancellation restores unresolved', () {
    final value = project(flows: [{'id': 'f1', 'action_type': 'conquer', 'occurred_at': '2026-06-20', 'amount': 100}],
      salaries: [{'id': 's1', 'pay_date': '2026-06-20', 'amount': 100}],);
    final session = IncomeEvidenceSession();
    final generation = session.beginRead('owner-a|JPY|cycle-a');
    expect(session.completeRead('owner-a|JPY|cycle-a', generation), isTrue);
    session.decide(value.records[0], value.records[1], IncomeRelationship.distinctEvents);
    final confirmed = project(flows: [{'id': 'f1', 'action_type': 'conquer', 'occurred_at': '2026-06-20', 'amount': 100}],
      salaries: [{'id': 's1', 'pay_date': '2026-06-20', 'amount': 100}], decisions: session.decisions,);
    expect(confirmed.combinedRecordedTotal, 200);
    final breakdown = const SalarySpendingBreakdownService().build(
      referenceDate: DateTime(2026, 6, 20), incomeEvidence: confirmed,
      expenses: [SalarySpendingEntry(date: DateTime(2026, 6, 20), amount: 10, description: '食費', sourceLabel: '支出')],
    );
    expect(breakdown.salaryIncomeTotal, 200);
    expect(breakdown.totalExpense, 10);
    expect(breakdown.remainingAfterExpense, 190);
    final limited = const SalarySpendingBreakdownService().build(
      referenceDate: DateTime(2026, 6, 20),
      incomeEvidence: withholdIncomeEvidence(confirmed, reason: IncomeEvidenceProblem.readLimitReached),
      expenses: [SalarySpendingEntry(date: DateTime(2026, 6, 20), amount: 10, description: '食費', sourceLabel: '支出')],
    );
    expect(limited.salaryIncomeTotal, isNull);
    expect(limited.remainingAfterExpense, isNull);
    expect(limited.totalExpense, 10);
    session.clearDecisions();
    expect(session.decisions, isEmpty);
    expect(value.combinedRecordedTotal, isNull);
  });
  test('old read generation and owner/cycle changes cannot reuse decisions', () {
    final session = IncomeEvidenceSession();
    final old = session.beginRead('owner-a|JPY|cycle-a');
    final latest = session.beginRead('owner-a|JPY|cycle-a');
    expect(session.completeRead('owner-a|JPY|cycle-a', old), isFalse);
    expect(session.ready, isFalse);
    expect(session.completeRead('owner-a|JPY|cycle-a', latest), isTrue);
    session.synchronizeScope('owner-a|JPY|cycle-b');
    expect(session.ready, isFalse);
    expect(session.completeRead('owner-a|JPY|cycle-a', latest), isFalse);
    session.synchronizeScope('owner-b|JPY|cycle-b');
    expect(session.decisions, isEmpty);
    expect(session.ready, isFalse);
  });
  test('changed source fingerprint discards screen decision and read failure withholds all totals', () {
    final value = project(flows: [{'id': 'f1', 'action_type': 'conquer', 'occurred_at': '2026-06-20', 'amount': 100}],
      salaries: [{'id': 's1', 'pay_date': '2026-06-20', 'amount': 100}],);
    final session = IncomeEvidenceSession(); final generation = session.beginRead('scope'); session.completeRead('scope', generation);
    session.decide(value.records[0], value.records[1], IncomeRelationship.sameEvent);
    session.retainCurrentRecords(project(salaries: [{'id': 's1', 'pay_date': '2026-06-20', 'amount': 101}]).records);
    expect(session.decisions, isEmpty);
    session.invalidateRead(); expect(session.ready, isFalse);
    final withheld = withholdIncomeEvidence(value);
    expect(withheld.combinedRecordedTotal, isNull);
    expect(withheld.matchedEventSubtotal, isNull);
    expect(withheld.sourceRecordedTotals.values.every((amount) => amount == null), isTrue);
  });
}
