import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/home_daily_cashflow_summary.dart';

void main() {
  test('empty day has no entries or net amount', () {
    const day = HomeDailyCashflowSummary();
    expect(day.recordCount, 0);
    expect(day.netTotal, 0);
    expect(day.hasCashflow, isFalse);
    expect(day.hasAnyEntry, isFalse);
  });

  test('transfer is an entry outside income and expense', () {
    const day = HomeDailyCashflowSummary(transferTotal: 1000, transferCount: 1);
    expect(day.recordCount, 0);
    expect(day.netTotal, 0);
    expect(day.hasCashflow, isFalse);
    expect(day.hasAnyEntry, isTrue);
  });

  test('mixed day and correction preserve independent totals', () {
    const day = HomeDailyCashflowSummary(
      incomeTotal: 600,
      expenseTotal: 750,
      transferTotal: 1000,
      incomeCount: 2,
      expenseCount: 3,
      transferCount: 1,
    );
    expect(day.recordCount, 5);
    expect(day.netTotal, -150);
    expect(day.hasCashflow, isTrue);
    final corrected = day.copyWith(expenseTotal: 500, expenseCount: 2);
    expect(corrected.recordCount, 4);
    expect(corrected.netTotal, 100);
    expect(corrected.incomeTotal, 600);
    expect(corrected.transferTotal, 1000);
    expect(corrected.transferCount, 1);
    expect(day.expenseTotal, 750);
    expect(day.expenseCount, 3);
  });
}
