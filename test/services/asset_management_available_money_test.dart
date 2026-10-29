import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';
import 'package:my_web_app/services/asset_management_available_money.dart';
import 'package:my_web_app/services/asset_management_insight_service.dart';

AssetLiabilityAccount _account({
  required String id,
  required AssetLiabilityAccountKind kind,
  required double balance,
}) {
  return AssetLiabilityAccount(
    id: id,
    name: id,
    kind: kind,
    balance: balance,
  );
}

AssetLiabilityCashflowRow _payment({
  required String id,
  required DateTime date,
  required double amount,
  bool paid = false,
  bool overdue = false,
  bool includedInBillingAccount = false,
  AssetLiabilityCashflowEventType eventType =
      AssetLiabilityCashflowEventType.payment,
}) {
  return AssetLiabilityCashflowRow(
    eventType: eventType,
    accountId: id,
    accountName: id,
    paymentDay: date.day,
    paymentDate: date,
    paymentSourceAccountId: null,
    paymentSourceAccountName: null,
    destinationAccountId: null,
    destinationAccountName: null,
    paymentMethod: AssetLiabilityPaymentMethod.direct,
    paymentMethodLabel: null,
    paymentMethodSettingSource:
        AssetLiabilityPaymentMethodSettingSource.builtInDefault,
    billingAccountId: null,
    billingAccountName: null,
    includedInBillingAccount: includedInBillingAccount,
    paymentAmount: amount,
    paymentAmountEstimated: false,
    paid: paid,
    received: false,
    overdue: overdue,
    cashBeforePayment: 0,
    cashAfterPayment: 0,
    riskLevel: AssetLiabilityCashRiskLevel.normal,
  );
}

