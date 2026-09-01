import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';

void main() {
  group('detectDuplicateDebts', () {
    test('Issue #5189: detects duplicate debt between じぶんローン and じぶん銀行カードローン', () {
      final rowA = AssetLiabilityDebtRow(
        id: 'jibun_loan',
        name: 'じぶんローン',
        balance: 1000000,
        annualRate: 15.0,
        monthlyPayment: 20000,
        accountKind: AssetLiabilityAccountKind.cardLoan,
        isDirectCashflowTarget: true,
        paymentAmountEstimated: false,
        billingConfirmed: true,
        scheduledPaymentAmount: 20000,
        actualPaymentAmount: 0,
        paid: false,
        annualRateRisk: null,
      );

      final rowB = AssetLiabilityDebtRow(
        id: 'jibun_bank_card_loan',
        name: 'じぶん銀行カードローン',
        balance: 1000000,
        annualRate: 15.0,
        monthlyPayment: 20000,
        accountKind: AssetLiabilityAccountKind.cardLoan,
        isDirectCashflowTarget: true,
        paymentAmountEstimated: false,
        billingConfirmed: true,
        scheduledPaymentAmount: 20000,
        actualPaymentAmount: 0,
        paid: false,
        annualRateRisk: null,
      );

      final otherRow = AssetLiabilityDebtRow(
        id: 'rakuten_card',
        name: '楽天カード',
        balance: 50000,
        annualRate: 15.0,
        monthlyPayment: 10000,
        accountKind: AssetLiabilityAccountKind.creditCard,
        isDirectCashflowTarget: true,
        paymentAmountEstimated: false,
        billingConfirmed: true,
        scheduledPaymentAmount: 10000,
        actualPaymentAmount: 0,
        paid: false,
        annualRateRisk: null,
      );

      final warnings = detectDuplicateDebts([rowA, rowB, otherRow]);
      expect(warnings, isNotEmpty);
      expect(warnings.length, equals(1));
      expect(warnings.first.rowA.id, equals('jibun_loan'));
      expect(warnings.first.rowB.id, equals('jibun_bank_card_loan'));
      expect(warnings.first.similarity, greaterThanOrEqualTo(0.75));
      expect(warnings.first.message, contains('じぶんローン'));
      expect(warnings.first.message, contains('じぶん銀行カードローン'));
    });

    test('distinct debts produce no false positive duplicate warnings', () {
      final rowA = AssetLiabilityDebtRow(
        id: 'mizuho_loan',
        name: 'みずほ銀行カードローン',
        balance: 500000,
        annualRate: 14.0,
        monthlyPayment: 15000,
        accountKind: AssetLiabilityAccountKind.cardLoan,
        isDirectCashflowTarget: true,
        paymentAmountEstimated: false,
        billingConfirmed: true,
        scheduledPaymentAmount: 15000,
        actualPaymentAmount: 0,
        paid: false,
        annualRateRisk: null,
      );

      final rowB = AssetLiabilityDebtRow(
        id: 'smbc_loan',
        name: '三井住友銀行カードローン',
        balance: 300000,
        annualRate: 14.5,
        monthlyPayment: 10000,
        accountKind: AssetLiabilityAccountKind.cardLoan,
        isDirectCashflowTarget: true,
        paymentAmountEstimated: false,
        billingConfirmed: true,
        scheduledPaymentAmount: 10000,
        actualPaymentAmount: 0,
        paid: false,
        annualRateRisk: null,
      );

      final warnings = detectDuplicateDebts([rowA, rowB]);
      expect(warnings, isEmpty);
    });
  });
}
