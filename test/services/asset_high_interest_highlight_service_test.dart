import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_high_interest_highlight_service.dart';

void main() {
  AssetLiabilityDebtRow buildRow({
    required String id,
    required String name,
    required double annualRate,
    required double monthlyInterestEstimate,
    required double liabilityShare,
    double balance = -100000,
    int? paymentDay = 15,
  }) {
    return AssetLiabilityDebtRow(
      id: id,
      name: name,
      kind: AssetLiabilityAccountKind.cardLoan,
      balance: balance,
      paymentDay: paymentDay,
      paymentSourceAccountId: 'wallet_cash',
      paymentSourceAccountName: '財布(現金)',
      paymentMethod: AssetLiabilityPaymentMethod.direct,
      paymentMethodLabel: '直接支払い',
      paymentMethodSettingSource:
          AssetLiabilityPaymentMethodSettingSource.builtInDefault,
      billingAccountId: null,
      billingAccountName: null,
      includedInBillingAccount: false,
      annualRate: annualRate,
      minimumPaymentEstimate: 10000,
      manualPaymentAmount: 10000,
      scheduledPaymentAmount: 10000,
      monthlyInterestEstimate: monthlyInterestEstimate,
      principalPaymentEstimate: 8000,
      balanceAfterPaymentEstimate: balance + 8000,
      liabilityShare: liabilityShare,
      priorityLabel: '高',
      paymentAmountEstimated: false,
      billingConfirmed: true,
      paid: false,
      requiresAction: true,
    );
  }

  group('AssetHighInterestHighlightService', () {
    test('classifies critical (>=17.5%), high (>=14%), and normal rates', () {
      expect(
        AssetHighInterestHighlightService.classifyRateTier(0.18),
        AssetDebtRateTier.critical,
      );
      expect(
        AssetHighInterestHighlightService.classifyRateTier(0.175),
        AssetDebtRateTier.critical,
      );
      expect(
        AssetHighInterestHighlightService.classifyRateTier(0.145),
        AssetDebtRateTier.high,
      );
      expect(
        AssetHighInterestHighlightService.classifyRateTier(0.14),
        AssetDebtRateTier.high,
      );
      expect(
        AssetHighInterestHighlightService.classifyRateTier(0.05),
        AssetDebtRateTier.normal,
      );

      expect(
        AssetHighInterestHighlightService.rateBadgeLabel(0.18),
        '高金利 18.0%',
      );
      expect(
        AssetHighInterestHighlightService.rateBadgeLabel(0.145),
        '要注意 14.5%',
      );
      expect(
        AssetHighInterestHighlightService.rateBadgeLabel(0.05),
        isNull,
      );
    });

    test(
      'sorts by annualRate desc, monthlyInterestEstimate desc, liabilityShare desc, abs(balance) desc',
      () {
        final rows = <AssetLiabilityDebtRow>[
          buildRow(
            id: 'low_rate',
            name: '低金利ローン',
            annualRate: 0.05,
            monthlyInterestEstimate: 2000,
            liabilityShare: 0.1,
          ),
          buildRow(
            id: 'yokohama_small',
            name: '横浜A',
            annualRate: 0.145,
            monthlyInterestEstimate: 5000,
            liabilityShare: 0.2,
          ),
          buildRow(
            id: 'yokohama_big',
            name: '横浜B',
            annualRate: 0.145,
            monthlyInterestEstimate: 5000,
            liabilityShare: 0.35,
          ),
          buildRow(
            id: 'acom_cl',
            name: 'アコムCL',
            annualRate: 0.18,
            monthlyInterestEstimate: 10447,
            liabilityShare: 0.15,
          ),
          buildRow(
            id: 'mobit',
            name: 'モビット',
            annualRate: 0.18,
            monthlyInterestEstimate: 22884,
            liabilityShare: 0.20,
          ),
        ];

        rows.sort(
          AssetHighInterestHighlightService.compareByHighInterestPriority,
        );
        expect(
          rows.map((r) => r.id).toList(),
          <String>[
            'mobit',
            'acom_cl',
            'yokohama_big',
            'yokohama_small',
            'low_rate',
          ],
        );
      },
    );

    test('builds monthly interest tooltip and resolves highest risk rate row',
        () {
      final mobit = buildRow(
        id: 'mobit',
        name: 'モビット',
        annualRate: 0.18,
        monthlyInterestEstimate: 22884,
        liabilityShare: 0.25,
      );
      final yokohama = buildRow(
        id: 'yokohama',
        name: '横浜銀行',
        annualRate: 0.145,
        monthlyInterestEstimate: 5146,
        liabilityShare: 0.08,
      );
      final normal = buildRow(
        id: 'normal',
        name: '無利息',
        annualRate: 0.0,
        monthlyInterestEstimate: 0,
        liabilityShare: 0.02,
      );

      final tooltip =
          AssetHighInterestHighlightService.monthlyInterestTooltip(mobit);
      expect(tooltip, contains('年利 18.0%'));
      expect(tooltip, contains('22,884円'));
      expect(tooltip, contains('負債割合 25.0%'));

      final highRisk = AssetLiabilityPaymentDayRisk(
        paymentDay: 5,
        paymentDate: DateTime(2026, 9, 5),
        accountNames: const <String>['横浜銀行', 'モビット'],
        balanceTotal: -500000,
        scheduledPaymentTotal: 40000,
        minimumPaymentEstimateTotal: 40000,
        manualPaymentTotal: 0,
        interestEstimateTotal: 28030,
        manualPaymentCount: 0,
        estimatedPaymentCount: 2,
        isPast: true,
        isToday: false,
        requiresAction: true,
      );
      final matched =
          AssetHighInterestHighlightService.highestRateRowForPaymentRisk(
        highRisk,
        <AssetLiabilityDebtRow>[yokohama, mobit, normal],
      );
      expect(matched?.id, 'mobit');

      final normalRisk = AssetLiabilityPaymentDayRisk(
        paymentDay: 10,
        paymentDate: DateTime(2026, 9, 10),
        accountNames: const <String>['無利息'],
        balanceTotal: -10000,
        scheduledPaymentTotal: 10000,
        minimumPaymentEstimateTotal: 10000,
        manualPaymentTotal: 0,
        interestEstimateTotal: 0,
        manualPaymentCount: 0,
        estimatedPaymentCount: 1,
        isPast: false,
        isToday: false,
        requiresAction: true,
      );
      expect(
        AssetHighInterestHighlightService.highestRateRowForPaymentRisk(
          normalRisk,
          <AssetLiabilityDebtRow>[yokohama, mobit, normal],
        ),
        isNull,
      );
    });
  });
}
