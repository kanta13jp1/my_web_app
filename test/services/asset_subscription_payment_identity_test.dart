import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';
import 'package:my_web_app/services/asset_payment_calendar_service.dart';

AssetPaymentCalendarMonth contractCalendar({
  required double invoice,
  Map<String, String> links = const {'legacy-a': 'cost-a'},
  String legacyId = 'legacy-a',
  String legacyName = 'Synthetic contract',
  String? billingAccountId = 'card-a',
}) {
  return AssetPaymentCalendarService.buildRange(
    start: DateTime(2026, 10),
    endExclusive: DateTime(2026, 11),
    asOf: DateTime(2026, 10, 15),
    flows: const [],
    startingCashBalance: 100,
    subscriptionFixedCostIds: links,
    debts: [
      AssetCalendarDebtInput(
        id: 'fixed-a',
        recurringFixedCostId: 'cost-a',
        name: 'Synthetic contract',
        balance: -invoice,
        scheduledPaymentAmount: invoice,
        paymentDay: 20,
        isFixedCost: true,
        isDirectCashflowTarget: false,
        includedInBillingAccount: true,
        paymentMethod: AssetLiabilityPaymentMethod.includedInCard,
        billingAccountId: billingAccountId,
      ),
      AssetCalendarDebtInput(
        id: 'card-a',
        name: 'Synthetic card',
        balance: -invoice,
        scheduledPaymentAmount: invoice,
        paymentDay: 27,
      ),
    ],
    subscriptions: [
      {
        'id': legacyId,
        'service_name': legacyName,
        'price': 1000,
        'due_date': '2026-10-20',
      },
    ],
  );
}

void main() {
  for (final kind in [
    AssetLiabilityAccountKind.creditCard,
    AssetLiabilityAccountKind.deposit,
    null
  ]) {
    test('direct payment routing evidence for $kind', () {
      final debt = AssetCalendarDebtInput(
        name: 'Synthetic routed payment',
        balance: -500,
        paymentDay: 20,
        scheduledPaymentAmount: 500,
        paymentMethod: AssetLiabilityPaymentMethod.direct,
        paymentSourceAccountKind: kind,
      );
      final result = AssetPaymentCalendarService.buildRange(
        start: DateTime(2026, 10),
        endExclusive: DateTime(2026, 11),
        asOf: DateTime(2026, 10, 15),
        flows: const [],
        startingCashBalance: 100,
        debts: [debt],
        subscriptions: const [],
      );
      final event = result.dayFor(DateTime(2026, 10, 20))!.events.single;
      expect(
        event.paymentMethodUnverified,
        kind == AssetLiabilityAccountKind.creditCard,
      );
      expect(result.scheduledOutflowTotal, 500);
      if (kind == AssetLiabilityAccountKind.creditCard) {
        expect(event.label, contains('支払方式とカード原資が不一致'));
      }
    });
  }

  for (final invoice in [500.0, 0.0]) {
    test('explicit contract identity survives override invoice $invoice', () {
      final result = contractCalendar(invoice: invoice);
      expect(result.dayFor(DateTime(2026, 10, 20))!.scheduledOutflow, 0);
      expect(result.scheduledOutflowTotal, invoice);
      final usage = result.dayFor(DateTime(2026, 10, 20))!.events.single;
      expect(usage.affectsCashProjection, isFalse);
      expect(usage.paymentMethodUnverified, isFalse);
    });
  }

  test('same-name same-price different contract remains unverified', () {
    final result = contractCalendar(invoice: 1000, legacyId: 'legacy-b');
    final usage = result.dayFor(DateTime(2026, 10, 20))!.events.single;
    expect(usage.paymentMethodUnverified, isTrue);
    expect(usage.label, contains('支払方法未照合'));
    expect(result.scheduledOutflowTotal, 2000);
  });

  test('names are irrelevant when explicit contract identity is known', () {
    final result =
        contractCalendar(invoice: 500, legacyName: 'Another spelling');
    expect(result.scheduledOutflowTotal, 500);
  });

  test('unknown payment method is never promoted to confirmed card', () {
    final noLinks = contractCalendar(invoice: 1000, links: const {});
    final noBilling = contractCalendar(invoice: 1000, billingAccountId: null);
    for (final result in [noLinks, noBilling]) {
      expect(
        result
            .dayFor(DateTime(2026, 10, 20))!
            .events
            .single
            .paymentMethodUnverified,
        isTrue,
      );
    }
  });

  test('ambiguous canonical identity is not resolved by name or price', () {
    const row = AssetCalendarDebtInput(
      id: 'first',
      recurringFixedCostId: 'cost-a',
      name: 'Synthetic contract',
      balance: -1000,
      paymentDay: 20,
    );
    expect(
      AssetPaymentCalendarService.resolvedSubscriptionDebt(
        const {'id': 'legacy-a'},
        const [row, row],
        subscriptionFixedCostIds: const {'legacy-a': 'cost-a'},
      ),
      isNull,
    );
  });

  test('injected recurring identity reaches pure calendar DTO', () {
    final workbook = const AssetLiabilityPlanningService().buildWorkbook(
      latestSnapshot: const {'Synthetic bank': 5000, 'SyntheticCard': -1000},
      baseDate: DateTime(2026, 10, 15),
      includeDefaultFixedPayments: false,
      cardBillingAccountIds: const {
        'Synthetic unique fixed cost': 'custom_syntheticcard',
      },
      recurringFixedCosts: const [
        AssetRecurringFixedCost(
          id: 'cost-a',
          name: 'Synthetic unique fixed cost',
          amount: 1000,
          paymentDay: 20,
        ),
      ],
    );
    final row = workbook.debtMasterRows.singleWhere(
      (row) => row.name == 'Synthetic unique fixed cost',
    );
    expect(row.recurringFixedCostId, 'cost-a');
    expect(
      AssetCalendarDebtInput.fromDebtRow(row).recurringFixedCostId,
      'cost-a',
    );
    final dto = AssetCalendarDebtInput.fromDebtRow(row);
    expect(dto.paymentMethod, AssetLiabilityPaymentMethod.includedInCard);
    expect(dto.billingAccountId, 'custom_syntheticcard');
  });
}
