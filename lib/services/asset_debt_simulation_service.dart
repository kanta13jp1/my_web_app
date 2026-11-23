import 'dart:math';

import 'package:my_web_app/models/asset_liability_workbook.dart';

/// 複数借入・おまとめローン試算に使う個別借入の入力モデル (#1369 / #2750)。
class MultiDebtInputItem {
  final String id;
  final String name;
  final double balance;
  final double annualRate;
  final double monthlyPayment;
  final int daysUntilNextPayment;

  const MultiDebtInputItem({
    required this.id,
    required this.name,
    required this.balance,
    required this.annualRate,
    required this.monthlyPayment,
    this.daysUntilNextPayment = 30,
  });

  factory MultiDebtInputItem.fromDebtRow(
    AssetLiabilityDebtRow row, {
    DateTime? baseDate,
  }) {
    final payment = row.scheduledPaymentAmount > 0
        ? row.scheduledPaymentAmount
        : row.minimumPaymentEstimate;
    final days = (baseDate != null && row.paymentDay != null)
        ? _computeDaysUntilNextPayment(baseDate, row.paymentDay!)
        : 30;
    return MultiDebtInputItem(
      id: row.id,
      name: row.name,
      balance: row.balance.abs(),
      annualRate: max(0.0, row.annualRate),
      monthlyPayment: max(0.0, payment),
      daysUntilNextPayment: days,
    );
  }

  static int _computeDaysUntilNextPayment(DateTime baseDate, int paymentDay) {
    final clampedDay = paymentDay.clamp(1, 31);
    final today = DateTime(baseDate.year, baseDate.month, baseDate.day);
    final daysInCurrentMonth = DateTime(today.year, today.month + 1, 0).day;
    var candidate = DateTime(
      today.year,
      today.month,
      min(clampedDay, daysInCurrentMonth),
    );
    if (!candidate.isAfter(today)) {
      final nextMonth = DateTime(today.year, today.month + 1, 1);
      final daysInNextMonth =
          DateTime(nextMonth.year, nextMonth.month + 1, 0).day;
      candidate = DateTime(
        nextMonth.year,
        nextMonth.month,
        min(clampedDay, daysInNextMonth),
      );
    }
    return candidate.difference(today).inDays.clamp(1, 31);
  }

  MultiDebtInputItem copyWith({
    String? id,
    String? name,
    double? balance,
    double? annualRate,
    double? monthlyPayment,
    int? daysUntilNextPayment,
  }) {
    return MultiDebtInputItem(
      id: id ?? this.id,
      name: name ?? this.name,
      balance: balance ?? this.balance,
      annualRate: annualRate ?? this.annualRate,
      monthlyPayment: monthlyPayment ?? this.monthlyPayment,
      daysUntilNextPayment: daysUntilNextPayment ?? this.daysUntilNextPayment,
    );
  }
}

/// 日割り利息（残高 × 実質年率 ÷ 365 × 日数）と次回元金充当内訳 (#1369 AC2)。
class DailyInterestBreakdown {
  final String debtId;
  final String debtName;
  final double balance;
  final double annualRate;
  final int days;
  final double monthlyPayment;
  final double dailyInterest;
  final double principalPortion;
  final bool interestExceedsPayment;

  const DailyInterestBreakdown({
    required this.debtId,
    required this.debtName,
    required this.balance,
    required this.annualRate,
    required this.days,
    required this.monthlyPayment,
    required this.dailyInterest,
    required this.principalPortion,
    required this.interestExceedsPayment,
  });
}

/// 高金利優先（アバランチ法）での繰り上げ返済充当先。
class MultiDebtPrepaymentAllocation {
  final String debtId;
  final String debtName;
  final double annualRate;
  final double appliedAmount;
  final double remainingBalanceAfterExtra;

  const MultiDebtPrepaymentAllocation({
    required this.debtId,
    required this.debtName,
    required this.annualRate,
    required this.appliedAmount,
    required this.remainingBalanceAfterExtra,
  });
}

/// 複数借入に対する繰り上げ返済シミュレーション結果 (#1369 AC3)。
class MultiDebtSimulationSummary {
  final int? baselineMonths;
  final double baselineTotalInterest;
  final bool baselineEverPaysOff;
  final int? boostedMonths;
  final double boostedTotalInterest;
  final bool boostedEverPaysOff;
  final double extraPaymentAmount;
  final bool isMonthlyRecurring;
  final List<MultiDebtPrepaymentAllocation> allocations;
  final List<DailyInterestBreakdown> dailyBreakdowns;

  const MultiDebtSimulationSummary({
    required this.baselineMonths,
    required this.baselineTotalInterest,
    required this.baselineEverPaysOff,
    required this.boostedMonths,
    required this.boostedTotalInterest,
    required this.boostedEverPaysOff,
    required this.extraPaymentAmount,
    required this.isMonthlyRecurring,
    required this.allocations,
    required this.dailyBreakdowns,
  });

