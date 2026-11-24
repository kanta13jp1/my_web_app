import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_late_fee_service.dart';

void main() {
  AssetLiabilityDebtRow buildRow({
    required String id,
    required String name,
    double annualRate = 0.146,
    int? paymentDay = 10,
    double balance = -150000,
    double scheduledPaymentAmount = 10000,
    bool paid = false,
    bool requiresAction = true,
    bool isDirectCashflowTarget = true,
    double? lateFeeAnnualRate,
    int overdueDays = 0,
    double estimatedLateFeeAmount = 0,
  }) {
    return AssetLiabilityDebtRow(
      id: id,
      name: name,
      kind: AssetLiabilityAccountKind.cardLoan,
      balance: balance,
      paymentDay: paymentDay,
      paymentSourceAccountId: 'wallet_cash',
      paymentSourceAccountName: '財布(現金)',
      paymentMethod: isDirectCashflowTarget
          ? AssetLiabilityPaymentMethod.direct
          : AssetLiabilityPaymentMethod.includedInCard,
      paymentMethodLabel: isDirectCashflowTarget ? '直接支払い' : 'カード合算',
      paymentMethodSettingSource:
          AssetLiabilityPaymentMethodSettingSource.builtInDefault,
      billingAccountId: isDirectCashflowTarget ? null : 'parent_card',
      billingAccountName: isDirectCashflowTarget ? null : '親カード',
      includedInBillingAccount: !isDirectCashflowTarget,
      annualRate: annualRate,
      minimumPaymentEstimate: scheduledPaymentAmount,
      manualPaymentAmount: scheduledPaymentAmount,
      scheduledPaymentAmount: scheduledPaymentAmount,
      monthlyInterestEstimate: 1800,
      principalPaymentEstimate: 8200,
      balanceAfterPaymentEstimate: balance + 8200,
      liabilityShare: 0.5,
      priorityLabel: '高',
      paymentAmountEstimated: false,
      billingConfirmed: true,
      paid: paid,
      requiresAction: requiresAction,
      lateFeeAnnualRate: lateFeeAnnualRate,
      overdueDays: overdueDays,
      estimatedLateFeeAmount: estimatedLateFeeAmount,
    );
  }

  AssetLiabilityWorkbook buildWorkbook(List<AssetLiabilityDebtRow> rows) {
    return AssetLiabilityWorkbook(
      baseDate: DateTime(2026, 9, 16),
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
      cashLikeTotal: 50000,
      securitiesTotal: 0,
      positiveAssetTotal: 50000,
      liabilityTotal: -300000,
      netWorth: -250000,
      monthlyMinimumPaymentEstimateTotal: 20000,
      monthlyScheduledPaymentTotal: 20000,
      monthlyActualPaymentTotal: 0,
      monthlyPaymentDifferenceTotal: 0,
      monthlyUnpaidPaymentTotal: 20000,
      monthlyUnreceivedIncomeTotal: 0,
      cashAfterMinimumPayments: 30000,
      cashAfterScheduledPayments: 30000,
      debtToAssetRatio: 6.0,
      topFourDebtShare: 1.0,
      manualPaymentCount: 2,
      estimatedPaymentCount: 0,
    );
  }

  group('AssetLateFeeService', () {
    test('uses statutory fallback floor 14.6% and caps default rate at 20.0%',
        () {
      expect(
        AssetLateFeeService.defaultLateFeeAnnualRate(
          kind: AssetLiabilityAccountKind.utility,
          annualRate: 0.0,
        ),
        0.146,
      );
      expect(
        AssetLateFeeService.defaultLateFeeAnnualRate(
          kind: AssetLiabilityAccountKind.cardLoan,
          annualRate: 0.18,
        ),
        0.18,
      );
      expect(
        AssetLateFeeService.defaultLateFeeAnnualRate(
          kind: AssetLiabilityAccountKind.cardLoan,
          annualRate: 0.25,
        ),
        0.20,
      );
    });

    test(
        'computes daily pro-rata late fee and balance addition for overdue unpaid direct debt',
        () {
      final result = AssetLateFeeService.estimate(
        kind: AssetLiabilityAccountKind.cardLoan,
        annualRate: 0.146,
        balance: -100000,
        scheduledPaymentAmount: 50000,
        paid: false,
        requiresAction: true,
        isDirectCashflowTarget: true,
        baseDate: DateTime(2026, 9, 16),
        paymentDate: DateTime(2026, 9, 6),
      );
      // 50,000 * 0.146 * 10 / 365 = 200.0
      expect(result.overdueDays, 10);
      expect(result.lateFeeAnnualRate, 0.146);
      expect(result.estimatedLateFeeAmount, 200);
      expect(result.projectedBalanceWithLateFee, 100200);
    });

    test(
        'returns zero late fee when paid, due today, upcoming, or card-included',
        () {
      final paid = AssetLateFeeService.estimate(
        kind: AssetLiabilityAccountKind.cardLoan,
        annualRate: 0.18,
        balance: -100000,
        scheduledPaymentAmount: 50000,
        paid: true,
        requiresAction: false,
        isDirectCashflowTarget: true,
        baseDate: DateTime(2026, 9, 16),
        paymentDate: DateTime(2026, 9, 6),
      );
      expect(paid.overdueDays, 0);
      expect(paid.estimatedLateFeeAmount, 0);
      expect(paid.lateFeeAnnualRate, isNull);

      final dueToday = AssetLateFeeService.estimate(
        kind: AssetLiabilityAccountKind.cardLoan,
        annualRate: 0.18,
        balance: -100000,
        scheduledPaymentAmount: 50000,
        paid: false,
        requiresAction: true,
        isDirectCashflowTarget: true,
        baseDate: DateTime(2026, 9, 16),
        paymentDate: DateTime(2026, 9, 16),
      );
      expect(dueToday.overdueDays, 0);
      expect(dueToday.estimatedLateFeeAmount, 0);

      final included = AssetLateFeeService.estimate(
        kind: AssetLiabilityAccountKind.creditCard,
        annualRate: 0.18,
        balance: -100000,
        scheduledPaymentAmount: 50000,
        paid: false,
        requiresAction: true,
        isDirectCashflowTarget: false,
        baseDate: DateTime(2026, 9, 16),
        paymentDate: DateTime(2026, 9, 6),
      );
      expect(included.estimatedLateFeeAmount, 0);
    });

    test(
        'summarizeWorkbook totals overdue rows and sorts descending by late fee',
        () {
      final workbook = buildWorkbook(<AssetLiabilityDebtRow>[
        buildRow(
          id: 'small_fee',
          name: '小口延滞',
          balance: -80000,
          overdueDays: 3,
          estimatedLateFeeAmount: 120,
          lateFeeAnnualRate: 0.146,
        ),
        buildRow(
          id: 'big_fee',
          name: '大口延滞',
          balance: -220000,
          overdueDays: 10,
          estimatedLateFeeAmount: 650,
          lateFeeAnnualRate: 0.18,
        ),
        buildRow(
          id: 'paid_row',
          name: '支払済み',
          paid: true,
          requiresAction: false,
          overdueDays: 0,
          estimatedLateFeeAmount: 0,
        ),
      ]);

      final summary = AssetLateFeeService.summarizeWorkbook(workbook);
      expect(summary.overdueCount, 2);
      expect(summary.totalEstimatedLateFee, 770);
      expect(
        summary.items.map((item) => item.accountId).toList(),
        <String>['big_fee', 'small_fee'],
      );
      expect(summary.items.first.projectedBalanceWithLateFee, 220650);
    });
  });
}
