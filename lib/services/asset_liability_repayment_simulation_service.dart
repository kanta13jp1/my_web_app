import 'dart:math';

import 'package:my_web_app/models/asset_liability_workbook.dart';

enum AssetLiabilityRepaymentSimulationStrategy {
  interestRate,
  smallestBalance,
  paymentDay,
}

class AssetLiabilityRepaymentSimulationResult {
  final double baseMonthlyPayment;
  final double extraMonthlyPayment;
  final int eligibleDebtCount;
  final List<AssetLiabilityRepaymentSimulationPlan> baselinePlans;
  final List<AssetLiabilityRepaymentSimulationPlan> plans;

  const AssetLiabilityRepaymentSimulationResult({
    required this.baseMonthlyPayment,
    required this.extraMonthlyPayment,
    required this.eligibleDebtCount,
    required this.baselinePlans,
    required this.plans,
  });

  bool get hasEligibleDebt => eligibleDebtCount > 0;

  AssetLiabilityRepaymentSimulationPlan? planFor(
    AssetLiabilityRepaymentSimulationStrategy strategy,
  ) {
    for (final plan in plans) {
      if (plan.strategy == strategy) return plan;
    }
    return null;
  }

  AssetLiabilityRepaymentSimulationPlan? baselinePlanFor(
    AssetLiabilityRepaymentSimulationStrategy strategy,
  ) {
    for (final plan in baselinePlans) {
      if (plan.strategy == strategy) return plan;
    }
    return null;
  }
}

class AssetLiabilityRepaymentSimulationPlan {
  final AssetLiabilityRepaymentSimulationStrategy strategy;
  final double startingBalanceTotal;
  final double baseMonthlyPayment;
  final double extraMonthlyPayment;
  final double monthlyPaymentBudget;
  final double estimatedInterestTotal;
  final int? estimatedPayoffMonths;
  final List<AssetLiabilityRepaymentPriorityDebt> priorityRows;
  final List<AssetLiabilityRepaymentMonthSnapshot> monthSnapshots;
  final List<String> warnings;

  const AssetLiabilityRepaymentSimulationPlan({
    required this.strategy,
    required this.startingBalanceTotal,
    required this.baseMonthlyPayment,
    required this.extraMonthlyPayment,
    required this.monthlyPaymentBudget,
    required this.estimatedInterestTotal,
    required this.estimatedPayoffMonths,
    required this.priorityRows,
    required this.monthSnapshots,
    required this.warnings,
  });

  String? get firstFocusDebtName =>
      priorityRows.isEmpty ? null : priorityRows.first.name;
}

class AssetLiabilityRepaymentPriorityDebt {
  final String id;
  final String name;
  final double balance;
  final double annualRate;
  final int? paymentDay;
  final double monthlyPayment;

  const AssetLiabilityRepaymentPriorityDebt({
    required this.id,
    required this.name,
    required this.balance,
    required this.annualRate,
    required this.paymentDay,
    required this.monthlyPayment,
  });
}

class AssetLiabilityRepaymentMonthSnapshot {
  final int monthIndex;
  final String? focusDebtName;
  final double paymentTotal;
  final double interestTotal;
  final double remainingDebt;
  final List<String> closedDebtNames;

  const AssetLiabilityRepaymentMonthSnapshot({
    required this.monthIndex,
    required this.focusDebtName,
    required this.paymentTotal,
    required this.interestTotal,
    required this.remainingDebt,
    required this.closedDebtNames,
  });
}

class AssetLiabilityRepaymentSimulationService {
  const AssetLiabilityRepaymentSimulationService();

  static const double _epsilon = 0.01;
  static const int _defaultMaxMonths = 360;

  AssetLiabilityRepaymentSimulationResult buildComparison({
    required AssetLiabilityWorkbook workbook,
    double extraMonthlyPayment = 0,
    int maxMonths = _defaultMaxMonths,
  }) {
    final sourceDebts = workbook.debtMasterRows
        .where(_isEligibleDebt)
        .map(_SimulationDebt.fromRow)
        .toList(growable: false);
    final baseMonthlyPayment = sourceDebts.fold<double>(
      0,
      (sum, debt) => sum + debt.monthlyPayment,
    );
    final normalizedExtra = max(0.0, extraMonthlyPayment);
    final resolvedMaxMonths = max(1, maxMonths);

    final baselinePlans = <AssetLiabilityRepaymentSimulationPlan>[
      for (final strategy in AssetLiabilityRepaymentSimulationStrategy.values)
        _simulate(
          sourceDebts: sourceDebts,
          strategy: strategy,
          baseMonthlyPayment: baseMonthlyPayment,
          extraMonthlyPayment: 0,
          maxMonths: resolvedMaxMonths,
        ),
    ];
    final plans = <AssetLiabilityRepaymentSimulationPlan>[
      for (final strategy in AssetLiabilityRepaymentSimulationStrategy.values)
        _simulate(
          sourceDebts: sourceDebts,
          strategy: strategy,
          baseMonthlyPayment: baseMonthlyPayment,
          extraMonthlyPayment: normalizedExtra,
          maxMonths: resolvedMaxMonths,
        ),
    ];

    return AssetLiabilityRepaymentSimulationResult(
      baseMonthlyPayment: baseMonthlyPayment,
      extraMonthlyPayment: normalizedExtra,
      eligibleDebtCount: sourceDebts.length,
      baselinePlans: baselinePlans,
      plans: plans,
    );
  }

