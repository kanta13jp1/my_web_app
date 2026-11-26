import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';
import 'package:my_web_app/services/asset_management_ai_summary_refresh.dart';
import 'package:my_web_app/services/asset_management_ai_summary_service.dart';
import 'package:my_web_app/services/asset_management_insight_service.dart';

// Regression tests for Issue #5196:
// Ensures prompt builder & AI summary cache consistency across:
// 1. Paid fixed costs (paid: true) excluded from unpaid/overdue warnings.
// 2. Canceled/zero-amount subscriptions excluded from cashflow & warnings.
// 3. Overridden annual interest rates reflected in prompt & fingerprint.
// 4. Latest confirmed debt balance reflected in prompt & cache invalidation.
void main() {
  final summaryService = AssetManagementAiSummaryService(
    now: () => DateTime(2026, 9, 6, 12),
  );
  const promptBuilder = AssetManagementInsightPromptBuilder();

  void expectCacheInvalidated(
    AssetManagementInsightReport before,
    AssetManagementInsightReport after,
  ) {
    final oldKey = summaryService.buildRequestFingerprint(before);
    final newKey = summaryService.buildRequestFingerprint(after);
    expect(newKey, isNot(oldKey));
    expect(
      summaryService.currentResultFor(
        report: after,
        result: _dummyResult(summaryService, before),
        resultKey: oldKey,
      ),
      isNull,
    );
    expect(
      AssetManagementAiSummaryRefresh.isStale(
        currentKey: newKey,
        resultKey: oldKey,
        hasResult: true,
      ),
      isTrue,
    );
  }

  group('Issue #5196 AI prompt & cache consistency', () {
    test(
        'paid fixed cost is excluded from unpaid warnings and invalidates cache',
        () {
      final before = _buildReport(paidAccountIds: const <String>{});
      final after = _buildReport(paidAccountIds: const <String>{'acom'});

      final deterministicBefore =
          summaryService.buildDeterministicSummary(before);
      final deterministicAfter =
          summaryService.buildDeterministicSummary(after);
      expect(deterministicBefore, isNot(deterministicAfter));

      final afterPrompt = promptBuilder.buildDetailedAdvicePrompt(after);
      expect(afterPrompt, contains('支払済み:はい'));
      expectCacheInvalidated(before, after);
    });

    test('zero-amount canceled subscription is excluded from cashflow prompt',
        () {
      final report = _buildReport(
        monthlyPaymentOverrides: const <String, double>{'acom': 0},
      );
      final prompt = promptBuilder.buildDetailedAdvicePrompt(report);
      expect(prompt, isNot(contains('項目:アコム / 金額:0円')));
      expect(
        report.actionItems.where(
          (AssetManagementInsightActionItem item) =>
              item.type == AssetManagementInsightActionType.subscriptionExcess,
        ),
        isEmpty,
      );
    });

    test(
        'overridden annual rate (15.0% vs 18.0%) updates prompt and invalidates cache',
        () {
      final defaultReport = _buildReport(
        annualRateOverrides: const <String, double>{'acom': 0.18},
      );
      final overriddenReport = _buildReport(
        annualRateOverrides: const <String, double>{'acom': 0.15},
      );

      final overriddenPrompt =
          promptBuilder.buildDetailedAdvicePrompt(overriddenReport);
      expect(overriddenPrompt, contains('年利:15.00%'));
      expect(overriddenPrompt, isNot(contains('年利:18.00%')));
      expectCacheInvalidated(defaultReport, overriddenReport);
    });

    test('latest confirmed debt balance updates prompt and invalidates cache',
        () {
      final staleReport = _buildReport(acomBalance: -7697192);
      final latestReport = _buildReport(acomBalance: -7519280);

      final latestPrompt =
          promptBuilder.buildDetailedAdvicePrompt(latestReport);
      expect(latestPrompt, contains('7,519,280円'));
      expect(latestPrompt, isNot(contains('7,697,192円')));
      expectCacheInvalidated(staleReport, latestReport);
    });
  });
}

AssetManagementInsightReport _buildReport({
  double acomBalance = -500000,
  Set<String> paidAccountIds = const <String>{},
  Map<String, double> monthlyPaymentOverrides = const <String, double>{
    'acom': 15000,
  },
  Map<String, double> annualRateOverrides = const <String, double>{},
}) {
  const planner = AssetLiabilityPlanningService();
  const insight = AssetManagementInsightService();
  final workbook = planner.buildWorkbook(
    latestSnapshot: <String, double>{
      'bank': 100000,
      'アコム': acomBalance,
    },
    baseDate: DateTime(2026, 9, 6),
    paidAccountIds: paidAccountIds,
    monthlyPaymentOverrides: monthlyPaymentOverrides,
    annualRateOverrides: annualRateOverrides,
    paymentSourceAccountIds: const <String, String>{'acom': 'bank'},
  );
  return insight.buildReport(workbook: workbook);
}

AssetManagementAiSummaryResult _dummyResult(
  AssetManagementAiSummaryService service,
  AssetManagementInsightReport report,
) {
  return AssetManagementAiSummaryResult(
    status: AssetManagementAiSummaryStatus.aiGenerated,
    text: 'Synthetic AI summary',
    source: 'synthetic test provider',
    errorMessage: null,
    generatedAt: DateTime(2026, 9, 6, 12),
    payload: service.buildPayload(report),
    aiDeveloperRequests: const <AssetManagementDeveloperRequest>[],
  );
}
