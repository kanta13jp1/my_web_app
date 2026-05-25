class DisposableBalancePayslip {
  const DisposableBalancePayslip({
    required this.payDate,
    required this.netAmount,
    this.companyName = '',
    this.confidence = 0,
  });

  final DateTime payDate;
  final double netAmount;
  final String companyName;
  final double confidence;
}

class DisposableBalanceRecurringExpense {
  const DisposableBalanceRecurringExpense({
    required this.name,
    required this.amount,
    this.dayOfMonth = 1,
    this.category = 'fixed',
    this.pausedAt,
  });

  final String name;
  final double amount;
  final int dayOfMonth;
  final String category;
  final DateTime? pausedAt;
}

class DisposableBalanceDebt {
  const DisposableBalanceDebt({
    required this.name,
    required this.monthlyPayment,
    this.principal = 0,
    this.interestRate = 0,
    this.lender = '',
    this.lastUpdated,
    this.pausedAt,
  });

  final String name;
  final double principal;
  final double monthlyPayment;
  final double interestRate;
  final String lender;
  final DateTime? lastUpdated;
  final DateTime? pausedAt;
}

class DisposableBalanceActionRecommendation {
  const DisposableBalanceActionRecommendation({
    required this.actionKey,
    required this.priority,
    required this.title,
    required this.instruction,
    required this.estimatedSeconds,
    required this.amountImpact,
    required this.category,
  });

  final String actionKey;
  final int priority;
  final String title;
  final String instruction;
  final int estimatedSeconds;
  final double amountImpact;
  final String category;
}

class DisposableBalanceResult {
  const DisposableBalanceResult({
    required this.asOfDate,
    required this.nextPayday,
    required this.daysRemaining,
    required this.salaryDay,
    required this.income,
    required this.fixedTotal,
    required this.debtTotal,
    required this.disposable,
    required this.dailyPace,
    required this.requiredActions,
  });

  final DateTime asOfDate;
  final DateTime nextPayday;
  final int daysRemaining;
  final int salaryDay;
  final double income;
  final double fixedTotal;
  final double debtTotal;
  final double disposable;
  final double dailyPace;
  final List<DisposableBalanceActionRecommendation> requiredActions;
}

class DisposableBalanceService {
  const DisposableBalanceService();

  static const int defaultSalaryDay = 25;

  DisposableBalanceResult build({
    required DateTime asOfDate,
    Iterable<DisposableBalancePayslip> payslips =
        const <DisposableBalancePayslip>[],
    Iterable<DisposableBalanceRecurringExpense> recurringExpenses =
        const <DisposableBalanceRecurringExpense>[],
    Iterable<DisposableBalanceDebt> debts = const <DisposableBalanceDebt>[],
    int salaryDay = defaultSalaryDay,
  }) {
    final normalizedAsOf = _dateOnly(asOfDate);
    final normalizedSalaryDay = salaryDay.clamp(1, 28).toInt();
    final nextPayday = nextPaydayFor(
      asOfDate: normalizedAsOf,
      salaryDay: normalizedSalaryDay,
    );
    final cycleStart = salaryCycleStartFor(
      asOfDate: normalizedAsOf,
      salaryDay: normalizedSalaryDay,
    );
    final daysRemaining =
        (nextPayday.difference(normalizedAsOf).inDays - 1).clamp(1, 366);

    final sortedPayslips = payslips.toList(growable: false)
      ..sort((a, b) => b.payDate.compareTo(a.payDate));
    DisposableBalancePayslip? currentPayslip;
    for (final payslip in sortedPayslips) {
      final payDate = _dateOnly(payslip.payDate);
      if (!payDate.isBefore(cycleStart) && payDate.isBefore(nextPayday)) {
        currentPayslip = payslip;
        break;
      }
    }
    final fallbackPayslip =
        sortedPayslips.isEmpty ? null : sortedPayslips.first;
    final income = (currentPayslip ?? fallbackPayslip)?.netAmount ?? 0;
    final activeRecurring = recurringExpenses
        .where((expense) => expense.pausedAt == null)
        .toList(growable: false);
    final activeDebts =
        debts.where((debt) => debt.pausedAt == null).toList(growable: false);
    final fixedTotal = activeRecurring.fold<double>(
      0,
      (sum, expense) => sum + expense.amount.abs(),
    );
    final debtTotal = activeDebts.fold<double>(
      0,
      (sum, debt) => sum + debt.monthlyPayment.abs(),
    );
    final disposable = income - fixedTotal - debtTotal;
    final dailyPace = disposable / daysRemaining;
    final actions = _buildActions(
      asOfDate: normalizedAsOf,
      currentPayslip: currentPayslip,
      fallbackPayslip: fallbackPayslip,
      recurringExpenses: activeRecurring,
      debts: activeDebts,
    );

    return DisposableBalanceResult(
      asOfDate: normalizedAsOf,
      nextPayday: nextPayday,
      daysRemaining: daysRemaining,
      salaryDay: normalizedSalaryDay,
      income: income,
      fixedTotal: fixedTotal,
      debtTotal: debtTotal,
      disposable: disposable,
      dailyPace: dailyPace,
      requiredActions: List<DisposableBalanceActionRecommendation>.unmodifiable(
        actions,
      ),
    );
  }