  bool _isEligibleDebt(AssetLiabilityDebtRow row) {
    return row.balance < -_epsilon &&
        !row.paid &&
        row.isDirectCashflowTarget &&
        !row.includedInBillingAccount;
  }

  AssetLiabilityRepaymentSimulationPlan _simulate({
    required List<_SimulationDebt> sourceDebts,
    required AssetLiabilityRepaymentSimulationStrategy strategy,
    required double baseMonthlyPayment,
    required double extraMonthlyPayment,
    required int maxMonths,
  }) {
    final states = sourceDebts.map((debt) => debt.copy()).toList();
    final priorityRows = sourceDebts.map((debt) => debt.copy()).toList()
      ..sort((a, b) => _compareDebts(a, b, strategy));
    final startingBalanceTotal = states.fold<double>(
      0.0,
      (sum, debt) => sum + debt.balance,
    );
    final monthlyPaymentBudget = max(
      0.0,
      baseMonthlyPayment + extraMonthlyPayment,
    );
    final snapshots = <AssetLiabilityRepaymentMonthSnapshot>[];
    final warnings = <String>[];

    if (states.isEmpty) {
      return AssetLiabilityRepaymentSimulationPlan(
        strategy: strategy,
        startingBalanceTotal: 0,
        baseMonthlyPayment: baseMonthlyPayment,
        extraMonthlyPayment: extraMonthlyPayment,
        monthlyPaymentBudget: monthlyPaymentBudget,
        estimatedInterestTotal: 0,
        estimatedPayoffMonths: 0,
        priorityRows: const <AssetLiabilityRepaymentPriorityDebt>[],
        monthSnapshots: const <AssetLiabilityRepaymentMonthSnapshot>[],
        warnings: const <String>[],
      );
    }

    if (monthlyPaymentBudget <= _epsilon) {
      warnings.add('毎月返済額が0円です');
      return AssetLiabilityRepaymentSimulationPlan(
        strategy: strategy,
        startingBalanceTotal: startingBalanceTotal,
        baseMonthlyPayment: baseMonthlyPayment,
        extraMonthlyPayment: extraMonthlyPayment,
        monthlyPaymentBudget: monthlyPaymentBudget,
        estimatedInterestTotal: 0,
        estimatedPayoffMonths: null,
        priorityRows: _toPriorityRows(priorityRows),
        monthSnapshots: const <AssetLiabilityRepaymentMonthSnapshot>[],
        warnings: warnings,
      );
    }

    var estimatedInterestTotal = 0.0;
    int? estimatedPayoffMonths;
    var budgetShortfallDetected = false;

    for (var monthIndex = 1; monthIndex <= maxMonths; monthIndex++) {
      final active = states.where((debt) => debt.balance > _epsilon).toList();
      if (active.isEmpty) {
        estimatedPayoffMonths = monthIndex - 1;
        break;
      }

      var monthInterestTotal = 0.0;
      for (final debt in active) {
        final interest = debt.balance * debt.annualRate / 12;
        debt.balance += interest;
        monthInterestTotal += interest;
      }
      estimatedInterestTotal += monthInterestTotal;

      active.sort((a, b) => _compareDebts(a, b, strategy));
      final minimumById = <String, double>{};
      var minimumTotal = 0.0;
      for (final debt in active) {
        final minimum = min(debt.monthlyPayment, debt.balance);
        minimumById[debt.id] = minimum;
        minimumTotal += minimum;
      }

      var remainingBudget = monthlyPaymentBudget;
      var paymentTotal = 0.0;
      final closedDebtNames = <String>[];
      final focusDebtName = active.isEmpty ? null : active.first.name;

      if (remainingBudget + _epsilon < minimumTotal) {
        budgetShortfallDetected = true;
        for (final debt in active) {
          if (remainingBudget <= _epsilon) break;
          final paid = _applyPayment(
            debt: debt,
            payment: min(remainingBudget, minimumById[debt.id] ?? 0),
            closedDebtNames: closedDebtNames,
          );
          paymentTotal += paid;
          remainingBudget -= paid;
        }
      } else {
        for (final debt in active) {
          final paid = _applyPayment(
            debt: debt,
            payment: minimumById[debt.id] ?? 0,
            closedDebtNames: closedDebtNames,
          );
          paymentTotal += paid;
          remainingBudget -= paid;
        }

        while (remainingBudget > _epsilon) {
          final target = _firstActiveDebt(active);
          if (target == null) break;
          final paid = _applyPayment(
            debt: target,
            payment: remainingBudget,
            closedDebtNames: closedDebtNames,
          );
          if (paid <= _epsilon) break;
          paymentTotal += paid;
          remainingBudget -= paid;
        }
      }

      final remainingDebt = states.fold<double>(
        0,
        (sum, debt) => sum + max(0.0, debt.balance),
      );
      snapshots.add(
        AssetLiabilityRepaymentMonthSnapshot(
          monthIndex: monthIndex,
          focusDebtName: focusDebtName,
          paymentTotal: paymentTotal,
          interestTotal: monthInterestTotal,
          remainingDebt: remainingDebt,
          closedDebtNames: closedDebtNames,
        ),
      );

      if (remainingDebt <= _epsilon) {
        estimatedPayoffMonths = monthIndex;
        break;
      }
    }

    if (budgetShortfallDetected) {
      warnings.add('毎月返済額が今月の支払予定額を下回っています');
    }
    if (estimatedPayoffMonths == null) {
      warnings.add('$maxMonthsか月以内に完済できません');
    }

    return AssetLiabilityRepaymentSimulationPlan(
      strategy: strategy,
      startingBalanceTotal: startingBalanceTotal,
      baseMonthlyPayment: baseMonthlyPayment,
      extraMonthlyPayment: extraMonthlyPayment,
      monthlyPaymentBudget: monthlyPaymentBudget,
      estimatedInterestTotal: estimatedInterestTotal,
      estimatedPayoffMonths: estimatedPayoffMonths,
      priorityRows: _toPriorityRows(priorityRows),
      monthSnapshots: snapshots,
      warnings: warnings,
    );
  }

