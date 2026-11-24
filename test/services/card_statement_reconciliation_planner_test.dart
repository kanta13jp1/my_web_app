import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_liability_monthly_state_store.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';
import 'package:my_web_app/services/asset_management_ai_summary_service.dart';
import 'package:my_web_app/services/asset_management_insight_service.dart';
import 'package:my_web_app/services/asset_salary_spending_entries.dart';
import 'package:my_web_app/services/card_statement_reconciliation_planner.dart';
import 'package:shared_preferences/shared_preferences.dart';

AssetLiabilityWorkbook _buildAuPayMismatchWorkbook({
  List<AssetLiabilityCardStatementLine> cardStatementLines =
      const <AssetLiabilityCardStatementLine>[],
}) {
  const planner = AssetLiabilityPlanningService();
  return planner.buildWorkbook(
    latestSnapshot: const <String, double>{
      'bank': 500000,
      'auPayカード': -40163,
      'au': -32152,
    },
    baseDate: DateTime(2026, 6, 10),
    monthlyPaymentOverrides: const <String, double>{
      'aupay_card': 40163,
      'au': 32152,
    },
    cardBillingAccountIds: const <String, String>{
      'au': 'aupay_card',
    },
    cardStatementLines: cardStatementLines,
  );
}

void main() {
  group('CardStatementReconciliationPlanner (#3329 / #3326 / #3349)', () {
    test(
      'suggests exact deficit 8011 for auPAY mismatch and previews balance/overshoot',
      () {
        final workbook = _buildAuPayMismatchWorkbook();
        final group = workbook.cardStatementReconciliation.groups.firstWhere(
          (g) => g.billingAccountId == 'aupay_card',
        );

        expect(group.billedAmount, 40163);
        expect(group.configuredDetailTotal, 32152);
        expect(group.configuredDifference, -8011);
        expect(group.needsReview, isTrue);
        expect(
          CardStatementReconciliationPlanner.suggestedBalancingAmount(group),
          8011,
        );

        final matched = CardStatementReconciliationPlanner.previewAdjustment(
          group: group,
          additionalAmount: 8011,
        );
        expect(matched.projectedConfiguredTotal, 40163);
        expect(matched.projectedConfiguredDifference, 0);
        expect(matched.isBalanced, isTrue);
        expect(matched.isOvershoot, isFalse);
        expect(matched.resolvesAlert, isTrue);

        final partial = CardStatementReconciliationPlanner.previewAdjustment(
          group: group,
          additionalAmount: 5000,
        );
        expect(partial.isBalanced, isFalse);
        expect(partial.isOvershoot, isFalse);
        expect(partial.resolvesAlert, isFalse);

        final overshoot = CardStatementReconciliationPlanner.previewAdjustment(
          group: group,
          additionalAmount: 10000,
        );
        expect(overshoot.isBalanced, isFalse);
        expect(overshoot.isOvershoot, isTrue);
        expect(overshoot.resolvesAlert, isFalse);
      },
    );

    test(
      'buildReconciledStatementLines resolves alerts, insight flag, and AI manual_statement_pending',
      () {
        final initialWorkbook = _buildAuPayMismatchWorkbook();
        const insightService = AssetManagementInsightService();
        final initialReport = insightService.buildReport(
          workbook: initialWorkbook,
        );
        final aiSummaryService = AssetManagementAiSummaryService(
          now: () => DateTime(2026, 6, 10),
        );
        final initialPayload = aiSummaryService.buildAiDetailedPayload(
          initialReport,
        );
        final initialReconJson = (initialPayload['workbook']
                as Map<String, dynamic>)['card_statement_reconciliation']
            as Map<String, dynamic>;

        expect(initialReport.cardStatementNeedsReview, isTrue);
        expect(initialReconJson['manual_statement_pending'], isTrue);
        expect(initialReconJson['provisional_detail_count'], 0);

        final group = initialWorkbook.cardStatementReconciliation.groups
            .firstWhere((g) => g.billingAccountId == 'aupay_card');
        final updatedLines =
            CardStatementReconciliationPlanner.buildReconciledStatementLines(
          existingLines: const <AssetLiabilityCardStatementLine>[],
          group: group,
          newManualLines: <AssetLiabilityCardStatementLine>[
            AssetLiabilityCardStatementLine(
              id: 'manual_8011',
              billingAccountId: 'aupay_card',
              billingAccountName: 'auPayカード',
              postedAt: DateTime(2026, 6, 10),
              description: '手動明細補正',
              amount: 8011,
              category: 'その他',
            ),
          ],
          adjustConfiguredTotal: true,
        );

        final reconciledWorkbook = _buildAuPayMismatchWorkbook(
          cardStatementLines: updatedLines,
        );
        final reconciledGroup =
            reconciledWorkbook.cardStatementReconciliation.groups.firstWhere(
          (g) => g.billingAccountId == 'aupay_card',
        );
        final reconciledReport = insightService.buildReport(
          workbook: reconciledWorkbook,
        );
        final reconciledPayload = aiSummaryService.buildAiDetailedPayload(
          reconciledReport,
        );
        final reconciledReconJson = (reconciledPayload['workbook']
                as Map<String, dynamic>)['card_statement_reconciliation']
            as Map<String, dynamic>;

        expect(reconciledGroup.configuredDetailTotal, 40163);
        expect(reconciledGroup.statementLineTotal, 40163);
        expect(reconciledGroup.alerts, isEmpty);
        expect(reconciledGroup.needsReview, isFalse);
        expect(reconciledReport.cardStatementNeedsReview, isFalse);
        expect(reconciledReconJson['manual_statement_pending'], isFalse);
      },
    );

    test(
      'provisional lines never double-count totals or spending and promote cleanly (#3349)',
      () {
        final provisionalLine = AssetLiabilityCardStatementLine(
          id: 'prov_1',
          billingAccountId: 'aupay_card',
          billingAccountName: 'auPayカード',
          postedAt: DateTime(2026, 6, 9),
          description: '未取込分仮記録',
          amount: 8011,
          isProvisional: true,
          createdAt: DateTime(2026, 5, 28),
        );

        expect(
          CardStatementReconciliationPlanner.isProvisionalCarryOver(
            provisionalLine,
            DateTime(2026, 6, 10),
          ),
          isTrue,
        );
        expect(
          CardStatementReconciliationPlanner.isProvisionalCarryOver(
            provisionalLine,
            DateTime(2026, 5, 29),
          ),
          isFalse,
        );

        final withProvisionalWorkbook = _buildAuPayMismatchWorkbook(
          cardStatementLines: <AssetLiabilityCardStatementLine>[
            provisionalLine,
          ],
        );
        final provGroup = withProvisionalWorkbook
            .cardStatementReconciliation.groups
            .firstWhere((g) => g.billingAccountId == 'aupay_card');

        expect(provGroup.configuredDetailTotal, 32152);
        expect(provGroup.statementLineTotal, 0);
        expect(provGroup.provisionalBillingDetails, hasLength(1));
        expect(provGroup.provisionalTotal, 8011);
        expect(withProvisionalWorkbook.provisionalBillingDetails, hasLength(1));
        expect(provGroup.needsReview, isTrue);

        final spendingWithProvisional = AssetSalarySpendingEntries.build(
          cardStatementLines: <AssetLiabilityCardStatementLine>[
            provisionalLine,
          ],
          recentFlows: const <Map<String, dynamic>>[],
          monthlyIncomePlans: const <AssetLiabilityIncomePlan>[],
          payslipSalaryIncomes: const <Map<String, dynamic>>[],
          payslipRows: const <Map<String, dynamic>>[],
          flowDisplayTitle: (_) => '',
        );
        expect(spendingWithProvisional.expenses, isEmpty);

        final promotedLines =
            CardStatementReconciliationPlanner.promoteProvisionalLine(
          existingLines: <AssetLiabilityCardStatementLine>[provisionalLine],
          group: provGroup,
          lineId: 'prov_1',
          promotedAt: DateTime(2026, 6, 10),
        );
        final afterPromoteWorkbook = _buildAuPayMismatchWorkbook(
          cardStatementLines: promotedLines,
        );
        final afterGroup = afterPromoteWorkbook
            .cardStatementReconciliation.groups
            .firstWhere((g) => g.billingAccountId == 'aupay_card');

        expect(afterPromoteWorkbook.provisionalBillingDetails, isEmpty);
        expect(afterGroup.configuredDetailTotal, 40163);
        expect(afterGroup.statementLineTotal, 40163);
        expect(afterGroup.needsReview, isFalse);
      },
    );

    test(
      'AssetLiabilityMonthlyStateStore round-trips provisional, category, and adjustment flags',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        const store = AssetLiabilityMonthlyStateStore();
        final month = DateTime(2026, 6, 1);
        final createdAt = DateTime(2026, 6, 10, 12, 30);

        await store.saveMonth(
          month: month,
          state: AssetLiabilityMonthlyState(
            cardStatementLines: <AssetLiabilityCardStatementLine>[
              AssetLiabilityCardStatementLine(
                id: 'line_prov',
                billingAccountId: 'aupay_card',
                billingAccountName: 'auPayカード',
                postedAt: DateTime(2026, 6, 10),
                description: '仮内訳テスト',
                amount: 8011,
                category: '食費',
                isProvisional: true,
                isConfiguredAdjustment: false,
                excludeFromStatementTotal: false,
                createdAt: createdAt,
              ),
              AssetLiabilityCardStatementLine(
                id: 'line_adj',
                billingAccountId: 'aupay_card',
                billingAccountName: 'auPayカード',
                postedAt: DateTime(2026, 6, 10),
                description: '設定調整テスト',
                amount: 1200,
                category: '日用品',
                isProvisional: false,
                isConfiguredAdjustment: true,
                excludeFromStatementTotal: true,
                createdAt: null,
              ),
            ],
          ),
        );

        final loaded = await store.loadMonth(month);
        expect(loaded.cardStatementLines, hasLength(2));

        final loadedProv = loaded.cardStatementLines.firstWhere(
          (l) => l.id == 'line_prov',
        );
        expect(loadedProv.category, '食費');
        expect(loadedProv.isProvisional, isTrue);
        expect(loadedProv.isConfiguredAdjustment, isFalse);
        expect(loadedProv.excludeFromStatementTotal, isFalse);
        expect(loadedProv.createdAt, createdAt);

        final loadedAdj = loaded.cardStatementLines.firstWhere(
          (l) => l.id == 'line_adj',
        );
        expect(loadedAdj.category, '日用品');
        expect(loadedAdj.isProvisional, isFalse);
        expect(loadedAdj.isConfiguredAdjustment, isTrue);
        expect(loadedAdj.excludeFromStatementTotal, isTrue);
      },
    );
  });
}
