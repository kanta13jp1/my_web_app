import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/ai_hub_chat_service.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';
import 'package:my_web_app/services/asset_management_ai_summary_service.dart';
import 'package:my_web_app/services/asset_management_insight_service.dart';

void main() {
  group('AssetManagementAiSummaryService', () {
    test('does not call ai-hub when feature flag is off', () async {
      var calls = 0;
      final service = AssetManagementAiSummaryService(
        aiEnabled: false,
        chatService: AiHubChatService(
          invoker: (body) async {
            calls += 1;
            return <String, dynamic>{'success': true, 'text': 'should not run'};
          },
        ),
        now: () => DateTime(2026, 5, 1, 12),
      );

      final result = await service.generateSummary(report: _report());

      expect(calls, 0);
      expect(result.status, AssetManagementAiSummaryStatus.disabled);
      expect(result.usedExternalAi, false);
      expect(result.source.contains('feature flag off'), true);
      expect(
        result.text.contains('Amounts are calculated by Dart rules'),
        true,
      );
    });

    test('calls ai-hub provider.chat when feature flag is on', () async {
      Map<String, dynamic>? capturedBody;
      final service = AssetManagementAiSummaryService(
        aiEnabled: true,
        chatService: AiHubChatService(
          invoker: (body) async {
            capturedBody = body;
            return <String, dynamic>{
              'success': true,
              'text': 'AI generated summary',
              'provider': 'deepinfra',
            };
          },
        ),
        now: () => DateTime(2026, 5, 1, 12),
      );

      final result = await service.generateSummary(report: _report());

      expect(result.status, AssetManagementAiSummaryStatus.aiGenerated);
      expect(result.usedExternalAi, true);
      expect(result.text, 'AI generated summary');
      expect(capturedBody?['action'], 'provider.chat');
      expect(capturedBody?['provider'], 'deepinfra');
      expect(capturedBody?['trace_id'], 'asset-management-ai-summary');
      expect(
        capturedBody?['message'].toString().contains(
              'Computed insight payload',
            ),
        true,
      );
      expect(
        capturedBody?['message'].toString().contains(
              '"external_ai_may_recalculate_amounts":false',
            ),
        true,
      );
    });

    test('falls back to deterministic text when ai-hub fails', () async {
      final service = AssetManagementAiSummaryService(
        aiEnabled: true,
        chatService: AiHubChatService(
          invoker: (body) async => throw const AiHubChatException('boom'),
        ),
        now: () => DateTime(2026, 5, 1, 12),
      );

      final result = await service.generateSummary(report: _report());

      expect(result.status, AssetManagementAiSummaryStatus.fallback);
      expect(result.usedExternalAi, false);
      expect(result.errorMessage?.contains('boom'), true);
      expect(
        result.text.contains('Amounts are calculated by Dart rules'),
        true,
      );
    });

    test('builds payload from calculated insights only', () {
      final report = _report();
      final service = AssetManagementAiSummaryService(
        now: () => DateTime(2026, 5, 1, 12),
      );

      final payload = service.buildPayload(report);
      final available = payload['available_money'] as Map<String, dynamic>;
      final today = available['today'] as Map<String, dynamic>;
      final guardrails = payload['guardrails'] as Map<String, dynamic>;

      expect(payload.containsKey('workbook'), false);
      expect(today['available_amount'], report.todayAvailable.availableAmount);
      expect(payload['action_items'] is List<dynamic>, true);
      expect(payload['movement_suggestions'] is List<dynamic>, true);
      expect(payload['developer_requests'] is List<dynamic>, true);
      expect(guardrails['calculation_owner'], 'dart_service');
      expect(guardrails['external_ai_may_summarize_only'], true);
      expect(guardrails['external_ai_may_recalculate_amounts'], false);
    });
  });
}

AssetManagementInsightReport _report() {
  const planner = AssetLiabilityPlanningService();
  const insight = AssetManagementInsightService();
  final workbook = planner.buildWorkbook(
    latestSnapshot: const <String, double>{'bank': 50000, 'PayPay': -20000},
    baseDate: DateTime(2026, 5, 1),
    monthlyPaymentOverrides: const <String, double>{'paypay_card': 20000},
    paymentSourceAccountIds: const <String, String>{'paypay_card': 'bank'},
  );
  return insight.buildReport(workbook: workbook, minimumSafetyBalance: 10000);
}
