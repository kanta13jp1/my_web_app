import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/ai_hub_chat_service.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';
import 'package:my_web_app/services/asset_management_ai_provider_router.dart';
import 'package:my_web_app/services/asset_management_ai_summary_service.dart';
import 'package:my_web_app/services/asset_management_insight_service.dart';

void main() {
  group('AssetManagementAiSummaryService', () {
    setUp(AiHubChatQuotaGuard.resetForTesting);

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
        result.text.contains('Dart rules'),
        true,
      );
    });

    test('calls ai-hub auto chat when feature flag is on', () async {
      Map<String, dynamic>? capturedBody;
      final service = AssetManagementAiSummaryService(
        aiEnabled: true,
        chatService: AiHubChatService(
          invoker: (body) async {
            capturedBody = body;
            return <String, dynamic>{
              'success': true,
              'text': 'AI generated summary',
              'provider': 'groq',
            };
          },
        ),
        now: () => DateTime(2026, 5, 1, 12),
      );

      final result = await service.generateSummary(report: _report());

      expect(result.status, AssetManagementAiSummaryStatus.aiGenerated);
      expect(result.usedExternalAi, true);
      expect(result.text, 'AI generated summary');
      expect(capturedBody?['action'], 'provider.chat_auto');
      expect(capturedBody?['tier'], 'performance');
      expect(capturedBody?['trace_id'], 'asset-management-ai-summary');
      expect(
        capturedBody?['message'].toString().contains(
              'Redacted computed insight payload',
            ),
        true,
      );
      expect(
        capturedBody?['message'].toString().contains(
              '"external_ai_may_recalculate_amounts":false',
            ),
        true,
      );
      expect(capturedBody?['message'].toString().contains('50,000'), false);
      expect(capturedBody?['message'].toString().contains('50000'), false);
      expect(capturedBody?['provider_choice_reason'], contains('summary'));
      expect(capturedBody?['routing_use_case'], 'summary');
    });

    test('routes through configured provider chain when routing is enabled',
        () async {
      final calls = <Map<String, dynamic>>[];
      final service = AssetManagementAiSummaryService(
        aiEnabled: true,
        providerRouter: const AssetManagementAiProviderRouter(
          routingEnabled: true,
        ),
        chatService: AiHubChatService(
          invoker: (body) async {
            calls.add(Map<String, dynamic>.from(body));
            return <String, dynamic>{
              'success': true,
              'text': 'Claude routed summary',
              'observability': <String, dynamic>{
                'provider': body['provider'],
                'model': body['model'],
              },
            };
          },
        ),
        now: () => DateTime(2026, 5, 1, 12),
      );

      final result = await service.generateSummary(report: _report());

      expect(result.status, AssetManagementAiSummaryStatus.aiGenerated);
      expect(result.text, 'Claude routed summary');
      expect(calls, hasLength(1));
      expect(calls.single['action'], 'provider.chat');
      expect(calls.single['provider'], 'anthropic');
      expect(calls.single['model'], 'claude-opus-4-7');
      expect(calls.single['routing_use_case'], 'summary');
      expect(
        calls.single['provider_choice_reason'],
        contains('claude-opus-4-7@anthropic'),
      );
      expect(result.providerRoute?['routing_enabled'], true);
    });

    test('provider routing falls back across providers before local summary',
        () async {
      final providers = <String>[];
      final service = AssetManagementAiSummaryService(
        aiEnabled: true,
        providerRouter: const AssetManagementAiProviderRouter(
          routingEnabled: true,
        ),
        chatService: AiHubChatService(
          invoker: (body) async {
            providers.add(body['provider'] as String);
            if (body['provider'] == 'anthropic') {
              throw const AiHubChatException('temporary outage');
            }
            return <String, dynamic>{
              'success': true,
              'text': 'GPT fallback summary',
              'provider': body['provider'],
            };
          },
        ),
        now: () => DateTime(2026, 5, 1, 12),
      );

      final result = await service.generateSummary(report: _report());

      expect(result.status, AssetManagementAiSummaryStatus.aiGenerated);
      expect(result.text, 'GPT fallback summary');
      expect(providers, <String>['anthropic', 'openai']);
    });

    test('ai-safe payload keeps exact money values out of external AI context',
        () {
      final service = AssetManagementAiSummaryService(
        now: () => DateTime(2026, 5, 1, 12),
      );

      final payload = service.buildAiSafePayload(_report());
      final encoded = payload.toString();

      expect(encoded.contains('50000'), false);
      expect(encoded.contains('20000'), false);
      expect(encoded.contains('available_money_bands'), true);
      expect(
        encoded.contains('external_ai_payload_redacts_exact_money_values'),
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
        result.text.contains('Dart rules'),
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
      final emergencyAdvices = payload['emergency_advices'] as List<dynamic>;

      expect(payload.containsKey('workbook'), false);
      expect(today['available_amount'], report.todayAvailable.availableAmount);
      expect(payload['action_items'] is List<dynamic>, true);
      expect(payload['movement_suggestions'] is List<dynamic>, true);
      expect(emergencyAdvices.length, report.emergencyAdvices.length);
      expect(payload['developer_requests'] is List<dynamic>, true);
      expect(guardrails['calculation_owner'], 'dart_service');
      expect(guardrails['external_ai_may_summarize_only'], true);
      expect(guardrails['external_ai_may_recalculate_amounts'], false);
      expect(guardrails['must_not_recommend_starvation_or_water_only'], true);
    });

    test(
      'waiting result keeps deterministic text before external AI returns',
      () {
        final service = AssetManagementAiSummaryService(
          now: () => DateTime(2026, 5, 1, 12),
        );

        final result = service.buildWaitingForAiResult(_report());

        expect(result.status, AssetManagementAiSummaryStatus.fallback);
        expect(result.usedExternalAi, false);
        expect(result.source, 'deterministic fallback / waiting for ai-hub');
        expect(
          result.text.contains('Dart rules'),
          true,
        );
      },
    );

    test('deterministic fallback gives concrete emergency living advice', () {
      final report = _emergencyReport();
      final service = AssetManagementAiSummaryService(
        now: () => DateTime(2026, 5, 28, 12),
      );

      final text = service.buildDeterministicSummary(report);
      final payload = service.buildPayload(report);

      expect(text.contains('今日の食費'), true);
      expect(text.contains('支払い'), true);
      expect(text.contains('Dart rules'), true);
      expect(payload['emergency_advices'] is List<dynamic>, true);
      expect((payload['emergency_advices'] as List<dynamic>).isNotEmpty, true);
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

AssetManagementInsightReport _emergencyReport() {
  const planner = AssetLiabilityPlanningService();
  const insight = AssetManagementInsightService();
  final workbook = planner.buildWorkbook(
    latestSnapshot: const <String, double>{'bank': 50000, 'PayPay': -200000},
    baseDate: DateTime(2026, 5, 28),
    monthlyPaymentOverrides: const <String, double>{'paypay_card': 200000},
    paymentSourceAccountIds: const <String, String>{'paypay_card': 'bank'},
  );
  return insight.buildReport(workbook: workbook, minimumSafetyBalance: 10000);
}
