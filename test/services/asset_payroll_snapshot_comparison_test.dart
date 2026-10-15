import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_payroll_snapshot_comparison.dart';

void main() {
  PayrollBalanceObservation observation(
    int month,
    int balance, {
    int year = 2030,
    String owner = 'owner-a',
    String account = 'account-a',
    bool confirmed = true,
    String source = 'synthetic-source',
    bool beforeDeposit = false,
  }) =>
      PayrollBalanceObservation(
        ownerId: owner,
        accountId: account,
        payrollMonth: DateTime(year, month),
        depositReference: 'synthetic-deposit-$year-$month',
        sourceReference: source,
        depositedAt: DateTime.utc(year, month, 20, 3),
        observedAt: DateTime.utc(year, month, 20, beforeDeposit ? 2 : 3),
        balanceYen: balance,
        evidence: PayrollBalanceEvidence.bankTransactionBalance,
        confirmedImmediatelyAfterDeposit: confirmed,
      );

  PayrollBalanceComparison compare(
    List<PayrollBalanceObservation> rows, {
    int month = 2,
    int? target,
  }) =>
      AssetPayrollSnapshotComparison.compare(
        ownerId: 'owner-a',
        accountId: 'account-a',
        payrollMonth: DateTime(2030, month),
        observations: rows,
        targetIncreaseYen: target,
      );

  test('compares consecutive confirmed observations and explicit goal', () {
    final result =
        compare([observation(1, 120), observation(2, 170)], target: 40);
    expect(result.status, PayrollComparisonStatus.comparable);
    expect(result.deltaYen, 50);
    expect(result.targetReached, isTrue);
  });
  test('no implicit goal and genuine zero remains zero', () {
    final result = compare([observation(1, 0), observation(2, 0)]);
    expect(result.deltaYen, 0);
    expect(result.targetReached, isNull);
  });
  test('payslip or estimated observation is not confirmation', () {
    final result =
        compare([observation(1, 120), observation(2, 999, confirmed: false)]);
    expect(result.status, PayrollComparisonStatus.currentMissing);
    expect(result.deltaYen, isNull);
  });
  test('missing immediate balance or source never becomes zero', () {
    final result =
        compare([observation(1, 120, source: ''), observation(2, 170)]);
    expect(result.status, PayrollComparisonStatus.previousMissing);
    expect(result.currentBalanceYen, 170);
    expect(result.previousBalanceYen, isNull);
  });
  test('owner and account boundaries exclude unrelated observations', () {
    final result = compare([
      observation(1, 120, owner: 'owner-b'),
      observation(1, 130, account: 'account-b'),
      observation(2, 170),
    ]);
    expect(result.status, PayrollComparisonStatus.previousMissing);
  });
  test('does not jump over missing calendar month', () {
    final result =
        compare([observation(1, 120), observation(3, 170)], month: 3);
    expect(result.deltaYen, isNull);
  });
  test('December to January boundary', () {
    final result = compare(
      [observation(12, 120, year: 2029), observation(1, 170)],
      month: 1,
    );
    expect(result.deltaYen, 50);
  });
  test('conflicting duplicate observations require review', () {
    final result = compare(
      [observation(1, 120), observation(2, 170), observation(2, 180)],
    );
    expect(result.status, PayrollComparisonStatus.conflictingObservations);
    expect(result.deltaYen, isNull);
  });
  test('observation before deposit is rejected', () {
    final result = compare(
      [observation(1, 120), observation(2, 170, beforeDeposit: true)],
    );
    expect(result.status, PayrollComparisonStatus.currentMissing);
  });
}