void main() {
  group('AssetManagementAvailableMoney', () {
    test('nextPayday returns this month before salary day', () {
      expect(
        AssetManagementAvailableMoney.nextPayday(DateTime(2026, 6, 13)),
        DateTime(2026, 6, 25),
      );
    });

    test('nextPayday rolls to next month on or after salary day', () {
      expect(
        AssetManagementAvailableMoney.nextPayday(DateTime(2026, 6, 25)),
        DateTime(2026, 7, 25),
      );
    });

    test('remainingDaysToPayday counts days to payday (min 1)', () {
      expect(
        AssetManagementAvailableMoney.remainingDaysToPayday(
          DateTime(2026, 6, 13),
          DateTime(2026, 6, 25),
        ),
        12,
      );
    });

    test('daysUntilWeekEnd counts today..Sunday capped to remaining', () {
      // 2026-06-13 は土曜 → 今週末(日)まで 2 日。
      expect(
        AssetManagementAvailableMoney.daysUntilWeekEnd(
          DateTime(2026, 6, 13),
          remainingDays: 12,
        ),
        2,
      );
      // 残日数が短ければそれを上限にする。
      expect(
        AssetManagementAvailableMoney.daysUntilWeekEnd(
          DateTime(2026, 6, 13),
          remainingDays: 1,
        ),
        1,
      );
    });

    test('availableAssets = selected main bank + cash wallet', () {
      final accounts = <AssetLiabilityAccount>[
        _account(
          id: 'smbc',
          kind: AssetLiabilityAccountKind.deposit,
          balance: 63539,
        ),
        _account(
          id: 'jibun',
          kind: AssetLiabilityAccountKind.deposit,
          balance: 47435,
        ),
        _account(
          id: 'wallet',
          kind: AssetLiabilityAccountKind.cash,
          balance: 9297,
        ),
      ];
      expect(
        AssetManagementAvailableMoney.availableAssets(
          accounts: accounts,
          mainAccountId: 'smbc',
        ),
        63539 + 9297,
      );
    });

    test('availableAssets falls back to largest deposit when unset', () {
      final accounts = <AssetLiabilityAccount>[
        _account(
          id: 'smbc',
          kind: AssetLiabilityAccountKind.deposit,
          balance: 63539,
        ),
        _account(
          id: 'jibun',
          kind: AssetLiabilityAccountKind.deposit,
          balance: 47435,
        ),
        _account(
          id: 'wallet',
          kind: AssetLiabilityAccountKind.cash,
          balance: 9297,
        ),
      ];
      expect(
        AssetManagementAvailableMoney.availableAssets(
          accounts: accounts,
          mainAccountId: null,
        ),
        63539 + 9297,
      );
    });

    test('unpaidUntilPayday sums unpaid direct payments due by payday', () {
      final payday = DateTime(2026, 6, 25);
      final rows = <AssetLiabilityCashflowRow>[
        _payment(id: 'a', date: DateTime(2026, 6, 8), amount: 22000),
        _payment(id: 'b', date: DateTime(2026, 6, 15), amount: 32000),
        // 給料日より後 → 除外。
        _payment(
          id: 'c',
          date: DateTime(2026, 6, 27),
          amount: 40000,
        ),
        // 支払済み → 除外。
        _payment(
          id: 'd',
          date: DateTime(2026, 6, 10),
          amount: 15000,
          paid: true,
        ),
      ];
      expect(
        AssetManagementAvailableMoney.unpaidUntilPayday(
          cashflowRows: rows,
          payday: payday,
        ),
        22000 + 32000,
      );
    });

    test('24th, 25th and 26th use next 25th for report amounts', () {
      // Synthetic, unchanged snapshot across dates isolates the cutoff. This
      // does not model a salary deposit or claim a user's actual balance.
      const planner = AssetLiabilityPlanningService();
      const insights = AssetManagementInsightService();
      final accounts = <AssetLiabilityAccount>[
        _account(
          id: 'main',
          kind: AssetLiabilityAccountKind.deposit,
          balance: 100000,
        ),
        _account(
          id: 'wallet',
          kind: AssetLiabilityAccountKind.cash,
          balance: 1000,
        ),
      ];
      List<AssetLiabilityCashflowRow> rowsFor(DateTime base) => [
            _payment(
              id: 'overdue',
              date: DateTime(2026, 6, 20),
              amount: 1000,
              overdue: true,
            ),
            _payment(
              id: 'cutoff-day',
              date: DateTime(2026, 6, 25),
              amount: 20000,
              overdue: DateTime(2026, 6, 25).isBefore(base),
            ),
            _payment(
              id: 'after-cutoff',
              date: DateTime(2026, 6, 26),
              amount: 40000,
            ),
            _payment(
              id: 'next-cutoff',
              date: DateTime(2026, 7, 25),
              amount: 3000,
            ),
            _payment(
              id: 'after-next-cutoff',
              date: DateTime(2026, 7, 26),
              amount: 5000,
            ),
            _payment(
              id: 'already-paid',
              date: DateTime(2026, 6, 25),
              amount: 7000,
              paid: true,
            ),
            _payment(
              id: 'included-in-bill',
              date: DateTime(2026, 6, 25),
              amount: 9000,
              includedInBillingAccount: true,
              overdue: DateTime(2026, 6, 25).isBefore(base),
            ),
            _payment(
              id: 'future-income',
              date: DateTime(2026, 6, 25),
              amount: 50000,
              eventType: AssetLiabilityCashflowEventType.income,
            ),
          ];

      final cases = <({
        DateTime base,
        DateTime cutoff,
        DateTime weekEnd,
        int remainingDays,
        int weekDays,
        double unpaid,
        double monthly,
        double daily,
        double weekly,
      })>[
        (
          base: DateTime(2026, 6, 24),
          cutoff: DateTime(2026, 6, 25),
          weekEnd: DateTime(2026, 6, 24),
          remainingDays: 1,
          weekDays: 1,
          unpaid: 21000,
          monthly: 70000,
          daily: 70000,
          weekly: 70000,
        ),
        (
          base: DateTime(2026, 6, 25),
          cutoff: DateTime(2026, 7, 25),
          weekEnd: DateTime(2026, 6, 28),
          remainingDays: 30,
          weekDays: 4,
          unpaid: 64000,
          monthly: 27000,
          daily: 900,
          weekly: 3600,
        ),
        (
          base: DateTime(2026, 6, 26),
          cutoff: DateTime(2026, 7, 25),
          weekEnd: DateTime(2026, 6, 28),
          remainingDays: 29,
          weekDays: 3,
          unpaid: 64000,
          monthly: 27000,
          daily: 27000 / 29,
          weekly: 81000 / 29,
        ),
      ];

      for (final scenario in cases) {
        final cutoff = AssetManagementAvailableMoney.nextPayday(scenario.base);
        expect(cutoff, scenario.cutoff);
        final remaining = AssetManagementAvailableMoney.remainingDaysToPayday(
          scenario.base,
          cutoff,
        );
        expect(remaining, scenario.remainingDays);
        expect(
          AssetManagementAvailableMoney.daysUntilWeekEnd(
            scenario.base,
            remainingDays: remaining,
          ),
          scenario.weekDays,
        );
        final workbook = planner.buildWorkbook(
          latestSnapshot: const <String, double>{},
          baseDate: scenario.base,
        ).copyWith(accounts: accounts, cashflowRows: rowsFor(scenario.base));
        final report = insights.buildReport(
          workbook: workbook,
          mainAccountId: 'main',
          minimumSafetyBalance: 10000,
        );
        expect(report.monthAvailable.cashLikeTotal, 101000);
        expect(report.monthAvailable.unpaidPaymentTotal, scenario.unpaid);
        expect(report.monthAvailable.endDate, scenario.cutoff);
        expect(report.weekAvailable.endDate, scenario.weekEnd);
        expect(report.monthAvailable.availableAmount, scenario.monthly);
        expect(
          report.todayAvailable.availableAmount,
          closeTo(scenario.daily, 0.001),
        );
        expect(
          report.weekAvailable.availableAmount,
          closeTo(scenario.weekly, 0.001),
        );
      }
    });

    test('breakdown derives today/week/month from disposable', () {
      final breakdown = AssetManagementAvailableMoneyBreakdown(
        availableAssets: 72836,
        unpaidUntilPayday: 0,
        minimumSafetyBalance: 10000,
        remainingDaysToPayday: 12,
        daysThisWeek: 2,
        payday: DateTime(2026, 6, 25),
      );
      expect(breakdown.disposableUntilPayday, 62836);
      expect(breakdown.monthAvailable, 62836);
      expect(breakdown.dailyAvailable, closeTo(62836 / 12, 0.001));
      expect(breakdown.todayAvailable, closeTo(62836 / 12, 0.001));
      expect(breakdown.weekAvailable, closeTo(62836 / 12 * 2, 0.001));
    });
  });
}
