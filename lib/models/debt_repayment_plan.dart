enum DebtRepaymentStrategy { snowball, avalanche, dueDate, hybrid }

class DebtRepaymentInputDebt {
  final String name;
  final double balance;
  final double annualRate;
  final double minimumPaymentRate;
  final double minimumPaymentFloor;
  final int? paymentDay;

  const DebtRepaymentInputDebt({
    required this.name,
    required this.balance,
    required this.annualRate,
    required this.minimumPaymentRate,
    required this.minimumPaymentFloor,
    this.paymentDay,
  });
}

class DebtRepaymentPlanInput {
  final List<DebtRepaymentInputDebt> debts;
  final DebtRepaymentStrategy strategy;
  final int monthlyBudget;
  final int extraBudget;
  final int targetMonths;
  final int monthlyIncome;
  final int monthlyExpense;
  final int fixedCost;
  final double netWorth;
  final String note;
  final DateTime baseMonth;

  const DebtRepaymentPlanInput({
    required this.debts,
    required this.strategy,
    required this.monthlyBudget,
    required this.extraBudget,
    required this.targetMonths,
    required this.monthlyIncome,
    required this.monthlyExpense,
    required this.fixedCost,
    required this.netWorth,
    required this.note,
    required this.baseMonth,
  });
}

class DebtPriorityItem {
  final int rank;
  final String name;
  final double balance;
  final double annualRate;
  final int? paymentDay;
  final String reason;

  const DebtPriorityItem({
    required this.rank,
    required this.name,
    required this.balance,
    required this.annualRate,
    this.paymentDay,
    required this.reason,
  });
}

class DebtMonthlyAction {
  final int monthIndex;
  final DateTime monthStart;
  final String? focusDebt;
  final double paymentTotal;
  final double minimumTotal;
  final double extraTotal;
  final double interestTotal;
  final double remainingDebt;
  final bool isBudgetShortfall;
  final List<String> closedDebts;

  const DebtMonthlyAction({
    required this.monthIndex,
    required this.monthStart,
    required this.focusDebt,
    required this.paymentTotal,
    required this.minimumTotal,
    required this.extraTotal,
    required this.interestTotal,
    required this.remainingDebt,
    required this.isBudgetShortfall,
    required this.closedDebts,
  });
}

class DebtRoadmapStep {
  final String name;
  final int startMonth;
  final int? endMonth;
  final int? monthsRequired;

  const DebtRoadmapStep({
    required this.name,
    required this.startMonth,
    required this.endMonth,
    required this.monthsRequired,
  });
}

enum DebtExecutionTaskKind {
  focus,
  budget,
  fixedCost,
  payment,
  milestone,
  review,
}

class DebtExecutionTask {
  final String id;
  final DebtExecutionTaskKind kind;
  final String title;
  final String detail;
  final DateTime dueDate;

  const DebtExecutionTask({
    required this.id,
    required this.kind,
    required this.title,
    required this.detail,
    required this.dueDate,
  });
}

class DebtExecutionPlan {
  final String summary;
  final List<DebtExecutionTask> tasks;

  const DebtExecutionPlan({required this.summary, required this.tasks});
}

class DebtRepaymentPlanResult {
  final String markdown;
  final List<String> warnings;
  final List<DebtPriorityItem> priorities;
  final List<DebtMonthlyAction> monthlyActions;
  final List<DebtRoadmapStep> roadmap;
  final double requestedMonthlyBudget;
  final double affordableMonthlyBudget;
  final int? estimatedCompletionMonths;
  final bool canMeetTargetMonths;

  const DebtRepaymentPlanResult({
    required this.markdown,
    required this.warnings,
    required this.priorities,
    required this.monthlyActions,
    required this.roadmap,
    required this.requestedMonthlyBudget,
    required this.affordableMonthlyBudget,
    required this.estimatedCompletionMonths,
    required this.canMeetTargetMonths,
  });
}