  DateTime nextPaydayFor({
    required DateTime asOfDate,
    int salaryDay = defaultSalaryDay,
  }) {
    final normalizedAsOf = _dateOnly(asOfDate);
    final normalizedSalaryDay = salaryDay.clamp(1, 28).toInt();
    final currentMonthPayday = _safeDate(
      normalizedAsOf.year,
      normalizedAsOf.month,
      normalizedSalaryDay,
    );
    if (normalizedAsOf.isBefore(currentMonthPayday)) {
      return currentMonthPayday;
    }
    return _safeDate(
      normalizedAsOf.year,
      normalizedAsOf.month + 1,
      normalizedSalaryDay,
    );
  }

  DateTime salaryCycleStartFor({
    required DateTime asOfDate,
    int salaryDay = defaultSalaryDay,
  }) {
    final nextPayday = nextPaydayFor(asOfDate: asOfDate, salaryDay: salaryDay);
    return _safeDate(nextPayday.year, nextPayday.month - 1, salaryDay);
  }

  List<DisposableBalanceActionRecommendation> _buildActions({
    required DateTime asOfDate,
    required DisposableBalancePayslip? currentPayslip,
    required DisposableBalancePayslip? fallbackPayslip,
    required List<DisposableBalanceRecurringExpense> recurringExpenses,
    required List<DisposableBalanceDebt> debts,
  }) {
    final actions = <DisposableBalanceActionRecommendation>[];
    if (currentPayslip == null) {
      actions.add(
        DisposableBalanceActionRecommendation(
          actionKey: 'upload_current_payslip',
          priority: actions.length + 1,
          title: 'Current payslip is missing',
          instruction:
              'Upload the latest payslip PDF so income uses source data (10 sec).',
          estimatedSeconds: 10,
          amountImpact: fallbackPayslip?.netAmount ?? 0,
          category: 'data_gap',
        ),
      );
    }
    if (recurringExpenses.isEmpty) {
      actions.add(
        DisposableBalanceActionRecommendation(
          actionKey: 'add_recurring_expenses',
          priority: actions.length + 1,
          title: 'Fixed expenses are not registered',
          instruction:
              'Add rent, utilities, and subscriptions as recurring expenses (180 sec).',
          estimatedSeconds: 180,
          amountImpact: 0,
          category: 'data_gap',
        ),
      );
    }
    for (final debt in debts) {
      final lastUpdated = debt.lastUpdated;
      if (lastUpdated == null) continue;
      final ageDays = asOfDate.difference(_dateOnly(lastUpdated)).inDays;
      if (ageDays >= 60) {
        actions.add(
          DisposableBalanceActionRecommendation(
            actionKey: 'refresh_debt_${_slugify(debt.name)}',
            priority: actions.length + 1,
            title: '${debt.name} balance is stale',
            instruction:
                'Enter the current ${debt.name} balance before deciding repayment order (60 sec).',
            estimatedSeconds: 60,
            amountImpact: debt.monthlyPayment,
            category: 'debt_refresh',
          ),
        );
        break;
      }
    }
    final duplicate = _findDuplicateSubscription(recurringExpenses);
    if (duplicate != null) {
      actions.add(
        DisposableBalanceActionRecommendation(
          actionKey: 'cancel_duplicate_${duplicate.group}',
          priority: actions.length + 1,
          title: '${duplicate.group} subscriptions overlap',
          instruction:
              'Choose one ${duplicate.group} subscription and cancel the other (${duplicate.savings.round()} JPY/month, 120 sec).',
          estimatedSeconds: 120,
          amountImpact: duplicate.savings,
          category: 'savings',
        ),
      );
    }
    return actions
        .asMap()
        .entries
        .map(
          (entry) => DisposableBalanceActionRecommendation(
            actionKey: entry.value.actionKey,
            priority: entry.key + 1,
            title: entry.value.title,
            instruction: entry.value.instruction,
            estimatedSeconds: entry.value.estimatedSeconds,
            amountImpact: entry.value.amountImpact,
            category: entry.value.category,
          ),
        )
        .take(5)
        .toList(growable: false);
  }

  _DuplicateSubscription? _findDuplicateSubscription(
    List<DisposableBalanceRecurringExpense> expenses,
  ) {
    final groups = <String, List<DisposableBalanceRecurringExpense>>{};
    for (final expense in expenses) {
      final name = expense.name.toLowerCase();
      final group = name.contains('spotify') ||
              name.contains('apple music') ||
              name.contains('youtube music')
          ? 'music'
          : name.contains('netflix') ||
                  name.contains('hulu') ||
                  name.contains('disney')
              ? 'video'
              : null;
      if (group == null) continue;
      groups.putIfAbsent(group, () => <DisposableBalanceRecurringExpense>[]);
      groups[group]!.add(expense);
    }
    for (final entry in groups.entries) {
      if (entry.value.length > 1) {
        final amounts =
            entry.value.map((expense) => expense.amount.abs()).toList()..sort();
        return _DuplicateSubscription(entry.key, amounts.first);
      }
    }
    return null;
  }

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime _safeDate(int year, int month, int day) {
    final firstOfMonth = DateTime(year, month, 1);
    final lastDay = DateTime(firstOfMonth.year, firstOfMonth.month + 1, 0).day;
    return DateTime(
      firstOfMonth.year,
      firstOfMonth.month,
      day.clamp(1, lastDay).toInt(),
    );
  }

  static String _slugify(String value) {
    final slug = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return slug.isEmpty ? 'debt' : slug;
  }
}

class _DuplicateSubscription {
  const _DuplicateSubscription(this.group, this.savings);

  final String group;
  final double savings;
}
