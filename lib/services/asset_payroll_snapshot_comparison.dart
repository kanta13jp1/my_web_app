/// Pure comparison of source-confirmed, immediately-after-payroll observations.
/// This does not detect deposits, infer balances, persist data, or post flows.
enum PayrollBalanceEvidence { bankTransactionBalance, userConfirmedAtDeposit }

class PayrollBalanceObservation {
  const PayrollBalanceObservation({
    required this.ownerId,
    required this.accountId,
    required this.payrollMonth,
    required this.depositReference,
    required this.sourceReference,
    required this.depositedAt,
    required this.observedAt,
    required this.balanceYen,
    required this.evidence,
    required this.confirmedImmediatelyAfterDeposit,
  });

  final String ownerId;
  final String accountId;

  /// Payroll attribution month, not necessarily the calendar month of deposit.
  final DateTime payrollMonth;
  final String depositReference;
  final String sourceReference;
  final DateTime depositedAt;
  final DateTime observedAt;
  final int balanceYen;
  final PayrollBalanceEvidence evidence;

  /// Must come from verified bank evidence or an explicit user confirmation.
  /// A payslip, scheduled date, or estimated balance cannot set this flag.
  final bool confirmedImmediatelyAfterDeposit;
}

enum PayrollComparisonStatus {
  comparable,
  currentMissing,
  previousMissing,
  conflictingObservations,
}

class PayrollBalanceComparison {
  const PayrollBalanceComparison({
    required this.status,
    this.currentBalanceYen,
    this.previousBalanceYen,
    this.deltaYen,
    this.targetIncreaseYen,
  });

  final PayrollComparisonStatus status;
  final int? currentBalanceYen;
  final int? previousBalanceYen;
  final int? deltaYen;

  /// User setting; absent means no goal, never an implicit universal target.
  final int? targetIncreaseYen;
  bool? get targetReached => deltaYen == null || targetIncreaseYen == null
      ? null
      : deltaYen! >= targetIncreaseYen!;
}

class AssetPayrollSnapshotComparison {
  const AssetPayrollSnapshotComparison._();

  static PayrollBalanceComparison compare({
    required String ownerId,
    required String accountId,
    required DateTime payrollMonth,
    required Iterable<PayrollBalanceObservation> observations,
    int? targetIncreaseYen,
  }) {
    if (ownerId.trim().isEmpty || accountId.trim().isEmpty) {
      throw ArgumentError('Owner and account are required.');
    }
    if (targetIncreaseYen != null && targetIncreaseYen < 0) {
      throw ArgumentError.value(targetIncreaseYen, 'targetIncreaseYen');
    }
    final previousMonth = DateTime(payrollMonth.year, payrollMonth.month - 1);
    List<PayrollBalanceObservation> eligible(DateTime month) => observations
        .where(
          (row) =>
              row.ownerId == ownerId &&
              row.accountId == accountId &&
              row.payrollMonth.year == month.year &&
              row.payrollMonth.month == month.month &&
              row.depositReference.trim().isNotEmpty &&
              row.sourceReference.trim().isNotEmpty &&
              row.confirmedImmediatelyAfterDeposit &&
              !row.observedAt.isBefore(row.depositedAt),
        )
        .toList();

    final current = eligible(payrollMonth);
    final previous = eligible(previousMonth);
    // No arbitrary latest/maximum selection when correction or import clashes
    // exist. Persistence must supply only its explicitly selected revision.
    bool conflicts(List<PayrollBalanceObservation> rows) => rows.length > 1;
    if (conflicts(current) || conflicts(previous)) {
      return PayrollBalanceComparison(
        status: PayrollComparisonStatus.conflictingObservations,
        targetIncreaseYen: targetIncreaseYen,
      );
    }
    if (current.isEmpty) {
      return PayrollBalanceComparison(
        status: PayrollComparisonStatus.currentMissing,
        targetIncreaseYen: targetIncreaseYen,
      );
    }
    final currentBalance = current.single.balanceYen;
    if (previous.isEmpty) {
      return PayrollBalanceComparison(
        status: PayrollComparisonStatus.previousMissing,
        currentBalanceYen: currentBalance,
        targetIncreaseYen: targetIncreaseYen,
      );
    }
    final previousBalance = previous.single.balanceYen;
    return PayrollBalanceComparison(
      status: PayrollComparisonStatus.comparable,
      currentBalanceYen: currentBalance,
      previousBalanceYen: previousBalance,
      deltaYen: currentBalance - previousBalance,
      targetIncreaseYen: targetIncreaseYen,
    );
  }
}
