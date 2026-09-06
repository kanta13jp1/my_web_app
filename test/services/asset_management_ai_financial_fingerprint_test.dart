import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';
import 'package:my_web_app/services/asset_management_ai_summary_refresh.dart';
import 'package:my_web_app/services/asset_management_ai_summary_service.dart';
import 'package:my_web_app/services/asset_management_insight_service.dart';

// Synthetic inputs only; no account access or external AI requests.
void main() {
  final service = AssetManagementAiSummaryService(
    now: () => DateTime(2026, 9, 6, 12),
  );

  void expectInvalidated(
    AssetManagementInsightReport before,
    AssetManagementInsightReport after,
  ) {
    final oldKey = service.buildRequestFingerprint(before);
    final currentKey = service.buildRequestFingerprint(after);
    expect(currentKey, isNot(oldKey));
    final oldResult = service.buildWaitingForAiResult(before);
    expect(
      service.currentResultFor(
        report: after,
        result: oldResult,
        resultKey: oldKey,
      ),
      isNull,
    );
    final newResult = service.buildWaitingForAiResult(after);
    expect(
      service.currentResultFor(
        report: after,
        result: newResult,
        resultKey: currentKey,
      ),
      same(newResult),
    );
    expect(
      AssetManagementAiSummaryRefresh.canReusePersisted(
        currentKey: currentKey,
        cachedKey: oldKey,
      ),
      isFalse,
    );
    expect(
      AssetManagementAiSummaryRefresh.isStale(
        currentKey: currentKey,
        resultKey: oldKey,
        hasResult: true,
      ),
      isTrue,
    );
  }

  Map<String, dynamic> singleRow(
    AssetManagementInsightReport report,
    String field,
  ) {
    final workbook =
        service.buildPayload(report)['workbook'] as Map<String, dynamic>;
    return (workbook[field] as List<dynamic>).single as Map<String, dynamic>;
  }

  group('Issue 5201 current financial input cache contract', () {
    test('unchanged inputs can reuse a persisted summary', () {
      final firstKey = service.buildRequestFingerprint(_report());
      final secondKey = service.buildRequestFingerprint(_report());
      expect(secondKey, firstKey);
      expect(
        AssetManagementAiSummaryRefresh.canReusePersisted(
          currentKey: secondKey,
          cachedKey: firstKey,
        ),
        isTrue,
      );
    });

    test('receiving income invalidates the unreceived summary', () {
      final before = _report();
      final after = _report(received: true);
      final oldPlans = singleRow(before, 'income_plans');
      final newPlans = singleRow(after, 'income_plans');
      expect(oldPlans['received'], isFalse);
      expect(newPlans['received'], isTrue);
      expectInvalidated(before, after);
    });

    test('a corrected debt balance invalidates the old balance summary', () {
      final before = _report();
      final after = _report(debtBalance: -60000);
      final oldRows = singleRow(before, 'debt_master_rows');
      final newRows = singleRow(after, 'debt_master_rows');
      expect(oldRows['balance'], -90000);
      expect(newRows['balance'], -60000);
      expectInvalidated(before, after);
    });

    test('a contractual payment correction invalidates the old summary', () {
      final before = _report();
      final after = _report(monthlyPayment: 3000);
      final oldRows = singleRow(before, 'debt_master_rows');
      final newRows = singleRow(after, 'debt_master_rows');
      expect(oldRows['scheduled_payment_amount'], 6000);
      expect(newRows['scheduled_payment_amount'], 3000);
      expectInvalidated(before, after);
    });
  });
}

AssetManagementInsightReport _report({
  bool received = false,
  double debtBalance = -90000,
  double monthlyPayment = 6000,
}) {
  const planner = AssetLiabilityPlanningService();
  const insight = AssetManagementInsightService();
  final workbook = planner.buildWorkbook(
    latestSnapshot: <String, double>{'bank': 30000, 'PayPay': debtBalance},
    baseDate: DateTime(2026, 9, 6),
    monthlyPaymentOverrides: <String, double>{'paypay_card': monthlyPayment},
    paymentSourceAccountIds: const <String, String>{'paypay_card': 'bank'},
    incomePlans: <AssetLiabilityIncomePlan>[
      AssetLiabilityIncomePlan(
        id: 'synthetic-income',
        date: DateTime(2026, 9, 5),
        name: 'Synthetic income',
        amount: 40000,
        destinationAccountId: 'bank',
        destinationAccountName: 'bank',
        received: received,
      ),
    ],
  );
  return insight.buildReport(workbook: workbook);
}
