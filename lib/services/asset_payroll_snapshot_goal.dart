import 'asset_payroll_snapshot_store.dart';

enum PayrollSnapshotGoalStatus {
  currentMissing,
  previousMissing,
  contextMismatch,
  comparable,
}

class PayrollSnapshotGoal {
  const PayrollSnapshotGoal(this.status, {this.deltaYen, this.targetYen});
  final PayrollSnapshotGoalStatus status;
  final int? deltaYen;
  final int? targetYen;
  bool? get reached =>
      deltaYen == null || targetYen == null ? null : deltaYen! >= targetYen!;

  /// Records are explicitly selected owner-confirmed day observations. This
  /// neither constructs a timestamp nor infers a bank deposit from a date.
  static PayrollSnapshotGoal compare({
    required String ownerId,
    required String accountId,
    required DateTime month,
    required PayrollSnapshotRecord? current,
    required PayrollSnapshotRecord? previous,
    required int? targetYen,
  }) {
    if (ownerId.isEmpty ||
        accountId.isEmpty ||
        (targetYen != null &&
            (targetYen < 0 || targetYen > 9007199254740991))) {
      throw ArgumentError('Invalid owner, account or target');
    }
    bool matches(PayrollSnapshotRecord row, DateTime expected) =>
        row.id.isNotEmpty &&
        row.ownerId == ownerId &&
        row.accountId == accountId &&
        row.month.year == expected.year &&
        row.month.month == expected.month;
    if ((current != null && !matches(current, month)) ||
        (previous != null &&
            !matches(previous, DateTime(month.year, month.month - 1)))) {
      return PayrollSnapshotGoal(PayrollSnapshotGoalStatus.contextMismatch,
          targetYen: targetYen);
    }
    if (current == null) {
      return PayrollSnapshotGoal(PayrollSnapshotGoalStatus.currentMissing,
          targetYen: targetYen);
    }
    if (previous == null) {
      return PayrollSnapshotGoal(PayrollSnapshotGoalStatus.previousMissing,
          targetYen: targetYen);
    }
    return PayrollSnapshotGoal(
      PayrollSnapshotGoalStatus.comparable,
      deltaYen: current.balanceYen - previous.balanceYen,
      targetYen: targetYen,
    );
  }
}
