import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_persistence.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_liability_monthly_state_store.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const config = AssetLiabilityRevolvingCreditConfig(
    monthlyAmount: 10000,
    creditLimit: 500000,
  );
  const service = AssetLiabilityPlanningService();
  AssetLiabilityDebtRow row({
    Map<String, double> amounts = const {},
    Map<String, double> days = const {},
    Set<String> confirmed = const {},
  }) =>
      service
          .buildWorkbook(
            latestSnapshot: {'じぶん銀行': 81234, 'auPayカード': -537541},
            baseDate: DateTime(2026, 10, 11),
            monthlyPaymentOverrides: amounts,
            confirmedPaymentDays: days,
            billingConfirmedAccountIds: confirmed,
            revolvingConfigs: {'aupay_card': config},
          )
          .debtMasterRows
          .firstWhere((r) => r.id == 'aupay_card');

  test('confirmed current bill overrides revolving amount and day, unpaid', () {
    final bill = row(
      amounts: {'aupay_card': 77541},
      days: {'aupay_card': 13},
      confirmed: {'aupay_card'},
    );
    expect(bill.scheduledPaymentAmount, 77541);
    expect(bill.paymentDay, 13);
    expect(bill.paid, isFalse);
    expect(bill.actualPaymentAmount, isNull);
    expect(bill.revolvingBilling!.billedAmount, 77541);
    expect(bill.revolvingBilling!.monthlyAmount, 10000);
    expect(bill.revolvingBilling!.newUsageAmount, 0);
    expect(config.monthlyAmount, 10000);
    expect(config.creditLimit, 500000);
  });

  test('unconfirmed carried amount does not override permanent revolving plan',
      () {
    final next = row(amounts: {'aupay_card': 77541});
    expect(next.scheduledPaymentAmount, 10000);
    expect(next.paymentDay, 25);
    final invalid = row(days: {'aupay_card': 32});
    expect(invalid.paymentDay, 25);
  });

  test(
      'current day survives local and remote reload, never copies to next month',
      () async {
    SharedPreferences.setMockInitialValues({});
    const state = AssetLiabilityMonthlyState(
      paymentOverrides: {'aupay_card': 77541},
      confirmedPaymentDays: {'aupay_card': 13},
      billingConfirmedAccountIds: {'aupay_card'},
    );
    const store = AssetLiabilityMonthlyStateStore();
    await store.saveMonth(month: DateTime(2026, 9), state: state);
    final loaded = await store.loadMonth(DateTime(2026, 9));
    expect(loaded.confirmedPaymentDays, state.confirmedPaymentDays);
    final payload = AssetLiabilityMonthlyStatePayload.fromState(
      monthKey: '2026-09',
      state: loaded,
    ).toSupabaseJson(userId: 'test');
    final remote =
        AssetLiabilityMonthlyStatePayload.fromSupabaseJson(payload).toState();
    expect(remote.confirmedPaymentDays, state.confirmedPaymentDays);
    expect(remote.paidAccountNames, isEmpty);
    final next = AssetLiabilityMonthlyStateStore.copyPreviousMonthState(
      previousState: remote,
      targetMonth: DateTime(2026, 10),
    );
    expect(next.confirmedPaymentDays, isEmpty);
    expect(next.billingConfirmedAccountIds, isEmpty);
    expect(
      (await store.loadMonth(DateTime(2026, 10))).confirmedPaymentDays,
      isEmpty,
    );
  });
}
