import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:my_web_app/utils/home_cashflow_bundle_loader.dart';

int _amount(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

String _dateKey(DateTime date) =>
    DateFormat('yyyy-MM-dd').format(DateTime(date.year, date.month, date.day));

Map<String, dynamic> _row(String type, Object? amount, DateTime date) => {
      'action_type': type,
      'amount': amount,
      'occurred_at': date.toIso8601String(),
    };

void main() {
  test('null userId performs zero requests and returns empty bundle', () async {
    var requestCount = 0;
    final bundle = await loadHomeCashflowBundle(
      userId: null,
      monthStart: DateTime(2026, 11, 1),
      nextMonth: DateTime(2026, 12, 1),
      calendarStart: DateTime(2026, 11, 1),
      calendarEnd: DateTime(2026, 12, 5),
      fetchRows: (_) async {
        requestCount += 1;
        return const <Object?>[];
      },
      dateKeyFor: _dateKey,
      amountFor: _amount,
    );

    expect(requestCount, 0);
    expect(bundle.monthlyTotals.incomeTotal, 0);
    expect(bundle.monthlyTotals.expenseTotal, 0);
    expect(bundle.monthlyTotals.incomeCount, 0);
    expect(bundle.monthlyTotals.expenseCount, 0);
    expect(bundle.monthlyTotals.lastRecordedAt, isNull);
    expect(bundle.dailyByDate, isEmpty);
  });

  test('signed-in user queries month and calendar bounds once', () async {
    final queries = <HomeCashflowBundleQuery>[];
    final monthStart = DateTime(2026, 11, 1);
    final nextMonth = DateTime(2026, 12, 1);
    final calendarStart = DateTime(2026, 10, 25, 18, 30);
    final calendarEnd = DateTime(2026, 12, 5, 23, 59);

    await loadHomeCashflowBundle(
      userId: 'user-scope-1',
      monthStart: monthStart,
      nextMonth: nextMonth,
      calendarStart: calendarStart,
      calendarEnd: calendarEnd,
      fetchRows: (query) async {
        queries.add(query);
        return const <Object?>[];
      },
      dateKeyFor: _dateKey,
      amountFor: _amount,
    );

    expect(queries, hasLength(1));
    expect(queries.single.userId, 'user-scope-1');
    expect(
      queries.single.startUtcIso,
      DateTime(2026, 10, 25).toUtc().toIso8601String(),
    );
    expect(
      queries.single.endExclusiveUtcIso,
      DateTime(2026, 12, 6).toUtc().toIso8601String(),
    );
  });

  test('composes monthly totals and calendar summaries accurately', () async {
    final bundle = await loadHomeCashflowBundle(
      userId: 'user-scope-2',
      monthStart: DateTime(2026, 11, 1),
      nextMonth: DateTime(2026, 12, 1),
      calendarStart: DateTime(2026, 10, 25),
      calendarEnd: DateTime(2026, 11, 20),
      fetchRows: (_) async => [
        null,
        'malformed',
        {'occurred_at': 'invalid'},
        _row('conquer', 1000, DateTime(2026, 10, 31, 23, 59)),
        _row('conquer', 500, DateTime(2026, 11, 1, 0, 0)),
        _row('expense', '200', DateTime(2026, 11, 1, 9, 0).toUtc()),
        _row('transfer', 300, DateTime(2026, 11, 2, 10, 0)),
        _row('borrowing', 400, DateTime(2026, 11, 2, 11, 0)),
        _row('unknown', 999, DateTime(2026, 11, 2, 12, 0)),
        _row('expense', 150, DateTime(2026, 11, 25, 14, 0)),
      ],
      dateKeyFor: _dateKey,
      amountFor: _amount,
    );

    expect(bundle.monthlyTotals.incomeTotal, 500);
    expect(bundle.monthlyTotals.incomeCount, 1);
    expect(bundle.monthlyTotals.expenseTotal, 350);
    expect(bundle.monthlyTotals.expenseCount, 2);
    expect(bundle.monthlyTotals.lastRecordedAt, DateTime(2026, 11, 25, 14, 0));

    expect(
      bundle.dailyByDate.keys.toList(),
      ['2026-10-31', '2026-11-01', '2026-11-02'],
    );
    expect(bundle.dailyByDate['2026-10-31']!.incomeTotal, 1000);
    expect(bundle.dailyByDate['2026-11-01']!.incomeTotal, 500);
    expect(bundle.dailyByDate['2026-11-01']!.expenseTotal, 200);
    expect(bundle.dailyByDate['2026-11-02']!.transferTotal, 300);
    expect(bundle.dailyByDate['2026-11-02']!.borrowingTotal, 400);
  });

  test('fetch failure calls onError once and returns empty bundle', () async {
    var requestCount = 0;
    Object? capturedError;
    final bundle = await loadHomeCashflowBundle(
      userId: 'user-scope-3',
      monthStart: DateTime(2026, 11, 1),
      nextMonth: DateTime(2026, 12, 1),
      calendarStart: DateTime(2026, 11, 1),
      calendarEnd: DateTime(2026, 11, 30),
      fetchRows: (_) async {
        requestCount += 1;
        throw StateError('network failed');
      },
      dateKeyFor: _dateKey,
      amountFor: _amount,
      onError: (error, _) {
        capturedError = error;
      },
    );

    expect(requestCount, 1);
    expect(capturedError, isA<StateError>());
    expect(bundle.monthlyTotals.incomeTotal, 0);
    expect(bundle.monthlyTotals.expenseTotal, 0);
    expect(bundle.dailyByDate, isEmpty);
  });
}
