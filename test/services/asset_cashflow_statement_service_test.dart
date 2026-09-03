import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_cashflow_statement_service.dart';

AssetLiabilityMonthlySnapshot _snapshot(
  String monthKey, {
  double? income,
  double expense = 0,
  double netWorth = 0,
}) {
  return AssetLiabilityMonthlySnapshot(
    monthKey: monthKey,
    savedAt: DateTime(2026, 1, 1),
    positiveAssetTotal: 0,
    liabilityTotal: 0,
    netWorth: netWorth,
    cashLikeTotal: 0,
    monthlyScheduledPaymentTotal: 0,
    monthlyPaidPaymentTotal: expense,
    monthlyUnpaidPaymentTotal: 0,
    overduePaymentCount: 0,
    monthlyReceivedIncomeTotal: income,
  );
}

void main() {
  const service = AssetCashflowStatementService();

  group('AssetCashflowStatementService.build', () {
    test('empty snapshots produce no data', () {
      final statement = service.build(
        snapshots: const <AssetLiabilityMonthlySnapshot>[],
        asOf: DateTime(2026, 7, 15),
      );
      expect(statement.hasData, isFalse);
      expect(statement.currentMonth, isNull);
      expect(statement.yearToDateCashflow, 0);
    });

    test('current month cashflow = income - expense', () {
      final statement = service.build(
        snapshots: [
          _snapshot('2026-07', income: 400000, expense: 250000),
        ],
        asOf: DateTime(2026, 7, 15),
      );
      expect(statement.hasCurrentMonthCashflow, isTrue);
      expect(statement.currentMonthCashflow, 150000);
      expect(statement.currentMonth!.isSurplus, isTrue);
    });

    test('current month snapshot overrides same-month history (fresher)', () {
      final statement = service.build(
        snapshots: [
          _snapshot('2026-07', income: 100000, expense: 100000),
        ],
        currentMonthSnapshot:
            _snapshot('2026-07', income: 400000, expense: 250000),
        asOf: DateTime(2026, 7, 15),
      );
      expect(statement.currentMonthCashflow, 150000);
    });

    test('year-to-date accumulates only same-year tracked months', () {
      final statement = service.build(
        snapshots: [
          // 前年は除外される。
          _snapshot('2025-12', income: 999999, expense: 0),
          _snapshot('2026-01', income: 300000, expense: 200000), // +100k
          _snapshot('2026-02', income: 300000, expense: 350000), // -50k
          _snapshot('2026-07', income: 400000, expense: 250000), // +150k
        ],
        asOf: DateTime(2026, 7, 15),
      );
      expect(statement.yearToDateCashflow, 200000);
      expect(statement.yearToDateTrackedMonths, 3);
      expect(statement.yearToDateUntrackedMonths, 0);
    });

    test('untracked income month is excluded from YTD, not treated as 0', () {
      final statement = service.build(
        snapshots: [
          _snapshot('2026-01', income: null, expense: 200000), // 除外
          _snapshot('2026-02', income: 300000, expense: 100000), // +200k
        ],
        asOf: DateTime(2026, 2, 15),
      );
      // 未追跡月を 0 円収入とみなすと -200k が混ざり +0 になるが、除外するので +200k。
      expect(statement.yearToDateCashflow, 200000);
      expect(statement.yearToDateTrackedMonths, 1);
      expect(statement.yearToDateUntrackedMonths, 1);
      expect(statement.hasUntrackedYearToDateMonths, isTrue);
    });

    test('untracked income exposes net worth delta as display-only estimate', () {
      final statement = service.build(
        snapshots: [
          _snapshot('2026-05', netWorth: -1000),
          _snapshot('2026-06', netWorth: -1200),
          _snapshot(
            '2026-07',
            income: 500,
            expense: 300,
            netWorth: -1100,
          ),
        ],
        asOf: DateTime(2026, 7, 15),
      );

      final may = statement.months[0];
      final june = statement.months[1];
      final july = statement.months[2];

      expect(may.displayCashflow, isNull);
      expect(may.usesNetWorthEstimate, isFalse);
      expect(june.cashflow, isNull);
      expect(june.estimatedCashflowFromNetWorth, -200);
      expect(june.displayCashflow, -200);
      expect(june.usesNetWorthEstimate, isTrue);
      expect(july.cashflow, 200);
      expect(july.estimatedCashflowFromNetWorth, isNull);
      expect(july.displayCashflow, 200);
      expect(july.usesNetWorthEstimate, isFalse);

      // 推定値は実績の年初来累積・黒字/赤字件数へ混ぜない。
      expect(statement.yearToDateCashflow, 200);
      expect(statement.yearToDateTrackedMonths, 1);
      expect(statement.yearToDateUntrackedMonths, 2);
      expect(statement.surplusMonthCount, 1);
      expect(statement.deficitMonthCount, 0);
    });

    test('surplus/deficit counts over trailing 12 months, tracked only', () {
      final statement = service.build(
        snapshots: [
          _snapshot('2026-01', income: 300000, expense: 100000), // 黒字
          _snapshot('2026-02', income: 100000, expense: 300000), // 赤字
          _snapshot('2026-03', income: null, expense: 300000), // 未追跡→除外
          _snapshot(
            '2026-04',
            income: 200000,
            expense: 200000,
          ), // 黒字(0はsurplus)
        ],
        asOf: DateTime(2026, 4, 15),
      );
      expect(statement.surplusMonthCount, 2);
      expect(statement.deficitMonthCount, 1);
      expect(statement.trackedMonthCount, 3);
      expect(statement.windowMonths, 12);
    });

    test('months older than trailing window are excluded from counts', () {
      final statement = service.build(
        snapshots: [
          _snapshot('2025-06', income: 100000, expense: 300000), // 13か月前→除外
          _snapshot('2025-08', income: 300000, expense: 100000), // 窓内
          _snapshot('2026-07', income: 300000, expense: 100000), // 当月
        ],
        asOf: DateTime(2026, 7, 15),
      );
      // 窓は 2025-08..2026-07。2025-06 は除外。
      expect(statement.surplusMonthCount, 2);
      expect(statement.deficitMonthCount, 0);
    });

    test('future months are excluded from YTD (safety)', () {
      final statement = service.build(
        snapshots: [
          _snapshot('2026-01', income: 300000, expense: 100000), // +200k
          _snapshot('2026-12', income: 999999, expense: 0), // 未来→除外
        ],
        asOf: DateTime(2026, 7, 15),
      );
      expect(statement.yearToDateCashflow, 200000);
      expect(statement.yearToDateTrackedMonths, 1);
    });

    test('months are sorted ascending by monthKey', () {
      final statement = service.build(
        snapshots: [
          _snapshot('2026-03', income: 0, expense: 0),
          _snapshot('2026-01', income: 0, expense: 0),
          _snapshot('2026-02', income: 0, expense: 0),
        ],
        asOf: DateTime(2026, 3, 15),
      );
      expect(
        statement.months.map((m) => m.monthKey).toList(),
        ['2026-01', '2026-02', '2026-03'],
      );
    });

    test('current month with untracked income cannot compute cashflow', () {
      final statement = service.build(
        snapshots: [
          _snapshot('2026-07', income: null, expense: 250000),
        ],
        asOf: DateTime(2026, 7, 15),
      );
      expect(statement.currentMonth, isNotNull);
      expect(statement.hasCurrentMonthCashflow, isFalse);
      expect(statement.currentMonthCashflow, isNull);
    });
  });
}
