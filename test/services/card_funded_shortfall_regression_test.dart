import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_payment_calendar_service.dart';

void main() {
  test('card funded fixed costs do not create cash shortfall on usage date',
      () {
    final calendar = AssetPaymentCalendarService.buildRange(
      start: DateTime(2026, 9, 25),
      endExclusive: DateTime(2026, 10, 25),
      asOf: DateTime(2026, 10, 17),
      flows: const <Map<String, dynamic>>[],
      subscriptions: const <Map<String, dynamic>>[],
      startingCashBalance: 13071,
      debts: const <AssetCalendarDebtInput>[
        AssetCalendarDebtInput(
          name: 'card subscription',
          balance: -30000,
          paymentDay: 20,
          scheduledPaymentAmount: 30000,
          isFixedCost: true,
          paymentMethod: AssetLiabilityPaymentMethod.direct,
          paymentSourceAccountKind: AssetLiabilityAccountKind.creditCard,
        ),
        AssetCalendarDebtInput(
          name: 'shopping card subscription',
          balance: -4981,
          paymentDay: 22,
          scheduledPaymentAmount: 4981,
          isFixedCost: true,
          paymentMethod: AssetLiabilityPaymentMethod.direct,
          paymentSourceAccountKind: AssetLiabilityAccountKind.shoppingDebt,
        ),
        AssetCalendarDebtInput(
          name: 'water',
          balance: -2400,
          paymentDay: 22,
          scheduledPaymentAmount: 2400,
          isFixedCost: true,
          paymentMethod: AssetLiabilityPaymentMethod.direct,
          paymentSourceAccountKind: AssetLiabilityAccountKind.deposit,
        ),
      ],
    );
    expect(calendar.scheduledOutflowTotal, 2400);
    expect(calendar.firstShortfallDate, isNull);
  });
}
