import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_future_card_bill.dart';
import 'package:my_web_app/services/asset_liability_monthly_state_store.dart';

void main() {
  final editedAt = DateTime(2026, 10, 12);
  AssetLiabilityMonthlyState apply(
    AssetLiabilityMonthlyState state, {
    double amount = 3041,
  }) =>
      AssetFutureCardBill.apply(
        state: state,
        accountId: 'cloud',
        accountName: 'Google Cloud',
        cardId: 'paypay',
        amount: amount,
        note: '10/1利用、11月以降・11/27以降',
        editedAt: editedAt,
      );
  test(
    'same month and account updates once; other payments and card total stay unchanged',
    () {
      const original = AssetLiabilityMonthlyState(
        paymentOverrides: {'aupay': 77541, 'cloud': 59, 'paypay': 13074},
        paidAccountNames: {'other'},
        confirmedPaymentDays: {'aupay': 13},
        billingConfirmedAccountIds: {'other'},
        paymentSourceAccountIds: {'paypay': 'bank'},
      );
      final once = apply(original);
      final twice = apply(once);
      expect(twice.paymentOverrides, {
        'aupay': 77541.0,
        'cloud': 3041.0,
        'paypay': 13074.0,
      });
      expect(twice.cardBillingAccountIds['cloud'], 'paypay');
      expect(twice.paidAccountNames, {'other'});
      expect(twice.confirmedPaymentDays, {'aupay': 13.0});
      expect(twice.billingConfirmedAccountIds, {'other'});
      expect(twice.paymentSourceAccountIds, original.paymentSourceAccountIds);
      expect(twice.actualPaymentAmounts, isEmpty);
      expect(twice.cardStatementLines, isEmpty);
      expect(original.paymentOverrides['cloud'], 59);
    },
  );
  test('existing paid history cannot be silently changed to unpaid', () {
    expect(
      () => apply(
        const AssetLiabilityMonthlyState(
          billingConfirmedAccountIds: {'cloud'},
        ),
      ),
      throwsStateError,
    );
    expect(
      () => apply(
        const AssetLiabilityMonthlyState(paidAccountNames: {'Google Cloud'}),
      ),
      throwsStateError,
    );
    expect(
      () => apply(
        const AssetLiabilityMonthlyState(actualPaymentAmounts: {'cloud': 3041}),
      ),
      throwsStateError,
    );
  });
  test(
    'amount rejects malformed values; accepts full-width and grouped integers',
    () {
      expect(AssetFutureCardBill.parseAmount('３，０４１'), 3041);
      expect(AssetFutureCardBill.parseAmount('3041'), 3041);
      expect(AssetFutureCardBill.parseAmount('30,41'), isNull);
      expect(AssetFutureCardBill.parseAmount('-3041'), isNull);
      expect(
        () => apply(const AssetLiabilityMonthlyState(), amount: double.nan),
        throwsArgumentError,
      );
    },
  );
}
