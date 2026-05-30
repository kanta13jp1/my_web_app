import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';
import 'package:my_web_app/services/disposable_balance_service.dart';

class DisposableBalanceAssetLiabilityInputs {
  const DisposableBalanceAssetLiabilityInputs({
    required this.recurringExpenses,
    required this.debts,
  });

  final List<DisposableBalanceRecurringExpense> recurringExpenses;
  final List<DisposableBalanceDebt> debts;
}

class DisposableBalanceAssetLiabilityAdapter {
  const DisposableBalanceAssetLiabilityAdapter();

  DisposableBalanceAssetLiabilityInputs build({
    required AssetLiabilityWorkbook workbook,
    required DateTime cycleStart,
    required DateTime nextPayday,
    DateTime? Function(AssetLiabilityDebtRow row)? lastUpdatedForDebt,
  }) {
    final debtRowsById = <String, AssetLiabilityDebtRow>{
      for (final row in workbook.debtMasterRows) row.id: row,
    };
    final recurringExpenses = <DisposableBalanceRecurringExpense>[];

    for (final row in workbook.cashflowRows) {
      final debtRow = debtRowsById[row.accountId];
      if (!_isFixedCashflowRow(row, debtRow) ||
          !_isWithinCycle(row.paymentDate, cycleStart, nextPayday)) {
        continue;
      }
      recurringExpenses.add(
        DisposableBalanceRecurringExpense(
          name: row.accountName,
          amount: row.paymentAmount,
          dayOfMonth: row.paymentDate.day.clamp(1, 28).toInt(),
          category: _fixedExpenseCategoryFor(debtRow),
        ),
      );
    }

    final debts = <DisposableBalanceDebt>[];
    for (final row in workbook.debtMasterRows) {
      if (!row.isDirectCashflowTarget ||
          row.scheduledPaymentAmount <= 0 ||
          _isFixedDebtRow(row)) {
        continue;
      }
      debts.add(
        DisposableBalanceDebt(
          name: row.name,
          principal: row.balance.abs(),
          monthlyPayment: row.scheduledPaymentAmount,
          interestRate: row.annualRate,
          dayOfMonth: row.paymentDay?.clamp(1, 31).toInt(),
          lastUpdated: lastUpdatedForDebt?.call(row),
        ),
      );
    }
    for (final row in workbook.cashflowRows) {
      if (!_isSupplementalDebtCashflowRow(row, debtRowsById) ||
          !_isWithinCycle(row.paymentDate, cycleStart, nextPayday)) {
        continue;
      }
      debts.add(
        DisposableBalanceDebt(
          name: row.accountName,
          principal: 0,
          monthlyPayment: row.paymentAmount,
          interestRate: 0,
          dayOfMonth: row.paymentDate.day.clamp(1, 31).toInt(),
          lastUpdated: null,
        ),
      );
    }

    return DisposableBalanceAssetLiabilityInputs(
      recurringExpenses: List<DisposableBalanceRecurringExpense>.unmodifiable(
        recurringExpenses,
      ),
      debts: List<DisposableBalanceDebt>.unmodifiable(debts),
    );
  }

  bool _isFixedCashflowRow(
    AssetLiabilityCashflowRow row,
    AssetLiabilityDebtRow? debtRow,
  ) {
    return row.isPayment &&
        row.isDirectCashflowTarget &&
        row.paymentAmount > 0 &&
        debtRow != null &&
        _isFixedDebtRow(debtRow);
  }

  bool _isFixedDebtRow(AssetLiabilityDebtRow row) {
    return row.kind == AssetLiabilityAccountKind.utility ||
        row.id == AssetLiabilityPlanningService.rentAccountId ||
        row.id == AssetLiabilityPlanningService.kddiProviderAccountId;
  }

  bool _isSupplementalDebtCashflowRow(
    AssetLiabilityCashflowRow row,
    Map<String, AssetLiabilityDebtRow> debtRowsById,
  ) {
    return row.isPayment &&
        row.isDirectCashflowTarget &&
        row.paymentAmount > 0 &&
        !debtRowsById.containsKey(row.accountId);
  }

  String _fixedExpenseCategoryFor(AssetLiabilityDebtRow? row) {
    if (row?.id == AssetLiabilityPlanningService.rentAccountId) {
      return 'housing';
    }
    if (row?.kind == AssetLiabilityAccountKind.utility ||
        row?.id == AssetLiabilityPlanningService.kddiProviderAccountId) {
      return 'utility';
    }
    return 'cashflow_fixed';
  }

  bool _isWithinCycle(
    DateTime date,
    DateTime cycleStart,
    DateTime nextPayday,
  ) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final normalizedStart = DateTime(
      cycleStart.year,
      cycleStart.month,
      cycleStart.day,
    );
    final normalizedEnd = DateTime(
      nextPayday.year,
      nextPayday.month,
      nextPayday.day,
    );
    return !normalizedDate.isBefore(normalizedStart) &&
        normalizedDate.isBefore(normalizedEnd);
  }
}
