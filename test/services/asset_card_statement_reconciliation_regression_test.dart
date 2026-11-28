import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/pages/asset_management_page.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';
import 'package:my_web_app/services/asset_management_insight_service.dart';

void main() {
  group('Issue #5373 card statement reconciliation regression', () {
    const planner = AssetLiabilityPlanningService();
    const insightService = AssetManagementInsightService();
    final baseDate = DateTime(2026, 9, 3);

    test(
      'famipay_card clears missing-import and mismatch alerts after statement registration',
      () {
        final beforeWorkbook = planner.buildWorkbook(
          baseDate: baseDate,
          latestSnapshot: const <String, double>{
            'bank': 300000,
            'ファミペイ': -30000,
            'KDDI': -15000,
          },
          monthlyPaymentOverrides: const <String, double>{
            'famipay_card': 30000,
            AssetLiabilityPlanningService.kddiProviderAccountId: 15000,
          },
          cardBillingAccountIds: const <String, String>{
            AssetLiabilityPlanningService.kddiProviderAccountId: 'famipay_card',
          },
          cardStatementLines: const <AssetLiabilityCardStatementLine>[],
        );

        final beforeGroup = beforeWorkbook.cardStatementReconciliation.groups
            .singleWhere((group) => group.billingAccountId == 'famipay_card');
        expect(beforeGroup.hasStatementLines, isFalse);
        expect(beforeGroup.configuredDifference, -15000);
        expect(beforeGroup.statementDifference, -30000);
        expect(
          beforeGroup.alerts,
          containsAll(<String>[
            AssetLiabilityPlanningService.cardStatementMissingImportAlert,
            AssetLiabilityPlanningService.cardStatementConfiguredMismatchAlert,
          ]),
        );
        expect(
          beforeWorkbook.cardStatementReconciliation.needsReviewGroups
              .any((group) => group.billingAccountId == 'famipay_card'),
          isTrue,
        );

        final beforeReport =
            insightService.buildReport(workbook: beforeWorkbook);
        final beforePrompt = const AssetManagementInsightPromptBuilder()
            .buildDetailedAdvicePrompt(beforeReport);
        expect(beforePrompt, contains('カード明細の取り込みが未実施です'));
        expect(beforePrompt, contains('設定済みカード内訳合計が請求額と一致しません'));

        final afterWorkbook = planner.buildWorkbook(
          baseDate: baseDate,
          latestSnapshot: const <String, double>{
            'bank': 300000,
            'ファミペイ': -30000,
            'KDDI': -30000,
          },
          monthlyPaymentOverrides: const <String, double>{
            'famipay_card': 30000,
            AssetLiabilityPlanningService.kddiProviderAccountId: 30000,
          },
          cardBillingAccountIds: const <String, String>{
            AssetLiabilityPlanningService.kddiProviderAccountId: 'famipay_card',
          },
          cardStatementLines: const <AssetLiabilityCardStatementLine>[
            AssetLiabilityCardStatementLine(
              id: 'line_fami_1',
              billingAccountId: 'famipay_card',
              billingAccountName: 'ファミペイ',
              postedAt: null,
              description: 'ファミペイ利用1',
              amount: 15000,
            ),
            AssetLiabilityCardStatementLine(
              id: 'line_fami_2',
              billingAccountId: 'famipay_card',
              billingAccountName: 'ファミペイ',
              postedAt: null,
              description: 'ファミペイ利用2',
              amount: 15000,
            ),
          ],
        );

        final afterGroup = afterWorkbook.cardStatementReconciliation.groups
            .singleWhere((group) => group.billingAccountId == 'famipay_card');
        expect(afterGroup.hasStatementLines, isTrue);
        expect(afterGroup.statementLineTotal, 30000);
        expect(afterGroup.statementDifference, 0);
        expect(afterGroup.configuredDifference, 0);
        expect(afterGroup.alerts, isEmpty);
        expect(
          afterWorkbook.cardStatementReconciliation.needsReviewGroups
              .any((group) => group.billingAccountId == 'famipay_card'),
          isFalse,
        );

        final afterReport = insightService.buildReport(workbook: afterWorkbook);
        final afterPrompt = const AssetManagementInsightPromptBuilder()
            .buildDetailedAdvicePrompt(afterReport);
        expect(afterPrompt, isNot(contains('カード明細の取り込みが未実施です')));
        expect(afterPrompt, isNot(contains('設定済みカード内訳合計が請求額と一致しません')));
      },
    );

    test(
      'acom_shopping switches from manual unimported notice to imported line breakdown',
      () {
        const revolvingConfigs = <String, AssetLiabilityRevolvingCreditConfig>{
          AssetLiabilityPlanningService.acomShoppingAccountId:
              AssetLiabilityRevolvingCreditConfig(
            monthlyAmount: 10000,
            newUsageAmount: 25000,
            creditLimit: 500000,
          ),
        };
        const priorBalances = <String, double>{
          AssetLiabilityPlanningService.acomShoppingAccountId: 350000,
        };

        final beforeWorkbook = planner.buildWorkbook(
          baseDate: baseDate,
          latestSnapshot: const <String, double>{
            'bank': 300000,
            'アコムショッピング': -400000,
          },
          revolvingConfigs: revolvingConfigs,
          cardStatementLines: const <AssetLiabilityCardStatementLine>[],
        );

        final beforeRow = beforeWorkbook.debtMasterRows.singleWhere(
          (row) =>
              row.id == AssetLiabilityPlanningService.acomShoppingAccountId,
        );
        expect(beforeRow.isRevolving, isTrue);
        expect(beforeRow.revolvingBilling?.hasImportedStatement, isFalse);
        expect(beforeRow.revolvingBilling?.newUsageAmount, 25000);
        expect(
          beforeRow.revolvingBilling?.usageItems.single.id,
          'manual_usage',
        );
        expect(beforeRow.scheduledPaymentAmount, 35000);

        final beforeReport = insightService.buildReport(
          workbook: beforeWorkbook,
          priorMonthAccountBalances: priorBalances,
        );
        final beforePrompt = const AssetManagementInsightPromptBuilder()
            .buildDetailedAdvicePrompt(beforeReport);
        expect(beforePrompt, contains('カード明細の取り込みが未実施'));

        final afterWorkbook = planner.buildWorkbook(
          baseDate: baseDate,
          latestSnapshot: const <String, double>{
            'bank': 300000,
            'アコムショッピング': -400000,
          },
          revolvingConfigs: revolvingConfigs,
          cardStatementLines: const <AssetLiabilityCardStatementLine>[
            AssetLiabilityCardStatementLine(
              id: 'line_acom_1',
              billingAccountId:
                  AssetLiabilityPlanningService.acomShoppingAccountId,
              billingAccountName: 'アコムショッピング',
              postedAt: null,
              description: 'ショッピング利用A',
              amount: 6000,
            ),
            AssetLiabilityCardStatementLine(
              id: 'line_acom_2',
              billingAccountId:
                  AssetLiabilityPlanningService.acomShoppingAccountId,
              billingAccountName: 'アコムショッピング',
              postedAt: null,
              description: 'ショッピング利用B',
              amount: 8000,
            ),
          ],
        );

        final afterRow = afterWorkbook.debtMasterRows.singleWhere(
          (row) =>
              row.id == AssetLiabilityPlanningService.acomShoppingAccountId,
        );
        final afterGroup =
            afterWorkbook.cardStatementReconciliation.groups.singleWhere(
          (group) =>
              group.billingAccountId ==
              AssetLiabilityPlanningService.acomShoppingAccountId,
        );
        expect(afterRow.isRevolving, isTrue);
        expect(afterRow.revolvingBilling?.hasImportedStatement, isTrue);
        expect(afterRow.revolvingBilling?.newUsageAmount, 14000);
        expect(afterRow.revolvingBilling?.usageItems.length, 2);
        expect(afterGroup.statementLineTotal, 14000);
        expect(afterRow.scheduledPaymentAmount, 24000);

        final afterReport = insightService.buildReport(
          workbook: afterWorkbook,
          priorMonthAccountBalances: priorBalances,
        );
        final afterPrompt = const AssetManagementInsightPromptBuilder()
            .buildDetailedAdvicePrompt(afterReport);
        expect(afterPrompt, contains('新規利用内訳(2件 / 合計14,000円)'));
        expect(afterPrompt, isNot(contains('カード明細の取り込みが未実施')));
      },
    );

    test(
      'reconciled famipay_card isolates remaining unreconciled loan balance difference',
      () {
        final workbook = planner.buildWorkbook(
          baseDate: baseDate,
          latestSnapshot: const <String, double>{
            'bank': 300000,
            'ファミペイ': -30000,
            'KDDI': -30000,
            'アコムカードローン': -130000,
          },
          monthlyPaymentOverrides: const <String, double>{
            'famipay_card': 30000,
            AssetLiabilityPlanningService.kddiProviderAccountId: 30000,
          },
          cardBillingAccountIds: const <String, String>{
            AssetLiabilityPlanningService.kddiProviderAccountId: 'famipay_card',
          },
          cardStatementLines: const <AssetLiabilityCardStatementLine>[
            AssetLiabilityCardStatementLine(
              id: 'line_fami_clean',
              billingAccountId: 'famipay_card',
              billingAccountName: 'ファミペイ',
              postedAt: null,
              description: 'ファミペイ確定明細',
              amount: 30000,
            ),
          ],
        );

        final famipayGroup = workbook.cardStatementReconciliation.groups
            .singleWhere((group) => group.billingAccountId == 'famipay_card');
        expect(famipayGroup.alerts, isEmpty);

        final report = insightService.buildReport(
          workbook: workbook,
          priorMonthAccountBalances: const <String, double>{
            'acom_card_loan': 100000,
          },
        );
        final disciplineReport = report.disciplineReport!;
        expect(disciplineReport.totalNewBorrowing, greaterThan(0));

        final breakdown = unreconciledBalanceDiffBreakdown(disciplineReport);
        expect(breakdown.length, 1);
        expect(breakdown.single.accountName, 'アコムカードローン');
        expect(breakdown.single.amount, greaterThan(0));
      },
    );
  });
}
