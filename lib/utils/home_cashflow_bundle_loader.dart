import '../models/home_daily_cashflow_summary.dart';
import 'home_calendar_cashflow_aggregation.dart';

/// Query bounds sent to fetch the Home cashflow bundle.
class HomeCashflowBundleQuery {
  final String userId;
  final String startUtcIso;
  final String endExclusiveUtcIso;

  const HomeCashflowBundleQuery({
    required this.userId,
    required this.startUtcIso,
    required this.endExclusiveUtcIso,
  });
}

/// Pure monthly cashflow totals before presentation formatting.
class HomeMonthlyCashflowTotals {
  final int incomeTotal;
  final int expenseTotal;
  final int incomeCount;
  final int expenseCount;
  final DateTime? lastRecordedAt;

  const HomeMonthlyCashflowTotals({
    this.incomeTotal = 0,
    this.expenseTotal = 0,
    this.incomeCount = 0,
    this.expenseCount = 0,
    this.lastRecordedAt,
  });
}

/// Composed monthly and calendar cashflow bundle without UI state.
class HomeCashflowBundleData {
  final HomeMonthlyCashflowTotals monthlyTotals;
  final Map<String, HomeDailyCashflowSummary> dailyByDate;

  const HomeCashflowBundleData({
    this.monthlyTotals = const HomeMonthlyCashflowTotals(),
    this.dailyByDate = const <String, HomeDailyCashflowSummary>{},
  });
}

DateTime _startOfLocalDay(DateTime date) =>
    DateTime(date.year, date.month, date.day);

DateTime _minLocalDate(DateTime a, DateTime b) => a.isBefore(b) ? a : b;

DateTime _maxLocalDate(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

/// Builds the single UTC half-open query covering both month and calendar.
HomeCashflowBundleQuery buildHomeCashflowBundleQuery({
  required String userId,
  required DateTime monthStart,
  required DateTime nextMonth,
  required DateTime calendarStart,
  required DateTime calendarEnd,
}) {
  final normalizedCalStart = _startOfLocalDay(calendarStart);
  final normalizedCalEndExclusive =
      _startOfLocalDay(calendarEnd).add(const Duration(days: 1));
  final queryStart = _minLocalDate(monthStart, normalizedCalStart);
  final queryEndExclusive = _maxLocalDate(nextMonth, normalizedCalEndExclusive);
  return HomeCashflowBundleQuery(
    userId: userId,
    startUtcIso: queryStart.toUtc().toIso8601String(),
    endExclusiveUtcIso: queryEndExclusive.toUtc().toIso8601String(),
  );
}

/// Composes monthly totals and calendar daily summaries from raw rows.
HomeCashflowBundleData composeHomeCashflowBundle(
  Object? rowsRaw, {
  required DateTime monthStart,
  required DateTime nextMonth,
  required DateTime calendarStart,
  required DateTime calendarEndExclusive,
  required String Function(DateTime) dateKeyFor,
  required int Function(dynamic) amountFor,
}) {
  final rows = rowsRaw is List ? rowsRaw : const <Object?>[];

  var incomeTotal = 0;
  var expenseTotal = 0;
  var incomeCount = 0;
  var expenseCount = 0;
  DateTime? lastRecordedAt;
  final calendarRows = <Object?>[];

  for (final row in rows.whereType<Map<String, dynamic>>()) {
    final occurredAt = DateTime.tryParse(
      row['occurred_at']?.toString() ?? '',
    )?.toLocal();
    if (occurredAt == null) continue;

    if (!occurredAt.isBefore(monthStart) && occurredAt.isBefore(nextMonth)) {
      if (lastRecordedAt == null || occurredAt.isAfter(lastRecordedAt)) {
        lastRecordedAt = occurredAt;
      }
      final actionType = row['action_type']?.toString() ?? '';
      final amount = amountFor(row['amount']);
      if (actionType == 'conquer') {
        incomeTotal += amount;
        incomeCount += 1;
      } else if (actionType == 'expense') {
        expenseTotal += amount;
        expenseCount += 1;
      }
    }

    if (!occurredAt.isBefore(calendarStart) &&
        occurredAt.isBefore(calendarEndExclusive)) {
      calendarRows.add(row);
    }
  }

  return HomeCashflowBundleData(
    monthlyTotals: HomeMonthlyCashflowTotals(
      incomeTotal: incomeTotal,
      expenseTotal: expenseTotal,
      incomeCount: incomeCount,
      expenseCount: expenseCount,
      lastRecordedAt: lastRecordedAt,
    ),
    dailyByDate: aggregateHomeCalendarCashflow(
      calendarRows,
      dateKeyFor: dateKeyFor,
      amountFor: amountFor,
    ),
  );
}

/// Loads the cashflow bundle in at most one request under user scoping.
Future<HomeCashflowBundleData> loadHomeCashflowBundle({
  required String? userId,
  required DateTime monthStart,
  required DateTime nextMonth,
  required DateTime calendarStart,
  required DateTime calendarEnd,
  required Future<Object?> Function(HomeCashflowBundleQuery query) fetchRows,
  required String Function(DateTime) dateKeyFor,
  required int Function(dynamic) amountFor,
  void Function(Object error, StackTrace stackTrace)? onError,
}) async {
  if (userId == null) {
    return const HomeCashflowBundleData();
  }

  final normalizedCalStart = _startOfLocalDay(calendarStart);
  final normalizedCalEndExclusive =
      _startOfLocalDay(calendarEnd).add(const Duration(days: 1));
  final query = buildHomeCashflowBundleQuery(
    userId: userId,
    monthStart: monthStart,
    nextMonth: nextMonth,
    calendarStart: calendarStart,
    calendarEnd: calendarEnd,
  );

  try {
    final rowsRaw = await fetchRows(query);
    return composeHomeCashflowBundle(
      rowsRaw,
      monthStart: monthStart,
      nextMonth: nextMonth,
      calendarStart: normalizedCalStart,
      calendarEndExclusive: normalizedCalEndExclusive,
      dateKeyFor: dateKeyFor,
      amountFor: amountFor,
    );
  } catch (error, stackTrace) {
    onError?.call(error, stackTrace);
    return const HomeCashflowBundleData();
  }
}