  int? get monthsSaved => (baselineMonths != null && boostedMonths != null)
      ? baselineMonths! - boostedMonths!
      : null;

  double? get interestSaved => (baselineEverPaysOff && boostedEverPaysOff)
      ? baselineTotalInterest - boostedTotalInterest
      : null;

  bool get becomesPayable => !baselineEverPaysOff && boostedEverPaysOff;
}

/// おまとめローン（借り換え）前後の比較試算結果 (#2750 AC2)。
class DebtConsolidationSimulationResult {
  final double totalPrincipal;
  final double currentMonthlyPaymentTotal;
  final int? currentPayoffMonths;
  final double currentTotalInterest;
  final bool currentEverPaysOff;
  final double weightedAverageAnnualRate;
  final double consolidatedAnnualRate;
  final int consolidatedTermMonths;
  final double consolidatedMonthlyPayment;
  final double consolidatedTotalInterest;
  final double consolidatedTotalPayment;

  const DebtConsolidationSimulationResult({
    required this.totalPrincipal,
    required this.currentMonthlyPaymentTotal,
    required this.currentPayoffMonths,
    required this.currentTotalInterest,
    required this.currentEverPaysOff,
    required this.weightedAverageAnnualRate,
    required this.consolidatedAnnualRate,
    required this.consolidatedTermMonths,
    required this.consolidatedMonthlyPayment,
    required this.consolidatedTotalInterest,
    required this.consolidatedTotalPayment,
  });

  double get monthlyPaymentDiff =>
      consolidatedMonthlyPayment - currentMonthlyPaymentTotal;

  double get monthlyPaymentSavings =>
      currentMonthlyPaymentTotal - consolidatedMonthlyPayment;

  double? get totalInterestDiff => currentEverPaysOff
      ? consolidatedTotalInterest - currentTotalInterest
      : null;

  double? get totalInterestSavings => currentEverPaysOff
      ? currentTotalInterest - consolidatedTotalInterest
      : null;

  bool get increasesTotalInterest =>
      totalInterestDiff != null && totalInterestDiff! > 0.5;
}

class _MutableDebtState {
  final String id;
  final String name;
  double balance;
  final double annualRate;
  final double monthlyPayment;

  _MutableDebtState({
    required this.id,
    required this.name,
    required this.balance,
    required this.annualRate,
    required this.monthlyPayment,
  });
}

class _PortfolioSimulationResult {
  final int? months;
  final double totalInterest;
  final bool everPaysOff;

  const _PortfolioSimulationResult({
    required this.months,
    required this.totalInterest,
    required this.everPaysOff,
  });
}

/// 複数借入の日割り利息・高金利優先繰り上げ返済・おまとめローン試算サービス (#1369 / #2750)。
class AssetDebtSimulationService {
  const AssetDebtSimulationService._();

  static const int maxSimulationMonths = 600;

  /// ワークブックの負債マスタから試算対象となる借入行を抽出し、高金利順に並べる。
  static List<MultiDebtInputItem> extractDefaultDebts(
    List<AssetLiabilityDebtRow> rows, {
    DateTime? baseDate,
  }) {
    final primary = rows
        .where(
          (row) =>
              row.balance < 0 &&
              !row.fullPaymentEstimate &&
              !row.includedInBillingAccount,
        )
        .map((row) => MultiDebtInputItem.fromDebtRow(row, baseDate: baseDate))
        .where((item) => item.balance > 0.01)
        .toList();
    final selected = primary.isNotEmpty
        ? primary
        : rows
            .where((row) => row.balance < 0 && !row.includedInBillingAccount)
            .map(
              (row) => MultiDebtInputItem.fromDebtRow(row, baseDate: baseDate),
            )
            .where((item) => item.balance > 0.01)
            .toList();
    selected.sort((a, b) {
      final rateCmp = b.annualRate.compareTo(a.annualRate);
      if (rateCmp != 0) return rateCmp;
      return b.balance.compareTo(a.balance);
    });
    return selected;
  }

  /// 日割り利息（残高 × 実質年率 ÷ 365 × 日数）と次回元金充当額を算出する。
  static DailyInterestBreakdown calculateDailyInterest(
    MultiDebtInputItem item,
  ) {
    final bal = max(0.0, item.balance);
    final rate = max(0.0, item.annualRate);
    final days = item.daysUntilNextPayment.clamp(1, 365);
    final pay = max(0.0, item.monthlyPayment);
    final dailyInterest = bal * rate / 365.0 * days;
    final principalPortion = max(0.0, pay - dailyInterest);
    final interestExceedsPayment = bal > 0 && rate > 0 && dailyInterest >= pay;
    return DailyInterestBreakdown(
      debtId: item.id,
      debtName: item.name,
      balance: bal,
      annualRate: rate,
      days: days,
      monthlyPayment: pay,
      dailyInterest: dailyInterest,
      principalPortion: principalPortion,
      interestExceedsPayment: interestExceedsPayment,
    );
  }

