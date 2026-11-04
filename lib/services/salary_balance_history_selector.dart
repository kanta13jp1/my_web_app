/// An observed balance, not proof that a salary deposit occurred.
class SalaryBalanceHistoryObservation {
  const SalaryBalanceHistoryObservation({
    required this.accountName,
    required this.recordedAt,
    required this.amount,
  });

  final String accountName;
  final DateTime recordedAt;
  final double amount;
}

/// Selects a same-account balance candidate without altering the daily chart.
///
/// The caller must capture an owner, authentication generation, and local
/// history revision when the observations are requested. These are checked
/// against the current context before any observation can be used. A caller
/// must establish that the selected account name is unique; a history row ID
/// is not an account ID. Null means the history cannot be used as evidence.
double? selectSalaryBalanceHistoryPeak({
  required Iterable<SalaryBalanceHistoryObservation> observations,
  required String accountName,
  required bool accountNameIsUnique,
  required String? historyOwnerId,
  required String? currentOwnerId,
  required int historyAuthGeneration,
  required int currentAuthGeneration,
  required int historyRevision,
  required int currentHistoryRevision,
  required DateTime cycleStart,
  required DateTime asOf,
}) {
  if (accountName.isEmpty ||
      !accountNameIsUnique ||
      historyOwnerId == null ||
      historyOwnerId.isEmpty ||
      historyOwnerId != currentOwnerId ||
      historyAuthGeneration != currentAuthGeneration ||
      historyRevision != currentHistoryRevision ||
      cycleStart.isAfter(asOf)) {
    return null;
  }

  double? peak;
  for (final observation in observations) {
    if (observation.accountName != accountName ||
        !observation.amount.isFinite ||
        observation.recordedAt.isBefore(cycleStart) ||
        observation.recordedAt.isAfter(asOf)) {
      continue;
    }
    if (peak == null || observation.amount > peak) {
      peak = observation.amount;
    }
  }
  return peak;
}

/// Calculates a finite balance change; neither input proves a salary deposit.
double? salaryHistoryBalanceIncrease({
  required double? previousCycleEndBalance,
  required double? observedPeak,
}) {
  if (previousCycleEndBalance == null ||
      observedPeak == null ||
      !previousCycleEndBalance.isFinite ||
      !observedPeak.isFinite) {
    return null;
  }
  final delta = observedPeak - previousCycleEndBalance;
  return delta.isFinite ? delta : null;
}