  List<AssetLiabilityRepaymentPriorityDebt> _toPriorityRows(
    List<_SimulationDebt> debts,
  ) {
    return <AssetLiabilityRepaymentPriorityDebt>[
      for (final debt in debts)
        AssetLiabilityRepaymentPriorityDebt(
          id: debt.id,
          name: debt.name,
          balance: debt.balance,
          annualRate: debt.annualRate,
          paymentDay: debt.paymentDay,
          monthlyPayment: debt.monthlyPayment,
        ),
    ];
  }

  _SimulationDebt? _firstActiveDebt(List<_SimulationDebt> debts) {
    for (final debt in debts) {
      if (debt.balance > _epsilon) return debt;
    }
    return null;
  }

  double _applyPayment({
    required _SimulationDebt debt,
    required double payment,
    required List<String> closedDebtNames,
  }) {
    if (payment <= _epsilon || debt.balance <= _epsilon) return 0;
    final paid = min(payment, debt.balance);
    debt.balance = max(0.0, debt.balance - paid);
    if (debt.balance <= _epsilon) {
      closedDebtNames.add(debt.name);
    }
    return paid;
  }

  int _compareDebts(
    _SimulationDebt a,
    _SimulationDebt b,
    AssetLiabilityRepaymentSimulationStrategy strategy,
  ) {
    switch (strategy) {
      case AssetLiabilityRepaymentSimulationStrategy.interestRate:
        final byRate = b.annualRate.compareTo(a.annualRate);
        if (byRate != 0) return byRate;
        final byBalance = a.balance.compareTo(b.balance);
        if (byBalance != 0) return byBalance;
        return _comparePaymentDay(a, b);
      case AssetLiabilityRepaymentSimulationStrategy.smallestBalance:
        final byBalance = a.balance.compareTo(b.balance);
        if (byBalance != 0) return byBalance;
        final byRate = b.annualRate.compareTo(a.annualRate);
        if (byRate != 0) return byRate;
        return _comparePaymentDay(a, b);
      case AssetLiabilityRepaymentSimulationStrategy.paymentDay:
        final byPaymentDay = _comparePaymentDay(a, b);
        if (byPaymentDay != 0) return byPaymentDay;
        final byRate = b.annualRate.compareTo(a.annualRate);
        if (byRate != 0) return byRate;
        return a.balance.compareTo(b.balance);
    }
  }

  int _comparePaymentDay(_SimulationDebt a, _SimulationDebt b) {
    final byPaymentDay = (a.paymentDay ?? 99).compareTo(b.paymentDay ?? 99);
    if (byPaymentDay != 0) return byPaymentDay;
    return a.name.compareTo(b.name);
  }
}

class _SimulationDebt {
  final String id;
  final String name;
  double balance;
  final double annualRate;
  final int? paymentDay;
  final double monthlyPayment;

  _SimulationDebt({
    required this.id,
    required this.name,
    required this.balance,
    required this.annualRate,
    required this.paymentDay,
    required this.monthlyPayment,
  });

  factory _SimulationDebt.fromRow(AssetLiabilityDebtRow row) {
    return _SimulationDebt(
      id: row.id,
      name: row.name,
      balance: row.balance.abs(),
      annualRate: max(0.0, row.annualRate),
      paymentDay: row.paymentDay,
      monthlyPayment: max(0.0, row.scheduledPaymentAmount),
    );
  }

  _SimulationDebt copy() {
    return _SimulationDebt(
      id: id,
      name: name,
      balance: balance,
      annualRate: annualRate,
      paymentDay: paymentDay,
      monthlyPayment: monthlyPayment,
    );
  }
}