  static _PortfolioSimulationResult _simulatePortfolio(
    List<MultiDebtInputItem> debts, {
    double monthlyExtra = 0,
  }) {
    final active = debts
        .where((d) => d.balance > 0.01)
        .map(
          (d) => _MutableDebtState(
            id: d.id,
            name: d.name,
            balance: max(0.0, d.balance),
            annualRate: max(0.0, d.annualRate),
            monthlyPayment: max(0.0, d.monthlyPayment),
          ),
        )
        .toList();
    if (active.isEmpty) {
      return const _PortfolioSimulationResult(
        months: 0,
        totalInterest: 0,
        everPaysOff: true,
      );
    }

    var totalInterest = 0.0;
    final extra = max(0.0, monthlyExtra);
    for (var month = 1; month <= maxSimulationMonths; month++) {
      final startTotal = active.fold<double>(0.0, (s, d) => s + d.balance);
      for (final debt in active) {
        if (debt.balance <= 0.01) continue;
        final interest = debt.balance * debt.annualRate / 12.0;
        totalInterest += interest;
        final owed = debt.balance + interest;
        final pay = min(owed, debt.monthlyPayment);
        debt.balance = max(0.0, owed - pay);
      }
      if (extra > 0) {
        var remainingExtra = extra;
        final priority = active.where((d) => d.balance > 0.01).toList()
          ..sort((a, b) {
            final rateCmp = b.annualRate.compareTo(a.annualRate);
            if (rateCmp != 0) return rateCmp;
            return b.balance.compareTo(a.balance);
          });
        for (final target in priority) {
          if (remainingExtra <= 0.01) break;
          final apply = min(target.balance, remainingExtra);
          target.balance = max(0.0, target.balance - apply);
          remainingExtra -= apply;
        }
      }
      final endTotal = active.fold<double>(0.0, (s, d) => s + d.balance);
      if (endTotal <= 0.01) {
        return _PortfolioSimulationResult(
          months: month,
          totalInterest: totalInterest,
          everPaysOff: true,
        );
      }
      if (endTotal >= startTotal) {
        return _PortfolioSimulationResult(
          months: null,
          totalInterest: totalInterest,
          everPaysOff: false,
        );
      }
    }
    return _PortfolioSimulationResult(
      months: null,
      totalInterest: totalInterest,
      everPaysOff: false,
    );
  }

  /// 高金利優先（アバランチ法）で繰り上げ返済を充当した場合の効果を算出する。
  static MultiDebtSimulationSummary simulateMultiDebtAvalanche({
    required List<MultiDebtInputItem> items,
    required double extraAmount,
    bool isMonthlyRecurring = false,
  }) {
    final normalized = items
        .map(
          (e) => e.copyWith(
            balance: max(0.0, e.balance),
            annualRate: max(0.0, e.annualRate),
            monthlyPayment: max(0.0, e.monthlyPayment),
          ),
        )
        .toList(growable: false);
    final dailyBreakdowns =
        normalized.map(calculateDailyInterest).toList(growable: false);
    final baseline = _simulatePortfolio(normalized);
    final safeExtra = max(0.0, extraAmount);

    final activeSorted = normalized.where((d) => d.balance > 0.01).toList()
      ..sort((a, b) {
        final rateCmp = b.annualRate.compareTo(a.annualRate);
        if (rateCmp != 0) return rateCmp;
        return b.balance.compareTo(a.balance);
      });

    final allocations = <MultiDebtPrepaymentAllocation>[];
    if (!isMonthlyRecurring) {
      var remainingExtra = safeExtra;
      final reducedById = <String, double>{};
      for (final debt in activeSorted) {
        if (remainingExtra <= 0.01) break;
        final apply = min(debt.balance, remainingExtra);
        if (apply <= 0) continue;
        final after = max(0.0, debt.balance - apply);
        reducedById[debt.id] = after;
        allocations.add(
          MultiDebtPrepaymentAllocation(
            debtId: debt.id,
            debtName: debt.name,
            annualRate: debt.annualRate,
            appliedAmount: apply,
            remainingBalanceAfterExtra: after,
          ),
        );
        remainingExtra -= apply;
      }
      final boostedItems = normalized
          .map(
            (e) => reducedById.containsKey(e.id)
                ? e.copyWith(balance: reducedById[e.id])
                : e,
          )
          .toList(growable: false);
      final boosted = _simulatePortfolio(boostedItems);
      return MultiDebtSimulationSummary(
        baselineMonths: baseline.months,
        baselineTotalInterest: baseline.totalInterest,
        baselineEverPaysOff: baseline.everPaysOff,
        boostedMonths: boosted.months,
        boostedTotalInterest: boosted.totalInterest,
        boostedEverPaysOff: boosted.everPaysOff,
        extraPaymentAmount: safeExtra,
        isMonthlyRecurring: false,
        allocations: List<MultiDebtPrepaymentAllocation>.unmodifiable(
          allocations,
        ),
        dailyBreakdowns: dailyBreakdowns,
      );
    }

    if (safeExtra > 0 && activeSorted.isNotEmpty) {
      final firstTarget = activeSorted.first;
      allocations.add(
        MultiDebtPrepaymentAllocation(
          debtId: firstTarget.id,
          debtName: firstTarget.name,
          annualRate: firstTarget.annualRate,
          appliedAmount: safeExtra,
          remainingBalanceAfterExtra: max(0.0, firstTarget.balance - safeExtra),
        ),
      );
    }
    final boosted = _simulatePortfolio(normalized, monthlyExtra: safeExtra);
    return MultiDebtSimulationSummary(
      baselineMonths: baseline.months,
      baselineTotalInterest: baseline.totalInterest,
      baselineEverPaysOff: baseline.everPaysOff,
      boostedMonths: boosted.months,
      boostedTotalInterest: boosted.totalInterest,
      boostedEverPaysOff: boosted.everPaysOff,
      extraPaymentAmount: safeExtra,
      isMonthlyRecurring: true,
      allocations:
          List<MultiDebtPrepaymentAllocation>.unmodifiable(allocations),
      dailyBreakdowns: dailyBreakdowns,
    );
  }

