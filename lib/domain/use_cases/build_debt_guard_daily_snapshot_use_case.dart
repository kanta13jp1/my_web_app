import '../models/debt_guard_rule.dart';

class BuildDebtGuardDailySnapshotUseCase {
  const BuildDebtGuardDailySnapshotUseCase();

  DebtGuardDailySnapshot call({
    required List<DebtGuardRule> rules,
    required List<DebtGuardEvent> events,
  }) {
    return DebtGuardDailySnapshot.fromEvents(rules: rules, events: events);
  }
}
