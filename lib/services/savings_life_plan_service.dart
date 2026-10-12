import 'dart:math';

import '../models/savings_life_plan.dart';

class SavingsLifePlanService {
  static DateTime day(DateTime value) =>
      DateTime.utc(value.year, value.month, value.day);

  static DateTime anniversary(DateTime start, int months) {
    final first = DateTime.utc(start.year, start.month + months);
    final lastDay = DateTime.utc(first.year, first.month + 1, 0).day;
    return DateTime.utc(first.year, first.month, min(start.day, lastDay));
  }

  static SavingsPlanResult calculate({
    required SavingsLifePlan plan,
    required DateTime asOf,
    required int monthlyCommitments,
  }) {
    final today = day(asOf);
    final deadline = day(plan.targetDate);
    final start = day(plan.start);
    final dates = <DateTime>[];
    // Calendar dates, not 365-day approximations. Fixed anchors survive reload.
    for (var index = 1; index <= 24; index++) {
      final date = anniversary(start, index);
      if (date.isAfter(deadline)) break;
      if (date.isAfter(today)) dates.add(date);
    }
    if (deadline.isAfter(today) && (dates.isEmpty || dates.last != deadline)) {
      dates.add(deadline);
    }
    final ready = plan.savings != null &&
        plan.income != null &&
        plan.livingCosts != null &&
        monthlyCommitments >= 0;
    final gap = max(0, plan.target - (plan.savings ?? 0));
    final required = dates.isEmpty ? gap : (gap / dates.length).ceil();
    final capacity = (plan.income ?? 0) -
        monthlyCommitments -
        (plan.livingCosts ?? 0) -
        plan.reserve;
    final shortfall = max(0, required - capacity);
    final livingCeiling =
        (plan.income ?? 0) - monthlyCommitments - plan.reserve - required;
    final daysInMonth = DateTime.utc(today.year, today.month + 1, 0).day;
    final checkpoints = <SavingsPlanCheckpoint>[];
    for (var i = 0; i < dates.length; i++) {
      checkpoints.add(
        SavingsPlanCheckpoint(
          dates[i],
          min(plan.target, (plan.savings ?? 0) + required * (i + 1)),
          max(0, (plan.savings ?? 0) + capacity * (i + 1)),
        ),
      );
    }
    return SavingsPlanResult(
      ready: ready,
      expired: !deadline.isAfter(today),
      requiredMonthlySavings: required,
      monthlyCapacity: capacity,
      monthlyShortfall: shortfall,
      monthlyLivingCeiling: livingCeiling,
      dailyLivingBudget: ready && shortfall == 0 && dates.isNotEmpty
          ? (plan.livingCosts! / daysInMonth).floor()
          : null,
      checkpoints: List.unmodifiable(checkpoints),
    );
  }
}
