/// Recorded balances can establish coverage of registered accounts only.
/// The presence of a flow, fixed cost or task cannot establish completeness.
class ClosingRecordChecks {
  final bool assets;
  final bool liabilities;
  final bool fixedCosts;
  final bool flows;
  final bool tasks;

  const ClosingRecordChecks({
    required this.assets,
    required this.liabilities,
    required this.fixedCosts,
    required this.flows,
    required this.tasks,
  });

  ClosingRecordChecks withRecordedBalances({
    required Set<String> registeredAccounts,
    required Map<String, double> recordedToday,
  }) {
    final allRecorded = registeredAccounts.isNotEmpty &&
        registeredAccounts.every(recordedToday.containsKey);
    return ClosingRecordChecks(
      assets: assets ||
          (allRecorded && recordedToday.values.any((value) => value >= 0)),
      liabilities: liabilities ||
          (allRecorded && recordedToday.values.any((value) => value < 0)),
      fixedCosts: fixedCosts,
      flows: flows,
      tasks: tasks,
    );
  }
}
