import 'dart:math';

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
    this.principalPayment = 0,
    this.interestPayment = 0,
    this.interestRate = 0,
    this.lender = '',
    this.dayOfMonth,
    this.lastUpdated,
    this.pausedAt,
  });

  final String name;
  final double principal;
  final double principalPayment;
  final double interestPayment;
  final double monthlyPayment;
  final double interestRate;
  final String lender;
  final int? dayOfMonth;
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
    required this.debtPrincipalTotal,
    required this.debtInterestTotal,
    required this.debtReductionSpendingLimit,
    required this.disposable,
    required this.dailyPace,
    required this.recurringExpenses,
    required this.debts,
    required this.requiredActions,
  });

  final DateTime asOfDate;
  final DateTime nextPayday;
  final int daysRemaining;
  final int salaryDay;
  final double income;
  final double fixedTotal;
  final double debtTotal;
  final double debtPrincipalTotal;
  final double debtInterestTotal;
  final double debtReductionSpendingLimit;
  final double disposable;
  final double dailyPace;
  final List<DisposableBalanceRecurringExpense> recurringExpenses;
  final List<DisposableBalanceDebt> debts;
  final List<DisposableBalanceActionRecommendation> requiredActions;
}

/// サーバー提案と端末側の決定的な不足判定を統合する。
///
/// 給与明細・固定費の登録有無は端末側の最新入力を正とし、サーバーの古い結果で
/// 表示を消したり復活させたりしない。節約・負債更新など他の提案はキー単位で
/// 重複を除いて追加する。
class DisposableBalanceActionMergeService {
  const DisposableBalanceActionMergeService();

  static const Set<String> _localAuthoritativeActionKeys = <String>{
    'upload_current_payslip',
    'add_recurring_expenses',
  };

  List<Map<String, dynamic>> merge({
    required Iterable<Map<String, dynamic>> serverActions,
    required Iterable<Map<String, dynamic>> localActions,
  }) {
    final local =
        localActions.map(Map<String, dynamic>.from).toList(growable: false);
    final server =
        serverActions.map(Map<String, dynamic>.from).toList(growable: false);
    final merged = <Map<String, dynamic>>[];
    final seenKeys = <String>{};

    void add(Map<String, dynamic> action) {
      final key = _actionKey(action);
      if (key.isNotEmpty && !seenKeys.add(key)) {
        return;
      }
      merged.add(action);
    }

    for (final action in local) {
      if (_localAuthoritativeActionKeys.contains(_actionKey(action))) {
        add(action);
      }
    }
    for (final action in server) {
      if (_localAuthoritativeActionKeys.contains(_actionKey(action))) {
        continue;
      }
      add(action);
    }
    for (final action in local) {
      if (!_localAuthoritativeActionKeys.contains(_actionKey(action))) {
        add(action);
      }
    }

    return List<Map<String, dynamic>>.unmodifiable(merged);
  }

  String _actionKey(Map<String, dynamic> action) =>
      (action['action_key'] ?? action['actionKey'])?.toString().trim() ?? '';
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
    final debtInterestTotal = activeDebts.fold<double>(
      0,
      (sum, debt) => sum + _interestPaymentFor(debt),
    );
    final debtPrincipalTotal = activeDebts.fold<double>(
      0,
      (sum, debt) => sum + _principalPaymentFor(debt),
    );
    final disposable = income - fixedTotal - debtTotal;
    final debtReductionSpendingLimit = disposable;
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
      debtPrincipalTotal: debtPrincipalTotal,
      debtInterestTotal: debtInterestTotal,
      debtReductionSpendingLimit: debtReductionSpendingLimit,
      disposable: disposable,
      dailyPace: dailyPace,
      recurringExpenses: List<DisposableBalanceRecurringExpense>.unmodifiable(
        activeRecurring,
      ),
      debts: List<DisposableBalanceDebt>.unmodifiable(activeDebts),
      requiredActions: List<DisposableBalanceActionRecommendation>.unmodifiable(
        actions,
      ),
    );
  }

  double interestPaymentFor(DisposableBalanceDebt debt) =>
      _interestPaymentFor(debt);

  double principalPaymentFor(DisposableBalanceDebt debt) =>
      _principalPaymentFor(debt);

  static double _interestPaymentFor(DisposableBalanceDebt debt) {
    return _paymentSplitFor(debt).interest;
  }

  static double _principalPaymentFor(DisposableBalanceDebt debt) {
    return _paymentSplitFor(debt).principal;
  }

  static _DebtPaymentSplit _paymentSplitFor(DisposableBalanceDebt debt) {
    final monthlyPayment = debt.monthlyPayment.abs();
    if (monthlyPayment <= 0) {
      return const _DebtPaymentSplit(principal: 0, interest: 0);
    }
    final explicitPrincipal =
        debt.principalPayment > 0 ? debt.principalPayment.abs() : 0.0;
    final explicitInterest =
        debt.interestPayment > 0 ? debt.interestPayment.abs() : 0.0;
    final hasExplicitPrincipal = explicitPrincipal > 0;
    final hasExplicitInterest = explicitInterest > 0;
    var interest = hasExplicitInterest
        ? explicitInterest
        : hasExplicitPrincipal
            ? max(0.0, monthlyPayment - explicitPrincipal)
            : debt.principal.abs() * max(0.0, debt.interestRate) / 12;
    interest = min(monthlyPayment, max(0.0, interest));

    var principal = hasExplicitPrincipal
        ? explicitPrincipal
        : max(0.0, monthlyPayment - interest);
    principal = min(monthlyPayment, max(0.0, principal));

    if (principal + interest > monthlyPayment) {
      if (hasExplicitInterest) {
        principal = max(0.0, monthlyPayment - interest);
      } else {
        interest = max(0.0, monthlyPayment - principal);
      }
    }
    return _DebtPaymentSplit(principal: principal, interest: interest);
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
          title: '今月の給与明細が未登録です',
          instruction: '最新の給与明細PDFをアップロードして、収入を明細データで計算してください（約10秒）。',
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
          title: '固定費が未登録です',
          instruction: '家賃・公共料金・サブスクを固定費として登録してください（約180秒）。',
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
            title: '${debt.name}の残高が古くなっています',
            instruction: '返済順を決める前に、${debt.name}の現在残高を入力してください（約60秒）。',
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
          title: '${_duplicateGroupLabel(duplicate.group)}サブスクが重複しています',
          instruction:
              '${_duplicateGroupLabel(duplicate.group)}サブスクを1つに絞ると、毎月${duplicate.savings.round()}円を削減できます（約120秒）。',
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

  static String _duplicateGroupLabel(String group) {
    switch (group) {
      case 'music':
        return '音楽';
      case 'video':
        return '動画';
    }
    return group;
  }
}

class _DebtPaymentSplit {
  const _DebtPaymentSplit({
    required this.principal,
    required this.interest,
  });

  final double principal;
  final double interest;
}

class _DuplicateSubscription {
  const _DuplicateSubscription(this.group, this.savings);

  final String group;
  final double savings;
}
