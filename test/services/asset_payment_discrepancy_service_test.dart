import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_payment_discrepancy_service.dart';

void main() {
  AssetLiabilityDebtRow buildRow({
    required String id,
    required String name,
    double minimumPaymentEstimate = 10000,
    double scheduledPaymentAmount = 10000,
    double? actualPaymentAmount,
    String? paymentDifferenceReason,
    bool includedInBillingAccount = false,
    AssetLiabilityPaymentMethod paymentMethod =
        AssetLiabilityPaymentMethod.direct,
  }) {
    return AssetLiabilityDebtRow(
      id: id,
      name: name,
      kind: AssetLiabilityAccountKind.cardLoan,
      balance: -200000,
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
      annualRate: 0.145,
      minimumPaymentEstimate: minimumPaymentEstimate,
      manualPaymentAmount: scheduledPaymentAmount,
      scheduledPaymentAmount: scheduledPaymentAmount,
      actualPaymentAmount: actualPaymentAmount,
      paymentDifferenceReason: paymentDifferenceReason,
      monthlyInterestEstimate: 2400,
      principalPaymentEstimate: 7600,
      balanceAfterPaymentEstimate: -192400,
      liabilityShare: 0.2,
      priorityLabel: '高',
      paymentAmountEstimated: false,
      billingConfirmed: true,
      paid: true,
      requiresAction: false,
    );
  }

  AssetLiabilityWorkbook buildWorkbook(List<AssetLiabilityDebtRow> rows) {
    return AssetLiabilityWorkbook(
      baseDate: DateTime(2026, 9, 2),
      accounts: const <AssetLiabilityAccount>[],
      debtMasterRows: rows,
      repaymentPriorityRows: const <AssetLiabilityDebtRow>[],
      paymentDayRisks: const <AssetLiabilityPaymentDayRisk>[],
      cashflowRows: const <AssetLiabilityCashflowRow>[],
      incomePlans: const <AssetLiabilityIncomePlan>[],
      transferTasks: const <AssetLiabilityTransferTask>[],
      accountCashflowSummaries: const <AssetLiabilityAccountCashflowSummary>[],
      transferSuggestions: const <AssetLiabilityTransferSuggestion>[],
      cardBillingReview: const AssetLiabilityCardBillingReviewData(
        directPaymentItems: <AssetLiabilityCardBillingReviewItem>[],
        cardBillingGroups: <AssetLiabilityCardBillingGroup>[],
        missingBillingAccountItems: <AssetLiabilityCardBillingReviewItem>[],
        needsReviewItems: <AssetLiabilityCardBillingReviewItem>[],
        doubleCountingRiskItems: <AssetLiabilityCardBillingReviewItem>[],
      ),
      cardStatementReconciliation:
          const AssetLiabilityCardStatementReconciliationData(
        groups: <AssetLiabilityCardStatementReconciliationGroup>[],
        unmatchedStatementLines: <AssetLiabilityCardStatementLine>[],
      ),
      cashLikeTotal: 100000,
      securitiesTotal: 0,
      positiveAssetTotal: 100000,
      liabilityTotal: -200000,
      netWorth: -100000,
      monthlyMinimumPaymentEstimateTotal: 10000,
      monthlyScheduledPaymentTotal: 10000,
      monthlyActualPaymentTotal: 10000,
      monthlyPaymentDifferenceTotal: 0,
      monthlyUnpaidPaymentTotal: 0,
      monthlyUnreceivedIncomeTotal: 0,
      cashAfterMinimumPayments: 90000,
      cashAfterScheduledPayments: 90000,
      debtToAssetRatio: 2.0,
      topFourDebtShare: 1.0,
      manualPaymentCount: 1,
      estimatedPaymentCount: 0,
    );
  }

  group('AssetPaymentDiscrepancyService', () {
    test(
      'detects >=1000 diff, <1000 missing reason, and filters noise/null/included rows',
      () {
        final workbook = buildWorkbook(<AssetLiabilityDebtRow>[
          buildRow(
            id: 'yokohama_bank',
            name: '横浜銀行',
            scheduledPaymentAmount: 0,
            actualPaymentAmount: 5146,
            paymentDifferenceReason: null,
          ),
          buildRow(
            id: 'mobit',
            name: 'モビット',
            scheduledPaymentAmount: 10000,
            actualPaymentAmount: 12500,
            paymentDifferenceReason: '端数調整で追加返済',
          ),
          buildRow(
            id: 'small_missing_reason',
            name: '小額理由なし',
            scheduledPaymentAmount: 10000,
            actualPaymentAmount: 10500,
            paymentDifferenceReason: '   ',
          ),
          buildRow(
            id: 'small_with_reason',
            name: '小額理由あり',
            scheduledPaymentAmount: 10000,
            actualPaymentAmount: 10500,
            paymentDifferenceReason: '手数料分',
          ),
          buildRow(
            id: 'sub_yen_noise',
            name: '微小誤差',
            scheduledPaymentAmount: 10000,
            actualPaymentAmount: 10000.4,
            paymentDifferenceReason: null,
          ),
          buildRow(
            id: 'no_actual',
            name: '実支払未入力',
            scheduledPaymentAmount: 10000,
            actualPaymentAmount: null,
          ),
          buildRow(
            id: 'included_card',
            name: 'カード合算行',
            scheduledPaymentAmount: 0,
            actualPaymentAmount: 9000,
            includedInBillingAccount: true,
            paymentMethod: AssetLiabilityPaymentMethod.includedInCard,
          ),
        ]);

        final items = AssetPaymentDiscrepancyService.detectDiscrepancies(
          workbook,
        );
        expect(
          items.map((e) => e.accountId).toList(),
          <String>['yokohama_bank', 'mobit', 'small_missing_reason'],
        );

        expect(items[0].differenceAmount, 5146);
        expect(items[0].exceedsThreshold, isTrue);
        expect(items[0].missingReason, isTrue);

        expect(items[1].differenceAmount, 2500);
        expect(items[1].exceedsThreshold, isTrue);
        expect(items[1].missingReason, isFalse);
        expect(items[1].reason, '端数調整で追加返済');

        expect(items[2].differenceAmount, 500);
        expect(items[2].exceedsThreshold, isFalse);
        expect(items[2].missingReason, isTrue);
      },
    );

    test(
      'detectAllForInsight captures minimum-payment shortfall and infers reasons (#3393)',
      () {
        final workbook = buildWorkbook(<AssetLiabilityDebtRow>[
          buildRow(
            id: 'under_min',
            name: '最低額不足カード',
            scheduledPaymentAmount: 5000,
            actualPaymentAmount: 5000,
          ),
          buildRow(
            id: 'under_sched',
            name: '予定不足ローン',
            minimumPaymentEstimate: 5000,
            scheduledPaymentAmount: 10000,
            actualPaymentAmount: 7000,
          ),
          buildRow(
            id: 'over_sched',
            name: '過払いローン',
            scheduledPaymentAmount: 10000,
            actualPaymentAmount: 15000,
            paymentDifferenceReason: '繰上返済',
          ),
          buildRow(
            id: 'exact_match',
            name: '完全一致ローン',
            scheduledPaymentAmount: 10000,
            actualPaymentAmount: 10000,
          ),
        ]);

        final items = AssetPaymentDiscrepancyService.detectAllForInsight(
          workbook,
        );
        expect(
          items.map((e) => e.accountId).toList(),
          <String>['under_min', 'over_sched', 'under_sched'],
        );

        expect(items[0].differenceAmount, 0);
        expect(items[0].effectiveDifferenceForInsight, -5000);
        expect(AssetPaymentDiscrepancyService.needsTopUp(items[0]), isTrue);
        expect(
          AssetPaymentDiscrepancyService.inferReasonHint(items[0]),
          contains('推定最低支払額を下回る実支払'),
        );

        expect(AssetPaymentDiscrepancyService.needsTopUp(items[1]), isFalse);
        expect(
          AssetPaymentDiscrepancyService.inferReasonHint(items[1]),
          contains('支払予定額より多い実支払'),
        );

        expect(AssetPaymentDiscrepancyService.needsTopUp(items[2]), isTrue);
        expect(
          AssetPaymentDiscrepancyService.inferReasonHint(items[2]),
          contains('支払予定額より少ない実支払'),
        );
      },
    );
  });
}
