import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_cashflow_forecast_inputs.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';
import 'package:my_web_app/services/asset_payment_calendar_service.dart';

AssetPaymentCalendarMonth calendar({
  required List<AssetCalendarDebtInput> debts,
  List<Map<String, dynamic>> subscriptions = const [],
  List<AssetCalendarInflowInput> inflows = const [],
  double balance = 5000,
}) {
  return AssetPaymentCalendarService.buildRange(
    start: DateTime(2026, 10),
    endExclusive: DateTime(2026, 11),
    asOf: DateTime(2026, 10, 15),
    flows: const [],
    subscriptions: subscriptions,
    debts: debts,
    startingCashBalance: balance,
    expectedInflows: inflows,
  );
}

void main() {
  test('paid current-day rows do not subtract from observed cash again', () {
    final result = calendar(
      debts: const [
        AssetCalendarDebtInput(
          id: 'paid_today',
          name: 'Synthetic settled payment',
          balance: -20000,
          paymentDay: 15,
          scheduledPaymentAmount: 10000,
          paid: true,
        ),
      ],
    );
    expect(result.scheduledOutflowTotal, 0);
    expect(result.firstShortfallDate, isNull);
  });

  test('same-cycle early-settled payment is not subtracted again', () {
    final result = calendar(
      debts: [
        AssetCalendarDebtInput(
          id: 'paid_in_advance',
          paidPeriodStart: DateTime(2026, 10),
          paidPeriodEndExclusive: DateTime(2026, 11),
          name: 'Synthetic early settlement',
          balance: -20000,
          paymentDay: 20,
          scheduledPaymentAmount: 10000,
          paid: true,
        ),
      ],
    );
    expect(result.scheduledOutflowTotal, 0);
    expect(result.firstShortfallDate, isNull);
  });

  test('settled fixed cost is not reintroduced by raw subscription data', () {
    final result = calendar(
      debts: const [
        AssetCalendarDebtInput(
          id: 'paid_fixed_cost',
          name: 'Synthetic paid fixed cost',
          balance: -1000,
          paymentDay: 15,
          scheduledPaymentAmount: 1000,
          paid: true,
          isFixedCost: true,
        ),
      ],
      subscriptions: const [
        {
          'service_name': 'Synthetic paid fixed cost',
          'due_date': '2026-10-15',
          'price': 1000,
        },
      ],
    );
    expect(result.scheduledOutflowTotal, 0);
  });

  test('current paid period does not erase the next cycle payment', () {
    final result = AssetPaymentCalendarService.buildRange(
      start: DateTime(2026, 10),
      endExclusive: DateTime(2026, 12),
      asOf: DateTime(2026, 10, 15),
      startingCashBalance: 5000,
      flows: const [],
      subscriptions: const [],
      debts: [
        AssetCalendarDebtInput(
          id: 'period_paid',
          name: 'Synthetic recurring payment',
          balance: -20000,
          paymentDay: 20,
          scheduledPaymentAmount: 10000,
          paid: true,
          paidPeriodStart: DateTime(2026, 10),
          paidPeriodEndExclusive: DateTime(2026, 11),
        ),
      ],
    );
    expect(result.dayFor(DateTime(2026, 10, 20))!.scheduledOutflow, 0);
    expect(result.dayFor(DateTime(2026, 11, 20))!.scheduledOutflow, 10000);
    expect(result.firstShortfallDate, DateTime(2026, 11, 20));
  });

  test('card-included subscription is not also a direct cash payment', () {
    final result = calendar(
      balance: 10000,
      debts: const [
        AssetCalendarDebtInput(
          id: 'synthetic_card',
          name: 'Synthetic card invoice',
          balance: -10000,
          paymentDay: 20,
          scheduledPaymentAmount: 10000,
        ),
        AssetCalendarDebtInput(
          id: 'included_subscription',
          name: 'Synthetic included subscription',
          balance: -1000,
          paymentDay: 17,
          scheduledPaymentAmount: 1000,
          isFixedCost: true,
          isDirectCashflowTarget: false,
        ),
      ],
      subscriptions: const [
        {
          'service_name': 'Synthetic included subscription',
          'due_date': '2026-10-17',
          'price': 1000,
        },
      ],
    );
    expect(result.scheduledOutflowTotal, 10000);
    expect(result.firstShortfallDate, isNull);
    expect(result.dayFor(DateTime(2026, 10, 17))!.scheduledOutflow, 0);
    expect(
      result.dayFor(DateTime(2026, 10, 17))!.events.single.label,
      contains('カード利用'),
    );
    expect(result.dayFor(DateTime(2026, 10, 20))!.scheduledOutflow, 10000);
  });

  test('long-term forecast also excludes card-included raw renewal', () {
    final workbook = const AssetLiabilityPlanningService().buildWorkbook(
      latestSnapshot: const {'SyntheticCard': -10000, '現金': 10000},
      baseDate: DateTime(2026, 10, 15),
      includeDefaultFixedPayments: false,
      paymentDayOverrides: const {'custom_syntheticcard': 20},
      monthlyPaymentOverrides: const {'custom_syntheticcard': 10000},
      billingConfirmedAccountIds: const {'custom_syntheticcard'},
      recurringFixedCosts: const [
        AssetRecurringFixedCost(
          id: 'synthetic_service',
          name: 'SyntheticService',
          amount: 1000,
          paymentDay: 17,
          category: AssetRecurringFixedCostCategory.subscription,
        ),
      ],
      cardBillingAccountIds: const {
        'SyntheticService': 'custom_syntheticcard',
      },
    );
    final source = workbook.debtMasterRows.singleWhere(
      (row) => row.name == 'SyntheticService',
    );
    expect(source.isDirectCashflowTarget, isFalse);
    final inputs = AssetCashflowForecastInputs.fromAssetData(
      accounts: workbook.accounts,
      debtRows: workbook.debtMasterRows,
      recurringIncomeTemplates: const [],
      inflowRules: const [],
      oneTimeInflows: const [],
      subscriptions: const [
        {
          'service_name': 'SyntheticService',
          'due_date': '2026-10-17',
          'price': 1000,
        },
      ],
    );
    expect(
      inputs.recurringOutflow.any((e) => e.label == 'SyntheticService'),
      isFalse,
    );
    expect(
      inputs.recurringOutflow.any((e) => e.label == 'SyntheticCard'),
      isTrue,
    );
    final cardPayment = inputs.recurringOutflow.singleWhere(
      (entry) => entry.label == 'SyntheticCard',
    );
    expect(cardPayment.dayOfMonth, 20);
    expect(cardPayment.amount, 10000);
  });

  test('future expected income is a forecast input, not observed balance', () {
    const debt = AssetCalendarDebtInput(
      id: 'synthetic_future_payment',
      name: 'Synthetic future payment',
      balance: -20000,
      paymentDay: 20,
      scheduledPaymentAmount: 10000,
    );
    final withoutPlan = calendar(debts: [debt]);
    final withPlan = calendar(
      debts: [debt],
      inflows: [
        AssetCalendarInflowInput(
          date: DateTime(2026, 10, 19),
          amount: 10000,
          label: 'Synthetic unconfirmed future income',
        ),
      ],
    );
    expect(withoutPlan.firstShortfallDate, DateTime(2026, 10, 20));
    expect(withPlan.firstShortfallDate, isNull);
    expect(withPlan.dayFor(DateTime(2026, 10, 15))!.projectedBalance, 5000);
  });

  test('first shortfall and maximum recovery are different dated quantities',
      () {
    final result = calendar(
      debts: const [
        AssetCalendarDebtInput(
          id: 'first_deficit',
          name: 'Synthetic first payment',
          balance: -20000,
          paymentDay: 20,
          scheduledPaymentAmount: 6000,
        ),
        AssetCalendarDebtInput(
          id: 'later_deficit',
          name: 'Synthetic later payment',
          balance: -20000,
          paymentDay: 22,
          scheduledPaymentAmount: 10000,
        ),
      ],
    );
    expect(result.firstShortfallDate, DateTime(2026, 10, 20));
    expect(result.dayFor(DateTime(2026, 10, 20))!.projectedBalance, -1000);
    expect(result.dayFor(DateTime(2026, 10, 22))!.projectedBalance, -11000);
    expect(result.shortfallRecoveryAmount, 11000);
  });
}
