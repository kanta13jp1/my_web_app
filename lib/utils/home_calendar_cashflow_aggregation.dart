import '../models/home_daily_cashflow_summary.dart';

/// Aggregates supplied rows without I/O using Home's existing conversions.
Map<String, HomeDailyCashflowSummary> aggregateHomeCalendarCashflow(
  dynamic rowsRaw, {
  required String Function(DateTime) dateKeyFor,
  required int Function(dynamic) amountFor,
}) {
  final rows = rowsRaw is List ? rowsRaw : const <dynamic>[];
  final result = <String, HomeDailyCashflowSummary>{};

  for (final row in rows.whereType<Map<String, dynamic>>()) {
    final occurredAt = DateTime.tryParse(
      row['occurred_at']?.toString() ?? '',
    )?.toLocal();
    if (occurredAt == null) continue;

    final dateKey = dateKeyFor(occurredAt);
    final current = result[dateKey] ?? const HomeDailyCashflowSummary();
    final actionType = row['action_type']?.toString() ?? '';
    final amount = amountFor(row['amount']);

    result[dateKey] = switch (actionType) {
      'conquer' => current.copyWith(
          incomeTotal: current.incomeTotal + amount,
          incomeCount: current.incomeCount + 1,
        ),
      'expense' => current.copyWith(
          expenseTotal: current.expenseTotal + amount,
          expenseCount: current.expenseCount + 1,
        ),
      'transfer' => current.copyWith(
          transferTotal: current.transferTotal + amount,
          transferCount: current.transferCount + 1,
        ),
      _ => current,
    };
  }

  return result;
}
