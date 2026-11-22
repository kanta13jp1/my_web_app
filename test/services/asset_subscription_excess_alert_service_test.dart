import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/models/user_profile.dart';
import 'package:my_web_app/services/asset_subscription_excess_alert_service.dart';

void main() {
  group('AssetSubscriptionExcessAlertService', () {
    AssetLiabilityWorkbook buildWorkbook({
      required List<AssetRecurringFixedCost> costs,
      DateTime? baseDate,
    }) {
      return AssetLiabilityWorkbook(
        baseDate: baseDate ?? DateTime(2026, 9, 5),
        recurringFixedCosts: costs,
        accounts: const <AssetLiabilityAccount>[
          AssetLiabilityAccount(
            id: 'bank',
            name: 'bank',
            kind: AssetLiabilityAccountKind.deposit,
            balance: 100000,
          ),
        ],
        debtMasterRows: const <AssetLiabilityDebtRow>[],
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
        liabilityTotal: 0,
        netWorth: 100000,
        monthlyMinimumPaymentEstimateTotal: 0,
        monthlyScheduledPaymentTotal: 0,
        monthlyActualPaymentTotal: 0,
        monthlyPaymentDifferenceTotal: 0,
        monthlyUnpaidPaymentTotal: 0,
        monthlyUnreceivedIncomeTotal: 0,
        cashAfterMinimumPayments: 100000,
        cashAfterScheduledPayments: 100000,
        debtToAssetRatio: 0,
        topFourDebtShare: 0,
        manualPaymentCount: 0,
        estimatedPaymentCount: 0,
      );
    }

    AssetRecurringFixedCost sub(
      String id,
      String name,
      double amount, {
      AssetRecurringFixedCostCategory category =
          AssetRecurringFixedCostCategory.subscription,
      DateTime? lastBillingDate,
    }) {
      return AssetRecurringFixedCost(
        id: id,
        name: name,
        amount: amount,
        paymentDay: 15,
        category: category,
        lastBillingDate: lastBillingDate,
      );
    }

    test('triggers when active subscription count reaches threshold', () {
      final alert = AssetSubscriptionExcessAlertService.evaluate(
        workbook: buildWorkbook(
          costs: <AssetRecurringFixedCost>[
            sub('s1', 'Sub 1', 1000),
            sub('s2', 'Sub 2', 1200),
            sub('s3', 'Sub 3', 800),
            sub('s4', 'Sub 4', 900),
            sub('s5', 'Sub 5', 1100),
          ],
        ),
      );
      expect(alert, isNotNull);
      expect(alert!.activeCount, 5);
      expect(alert.monthlyTotal, 5000);
      expect(alert.annualTotal, 60000);
      expect(alert.triggers.any((t) => t.contains('件数 5件')), isTrue);
    });

    test('triggers when monthly total reaches threshold', () {
      final alert = AssetSubscriptionExcessAlertService.evaluate(
        workbook: buildWorkbook(
          costs: <AssetRecurringFixedCost>[
            sub('s1', 'Pro Plan A', 10000),
            sub('s2', 'Pro Plan B', 6000),
          ],
        ),
      );
      expect(alert, isNotNull);
      expect(alert!.activeCount, 2);
      expect(alert.monthlyTotal, 16000);
      expect(alert.triggers.any((t) => t.contains('月額')), isTrue);
    });

    test('triggers when annual subscription share exceeds 5% of annual income',
        () {
      final alert = AssetSubscriptionExcessAlertService.evaluate(
        workbook: buildWorkbook(
          costs: <AssetRecurringFixedCost>[
            sub('s1', 'Cloud Suite', 10000),
          ],
        ),
        userProfile: UserProfile(
          userId: 'u1',
          annualIncome: 2000000,
        ),
      );
      expect(alert, isNotNull);
      expect(alert!.incomeShareRatio, closeTo(0.06, 0.0001));
      expect(alert.triggers.any((t) => t.contains('年収比 6.0%')), isTrue);
    });

    test('excludes 0 yen, expired lastBillingDate, and utility entries', () {
      final alert = AssetSubscriptionExcessAlertService.evaluate(
        workbook: buildWorkbook(
          baseDate: DateTime(2026, 9, 5),
          costs: <AssetRecurringFixedCost>[
            sub('zero', 'Canceled Zero', 0),
            sub(
              'expired',
              'Ended Plan',
              30000,
              lastBillingDate: DateTime(2026, 9, 4),
            ),
            sub(
              'rent',
              '家賃',
              90000,
              category: AssetRecurringFixedCostCategory.utility,
            ),
            sub('active1', 'Active App', 1200),
            sub('active2', 'Music Plan', 980),
          ],
        ),
        userProfile: UserProfile(
          userId: 'u1',
          annualIncome: 5000000,
        ),
      );
      expect(alert, isNull);
    });
  });
}
