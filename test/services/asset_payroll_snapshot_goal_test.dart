import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_payroll_snapshot_goal.dart';
import 'package:my_web_app/services/asset_payroll_snapshot_store.dart';

void main() {
  PayrollSnapshotRecord record({
    String owner = 'owner-a',
    String account = 'account-a',
    int month = 1,
    int balance = 100,
  }) =>
      PayrollSnapshotRecord(
        id: 'selected-$month',
        ownerId: owner,
        accountId: account,
        month: DateTime(2020, month),
        balanceYen: balance,
        depositDate: DateTime(2020, month, 25),
        note: 'synthetic explicit owner confirmation',
      );
  PayrollSnapshotGoal compare({
    PayrollSnapshotRecord? current,
    PayrollSnapshotRecord? previous,
    int? target,
    int month = 2,
  }) =>
      PayrollSnapshotGoal.compare(
        ownerId: 'owner-a',
        accountId: 'account-a',
        month: DateTime(2020, month),
        current: current,
        previous: previous,
        targetYen: target,
      );

  test('explicit threshold below equal above and signed difference', () {
    for (final amount in [109, 110, 111]) {
      final result = compare(
        current: record(month: 2, balance: amount),
        previous: record(),
        target: 10,
      );
      expect(result.deltaYen, amount - 100);
      expect(result.reached, amount >= 110);
    }
    final decreasing = compare(
      current: record(month: 2, balance: -10),
      previous: record(balance: 0),
      target: 0,
    );
    expect(decreasing.deltaYen, -10);
    expect(decreasing.reached, isFalse);
  });
  test('missing and unset are not inferred zero', () {
    expect(compare(target: 0).reached, isNull);
    expect(compare(current: record(month: 2), target: 0).reached, isNull);
    final unset = compare(current: record(month: 2), previous: record());
    expect(unset.deltaYen, 0);
    expect(unset.reached, isNull);
    expect(
        compare(current: record(month: 2), previous: record(), target: 0)
            .reached,
        isTrue,);
  });
  test('owner account and consecutive calendar month must match', () {
    for (final previous in [
      record(owner: 'owner-b'),
      record(account: 'account-b'),
      record(month: 0)
    ,]) {
      final result =
          compare(current: record(month: 2), previous: previous, target: 0);
      expect(result.status, PayrollSnapshotGoalStatus.contextMismatch);
      expect(result.reached, isNull);
    }
    final january = compare(
      month: 1,
      current: record(month: 1),
      previous: record(month: 0),
      target: 0,
    );
    expect(january.reached, isTrue);
    expect(() => compare(target: -1), throwsArgumentError);
  });
}
