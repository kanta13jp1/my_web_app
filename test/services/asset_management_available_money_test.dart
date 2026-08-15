import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_management_available_money.dart';

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
}) {
  return AssetLiabilityCashflowRow(
    eventType: AssetLiabilityCashflowEventType.payment,
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
    includedInBillingAccount: false,
    paymentAmount: amount,
    paymentAmountEstimated: false,
    paid: paid,
    received: false,
    overdue: false,
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
        _payment(id: 'c', date: DateTime(2026, 6, 27), amount: 40000),
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