  /// 複数借入をおまとめローン（元利均等返済）へ借り換えた場合の効果を比較試算する (#2750)。
  static DebtConsolidationSimulationResult simulateConsolidation({
    required List<MultiDebtInputItem> items,
    required double consolidatedAnnualRate,
    required int consolidatedTermMonths,
    double? overrideTotalPrincipal,
  }) {
    final normalized = items
        .map(
          (e) => e.copyWith(
            balance: max(0.0, e.balance),
            annualRate: max(0.0, e.annualRate),
            monthlyPayment: max(0.0, e.monthlyPayment),
          ),
        )
        .toList(growable: false);

    final baseline = _simulatePortfolio(normalized);
    final itemBalanceSum = normalized.fold<double>(
      0.0,
      (s, e) => s + e.balance,
    );
    final principal = max(0.0, overrideTotalPrincipal ?? itemBalanceSum);
    final currentMonthlyPaymentTotal = normalized.fold<double>(
      0.0,
      (s, e) => s + e.monthlyPayment,
    );
    final weightedAverageAnnualRate = itemBalanceSum > 0
        ? normalized.fold<double>(
              0.0,
              (s, e) => s + e.balance * e.annualRate,
            ) /
            itemBalanceSum
        : 0.0;

    final term = consolidatedTermMonths.clamp(1, 360);
    final rate = max(0.0, consolidatedAnnualRate);
    final double consolidatedMonthlyPayment;
    final double consolidatedTotalPayment;
    final double consolidatedTotalInterest;

    if (principal <= 0) {
      consolidatedMonthlyPayment = 0;
      consolidatedTotalPayment = 0;
      consolidatedTotalInterest = 0;
    } else if (rate <= 0) {
      consolidatedMonthlyPayment = principal / term;
      consolidatedTotalPayment = principal;
      consolidatedTotalInterest = 0;
    } else {
      final r = rate / 12.0;
      final factor = pow(1 + r, term).toDouble();
      consolidatedMonthlyPayment = principal * r * factor / (factor - 1);
      consolidatedTotalPayment = consolidatedMonthlyPayment * term;
      consolidatedTotalInterest =
          max(0.0, consolidatedTotalPayment - principal);
    }

    return DebtConsolidationSimulationResult(
      totalPrincipal: principal,
      currentMonthlyPaymentTotal: currentMonthlyPaymentTotal,
      currentPayoffMonths: baseline.months,
      currentTotalInterest: baseline.totalInterest,
      currentEverPaysOff: baseline.everPaysOff,
      weightedAverageAnnualRate: weightedAverageAnnualRate,
      consolidatedAnnualRate: rate,
      consolidatedTermMonths: term,
      consolidatedMonthlyPayment: consolidatedMonthlyPayment,
      consolidatedTotalInterest: consolidatedTotalInterest,
      consolidatedTotalPayment: consolidatedTotalPayment,
    );
  }
}
