import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_principal_interest_breakdown_service.dart';

void main() {
  AssetLiabilityDebtRow buildRow({
    required String id,
    required double scheduledPaymentAmount,
    required double monthlyInterestEstimate,
    required double principalPaymentEstimate,
    bool includedInBillingAccount = false,
    AssetLiabilityPaymentMethod paymentMethod =
        AssetLiabilityPaymentMethod.direct,
  }) {
    return AssetLiabilityDebtRow(
      id: id,
      name: 'テスト負債',
      kind: AssetLiabilityAccountKind.cardLoan,
      balance: -300000,
      paymentDay: 15,
      paymentSourceAccountId: 'wallet_cash',
      paymentSourceAccountName: '財布(現金)',
      paymentMethod: paymentMethod,
      paymentMethodLabel: includedInBillingAccount ? 'カード合算' : '直接支払い',
      paymentMethodSettingSource:
          AssetLiabilityPaymentMethodSettingSource.builtInDefault,
      billingAccountId: includedInBillingAccount ? 'parent_card' : null,
      billingAccountName: includedInBillingAccount ? '親カード' : null,
      includedInBillingAccount: includedInBillingAccount,
      annualRate: 0.18,
      minimumPaymentEstimate: scheduledPaymentAmount,
      manualPaymentAmount: scheduledPaymentAmount,
      scheduledPaymentAmount: scheduledPaymentAmount,
      monthlyInterestEstimate: monthlyInterestEstimate,
      principalPaymentEstimate: principalPaymentEstimate,
      balanceAfterPaymentEstimate: -300000 + principalPaymentEstimate,
      liabilityShare: 0.3,
      priorityLabel: '高',
      paymentAmountEstimated: false,
      billingConfirmed: true,
      paid: false,
      requiresAction: true,
    );
  }

  group('AssetPrincipalInterestBreakdownService', () {
    test('flags low principal efficiency (<50%) and keeps healthy rows normal',
        () {
      final lowEfficiency = buildRow(
        id: 'mobit',
        scheduledPaymentAmount: 10000,
        monthlyInterestEstimate: 7000,
        principalPaymentEstimate: 3000,
      );
      final healthy = buildRow(
        id: 'jibun',
        scheduledPaymentAmount: 15000,
        monthlyInterestEstimate: 3000,
        principalPaymentEstimate: 12000,
      );

      final lowBreakdown =
          AssetPrincipalInterestBreakdownService.build(lowEfficiency);
      expect(lowBreakdown, isNotNull);
      expect(lowBreakdown!.principalRatio, closeTo(0.3, 0.001));
      expect(lowBreakdown.interestRatio, closeTo(0.7, 0.001));
      expect(lowBreakdown.isLowPrincipalEfficiency, isTrue);
      expect(
        AssetPrincipalInterestBreakdownService.summaryLabel(
          lowBreakdown,
          (v) => '¥${v.round()}',
        ),
        '元金 ¥3000 (30%) / 利息 ¥7000 (70%)',
      );
      expect(
        AssetPrincipalInterestBreakdownService.lowEfficiencyWarningLabel(
          lowBreakdown,
        ),
        '元金充当率低 (30%)',
      );

      final healthyBreakdown =
          AssetPrincipalInterestBreakdownService.build(healthy);
      expect(healthyBreakdown, isNotNull);
      expect(healthyBreakdown!.principalRatio, closeTo(0.8, 0.001));
      expect(healthyBreakdown.isLowPrincipalEfficiency, isFalse);
    });

    test('excludes zero-interest/principal and non-direct rows', () {
      final zeroBoth = buildRow(
        id: 'zero_both',
        scheduledPaymentAmount: 10000,
        monthlyInterestEstimate: 0,
        principalPaymentEstimate: 0,
      );
      final zeroPayment = buildRow(
        id: 'zero_pay',
        scheduledPaymentAmount: 0,
        monthlyInterestEstimate: 3000,
        principalPaymentEstimate: 0,
      );
      final includedCard = buildRow(
        id: 'card_sub',
        scheduledPaymentAmount: 10000,
        monthlyInterestEstimate: 2000,
        principalPaymentEstimate: 8000,
        includedInBillingAccount: true,
        paymentMethod: AssetLiabilityPaymentMethod.includedInCard,
      );

      expect(AssetPrincipalInterestBreakdownService.build(zeroBoth), isNull);
      expect(AssetPrincipalInterestBreakdownService.build(zeroPayment), isNull);
      expect(
        AssetPrincipalInterestBreakdownService.build(includedCard),
        isNull,
      );
    });
  });
}
