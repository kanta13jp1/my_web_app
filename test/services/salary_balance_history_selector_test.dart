import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/salary_balance_history_selector.dart';

void main() {
  final cycleStart = DateTime.utc(2026, 6, 1);
  final asOf = DateTime.utc(2026, 6, 20, 12);

  SalaryBalanceHistoryObservation row(
    String name,
    DateTime at,
    double amount,
  ) =>
      SalaryBalanceHistoryObservation(
        accountName: name,
        recordedAt: at,
        amount: amount,
      );

  double? select(
    List<SalaryBalanceHistoryObservation> rows, {
    bool unique = true,
    String? historyOwner = 'owner-a',
    String? currentOwner = 'owner-a',
    int historyGeneration = 1,
    int currentGeneration = 1,
    int historyRevision = 1,
    int currentRevision = 1,
  }) =>
      selectSalaryBalanceHistoryPeak(
        observations: rows,
        accountName: 'bank-a',
        accountNameIsUnique: unique,
        historyOwnerId: historyOwner,
        currentOwnerId: currentOwner,
        historyAuthGeneration: historyGeneration,
        currentAuthGeneration: currentGeneration,
        historyRevision: historyRevision,
        currentHistoryRevision: currentRevision,
        cycleStart: cycleStart,
        asOf: asOf,
      );

  test('retains an earlier same-day peak after spending', () {
    final rows = [
      row('bank-a', DateTime.utc(2026, 6, 20, 9), 201000),
      row('bank-a', DateTime.utc(2026, 6, 20, 11), 1000),
    ];
    expect(select(rows), 201000);
    expect(select([rows.last]), 1000);
  });

  test('retains multiple records at an identical timestamp in either order',
      () {
    final at = DateTime.utc(2026, 6, 20, 9);
    final rows = [row('bank-a', at, 201000), row('bank-a', at, 1000)];
    expect(select(rows), 201000);
    expect(select(rows.reversed.toList()), 201000);
  });

  test('excludes other accounts, other cycles, future time and invalid values',
      () {
    final rows = [
      row('bank-b', DateTime.utc(2026, 6, 20, 9), 999999),
      row('bank-a', DateTime.utc(2026, 5, 31, 23), 999999),
      row('bank-a', DateTime.utc(2026, 6, 20, 13), 999999),
      row('bank-a', DateTime.utc(2026, 6, 20, 10), double.infinity),
      row('bank-a', DateTime.utc(2026, 6, 20, 10), double.nan),
      row('bank-a', cycleStart, 1000),
      row('bank-a', asOf, 2000),
    ];
    expect(select(rows), 2000);
    expect(select(rows.take(5).toList()), isNull);
  });

  test('rejects ambiguous identities, owner changes and stale requests', () {
    final rows = [row('bank-a', DateTime.utc(2026, 6, 20, 9), 201000)];
    expect(select(rows, unique: false), isNull);
    expect(select(rows, historyOwner: null), isNull);
    expect(select(rows, historyOwner: ''), isNull);
    expect(select(rows, currentOwner: 'owner-b'), isNull);
    // A -> B -> A still changes the authentication generation.
    expect(select(rows, currentGeneration: 3), isNull);
    // A successful intervening write or delete invalidates the loaded set.
    expect(select(rows, currentRevision: 2), isNull);
  });

  test('rejects missing, non-finite and overflowed balance changes', () {
    double? difference(double? baseline, double? peak) =>
        salaryHistoryBalanceIncrease(
          previousCycleEndBalance: baseline,
          observedPeak: peak,
        );
    expect(difference(1000, 201000), 200000);
    expect(difference(2000, 1000), -1000);
    expect(difference(null, 201000), isNull);
    expect(difference(1000, null), isNull);
    expect(difference(double.negativeInfinity, 201000), isNull);
    expect(difference(double.infinity, 201000), isNull);
    expect(difference(double.nan, 201000), isNull);
    expect(difference(1000, double.infinity), isNull);
    expect(difference(1000, double.nan), isNull);
    expect(difference(-1e308, 1e308), isNull);
  });
}
