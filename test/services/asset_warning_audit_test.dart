import 'package:flutter_test/flutter_test.dart';
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
      debts: const [
        AssetCalendarDebtInput(
          id: 'paid_in_advance',
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

  test('first shortfall and maximum recovery are different dated quantities', () {
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
