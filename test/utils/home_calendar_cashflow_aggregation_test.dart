import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:my_web_app/models/home_daily_cashflow_summary.dart';
import 'package:my_web_app/utils/home_calendar_cashflow_aggregation.dart';

int _amount(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

Map<String, HomeDailyCashflowSummary> _aggregate(dynamic rows) {
  return aggregateHomeCalendarCashflow(
    rows,
    dateKeyFor: DateFormat('yyyy-MM-dd').format,
    amountFor: _amount,
  );
}

Map<String, dynamic> _row(String type, dynamic amount, DateTime date) => {
      'action_type': type,
      'amount': amount,
      'occurred_at': date.toIso8601String(),
    };

void main() {
  test('non-list and malformed rows are ignored', () {
    for (final input in [
      null,
      1,
      'invalid',
      <String, dynamic>{},
      [null, 1, {'occurred_at': 'invalid'}],
    ]) {
      expect(_aggregate(input), isEmpty);
    }
  });

  test('local day merges UTC and local timestamps', () {
    final date = DateTime(2026, 1, 2, 0, 30);
    final days = _aggregate([
      _row('conquer', 100, date),
      _row('conquer', '50', date.toUtc()),
      _row('expense', 25.9, date),
      _row('transfer', 500, date),
      _row('expense', '-5', DateTime(2026, 1, 3)),
    ]);
    expect(days.keys, ['2026-01-02', '2026-01-03']);
    final day = days['2026-01-02']!;
    expect(day.incomeTotal, 150);
    expect(day.incomeCount, 2);
    expect(day.expenseTotal, 25);
    expect(day.expenseCount, 1);
    expect(day.transferTotal, 500);
    expect(day.transferCount, 1);
    expect(day.recordCount, 3);
    expect(day.netTotal, 125);
    expect(days['2026-01-03']!.netTotal, 5);
  });

  test('unknown actions retain empty day and input order', () {
    final days = _aggregate([
      _row('unknown', 100, DateTime(2026, 1, 2)),
      _row('expense', 'invalid', DateTime(2026, 1, 1)),
    ]);
    expect(days.keys, ['2026-01-02', '2026-01-01']);
    expect(days['2026-01-02']!.hasAnyEntry, isFalse);
    expect(days['2026-01-01']!.expenseTotal, 0);
    expect(days['2026-01-01']!.expenseCount, 1);
  });

  test('conversion failure propagates to existing loader catch', () {
    expect(
      () => aggregateHomeCalendarCashflow(
        [_row('expense', 1, DateTime(2026, 1, 2))],
        dateKeyFor: DateFormat('yyyy-MM-dd').format,
        amountFor: (_) => throw StateError('conversion failed'),
      ),
      throwsStateError,
    );
  });
}
