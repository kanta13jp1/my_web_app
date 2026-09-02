import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_duplicate_debt_service.dart';

AssetLiabilityDebtRow _createTestDebtRow({
  required String id,
  required String name,
  double balance = 1000000,
  double annualRate = 15.0,
}) {
  return AssetLiabilityDebtRow(
    id: id,
    name: name,
    kind: AssetLiabilityAccountKind.cardLoan,
    balance: balance,
    paymentDay: 10,
    paymentSourceAccountId: null,
    paymentSourceAccountName: null,
    paymentMethod: AssetLiabilityPaymentMethod.direct,
    paymentMethodLabel: '直接',
    paymentMethodSettingSource:
        AssetLiabilityPaymentMethodSettingSource.builtInDefault,
    billingAccountId: null,
    billingAccountName: null,
    includedInBillingAccount: false,
    annualRate: annualRate,
    minimumPaymentEstimate: 20000,
    manualPaymentAmount: null,
    scheduledPaymentAmount: 20000,
    monthlyInterestEstimate: 12500,
    principalPaymentEstimate: 7500,
    balanceAfterPaymentEstimate: 992500,
    liabilityShare: 0.5,
    priorityLabel: '中',
    paymentAmountEstimated: false,
    billingConfirmed: true,
    paid: false,
    fullPaymentEstimate: false,
    revolvingBilling: null,
    requiresAction: false,
  );
}

void main() {
  group('AssetDuplicateDebtService', () {
    test(
      'Issue #5189: detects duplicate debt between じぶんローン and じぶん銀行カードローン',
      () {
        final rowA = _createTestDebtRow(id: 'jibun_loan', name: 'じぶんローン');

        final rowB = _createTestDebtRow(
          id: 'jibun_bank_card_loan',
          name: 'じぶん銀行カードローン',
        );

        final otherRow = _createTestDebtRow(
          id: 'rakuten_card',
          name: '楽天カード',
          balance: 50000,
        );

        final warnings = AssetDuplicateDebtService.detectDuplicates([
          rowA,
          rowB,
          otherRow,
        ]);
        expect(warnings, isNotEmpty);
        expect(warnings.length, equals(1));
        expect(warnings.first.rowA.id, equals('jibun_loan'));
        expect(warnings.first.rowB.id, equals('jibun_bank_card_loan'));
        expect(warnings.first.similarity, greaterThanOrEqualTo(0.75));
        expect(warnings.first.message, contains('じぶんローン'));
        expect(warnings.first.message, contains('じぶん銀行カードローン'));
      },
    );

    test('distinct debts produce no false positive duplicate warnings', () {
      final rowA = _createTestDebtRow(
        id: 'mizuho_loan',
        name: 'みずほ銀行カードローン',
        balance: 500000,
      );

      final rowB = _createTestDebtRow(
        id: 'smbc_loan',
        name: '三井住友銀行カードローン',
        balance: 300000,
      );

      final warnings = AssetDuplicateDebtService.detectDuplicates([rowA, rowB]);
      expect(warnings, isEmpty);
    });
  });
}
