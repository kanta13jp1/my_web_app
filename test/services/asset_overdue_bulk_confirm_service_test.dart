import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_overdue_bulk_confirm_service.dart';

void main() {
  group('AssetOverdueBulkConfirmService', () {
    AssetLiabilityDebtRow debt({
      required String id,
      required String name,
      bool paid = false,
      bool includedInBillingAccount = false,
      double scheduledPaymentAmount = 10000,
    }) {
      return AssetLiabilityDebtRow(
        id: id,
        name: name,
        kind: AssetLiabilityAccountKind.cardLoan,
        balance: -100000,
        paymentDay: 2,
        paymentSourceAccountId: 'bank',
        paymentSourceAccountName: 'bank',
        paymentMethod: AssetLiabilityPaymentMethod.direct,
        paymentMethodLabel: '直接支払い',
        paymentMethodSettingSource:
            AssetLiabilityPaymentMethodSettingSource.builtInDefault,
        billingAccountId: null,
        billingAccountName: null,
        includedInBillingAccount: includedInBillingAccount,
        annualRate: 0.15,
        minimumPaymentEstimate: scheduledPaymentAmount,
        manualPaymentAmount: scheduledPaymentAmount,
        scheduledPaymentAmount: scheduledPaymentAmount,
        monthlyInterestEstimate: 1000,
        principalPaymentEstimate: 9000,
        balanceAfterPaymentEstimate: -91000,
        liabilityShare: 0.5,
        priorityLabel: '高金利',
        paymentAmountEstimated: false,
        billingConfirmed: true,
        paid: paid,
        requiresAction: !paid,
      );
    }

    AssetLiabilityCashflowRow payment({
      required String accountId,
      required String accountName,
      required DateTime paymentDate,
      required double paymentAmount,
      bool paid = false,
      bool overdue = true,
      bool includedInBillingAccount = false,
    }) {
      return AssetLiabilityCashflowRow(
        eventType: AssetLiabilityCashflowEventType.payment,
        accountId: accountId,
        accountName: accountName,
        paymentDay: paymentDate.day,
        paymentDate: paymentDate,
        paymentSourceAccountId: 'bank',
        paymentSourceAccountName: 'bank',
        destinationAccountId: null,
        destinationAccountName: null,
        paymentMethod: AssetLiabilityPaymentMethod.direct,
        paymentMethodLabel: '直接支払い',
        paymentMethodSettingSource:
            AssetLiabilityPaymentMethodSettingSource.builtInDefault,
        billingAccountId: null,
        billingAccountName: null,
        includedInBillingAccount: includedInBillingAccount,
        paymentAmount: paymentAmount,
        paymentAmountEstimated: false,
        paid: paid,
        received: false,
        overdue: overdue,
        cashBeforePayment: 50000,
        cashAfterPayment: 50000 - paymentAmount,
        riskLevel: AssetLiabilityCashRiskLevel.normal,
      );
    }

    AssetLiabilityWorkbook buildWorkbook({
      required List<AssetLiabilityDebtRow> debts,
      required List<AssetLiabilityCashflowRow> cashflows,
    }) {
      return AssetLiabilityWorkbook(
        baseDate: DateTime(2026, 9, 5),
        accounts: const <AssetLiabilityAccount>[
          AssetLiabilityAccount(
            id: 'bank',
            name: 'bank',
            kind: AssetLiabilityAccountKind.deposit,
            balance: 100000,
          ),
        ],
        debtMasterRows: debts,
        repaymentPriorityRows: debts,
        paymentDayRisks: const <AssetLiabilityPaymentDayRisk>[],
        cashflowRows: cashflows,
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
        liabilityTotal: -100000,
        netWorth: 0,
        monthlyMinimumPaymentEstimateTotal: 30000,
        monthlyScheduledPaymentTotal: 30000,
        monthlyActualPaymentTotal: 0,
        monthlyPaymentDifferenceTotal: 0,
        monthlyUnpaidPaymentTotal: 30000,
        monthlyUnreceivedIncomeTotal: 0,
        cashAfterMinimumPayments: 70000,
        cashAfterScheduledPayments: 70000,
        debtToAssetRatio: 1,
        topFourDebtShare: 1,
        manualPaymentCount: 2,
        estimatedPaymentCount: 0,
      );
    }

    test('collects only unpaid direct overdue rows sorted by date then amount',
        () {
      final workbook = buildWorkbook(
        debts: <AssetLiabilityDebtRow>[
          debt(id: 'mobit', name: 'モビット', scheduledPaymentAmount: 15000),
          debt(id: 'acom', name: 'アコムカードローン', scheduledPaymentAmount: 12000),
          debt(id: 'paid_loan', name: '支払済みローン', paid: true),
          debt(
            id: 'billed_item',
            name: 'カードまとめ',
            includedInBillingAccount: true,
          ),
          debt(id: 'future_loan', name: '来週ローン', scheduledPaymentAmount: 8000),
        ],
        cashflows: <AssetLiabilityCashflowRow>[
          payment(
            accountId: 'acom',
            accountName: 'アコムカードローン',
            paymentDate: DateTime(2026, 9, 3),
            paymentAmount: 12000,
          ),
          payment(
            accountId: 'mobit',
            accountName: 'モビット',
            paymentDate: DateTime(2026, 9, 1),
            paymentAmount: 15000,
          ),
          payment(
            accountId: 'mobit',
            accountName: 'モビット',
            paymentDate: DateTime(2026, 9, 1),
            paymentAmount: 15000,
          ),
          payment(
            accountId: 'paid_loan',
            accountName: '支払済みローン',
            paymentDate: DateTime(2026, 9, 1),
            paymentAmount: 5000,
            paid: true,
            overdue: true,
          ),
          payment(
            accountId: 'billed_item',
            accountName: 'カードまとめ',
            paymentDate: DateTime(2026, 9, 2),
            paymentAmount: 4000,
            includedInBillingAccount: true,
          ),
          payment(
            accountId: 'future_loan',
            accountName: '来週ローン',
            paymentDate: DateTime(2026, 9, 10),
            paymentAmount: 8000,
            overdue: false,
          ),
        ],
      );

      final items = AssetOverdueBulkConfirmService.collectOverdueUnpaidItems(
        workbook,
      );
      expect(items, hasLength(2));
      expect(items[0].debtRow.id, 'mobit');
      expect(items[0].overdueDays, 4);
      expect(items[1].debtRow.id, 'acom');
      expect(items[1].overdueDays, 2);

      final allTotal = AssetOverdueBulkConfirmService.totalSelectedAmount(
        items,
        const <String>{'mobit', 'acom'},
      );
      expect(allTotal, 27000);

      final partialTotal = AssetOverdueBulkConfirmService.totalSelectedAmount(
        items,
        const <String>{'acom'},
      );
      expect(partialTotal, 12000);
    });
  });
}
