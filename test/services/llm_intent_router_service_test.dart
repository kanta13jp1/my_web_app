import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/llm_intent_router_service.dart';

void main() {
  test('routeIntent parses structured Groq router response within 500ms SLA',
      () async {
    final service = LlmIntentRouterService(
      invoker: (functionName, body) async {
        expect(functionName, LlmIntentRouterService.defaultEdgeFunction);
        expect(body['action'], LlmIntentRouterService.defaultRouterAction);
        expect(body['budgetMs'], 500);
        return {
          'intent': 'deep_reasoning',
          'targetAgent': 'reasoning_specialist',
          'targetHandler': 'claude-sonnet-5',
          'confidence': 0.93,
          'latencyMs': 185,
          'withinSla500ms': true,
          'provider': 'groq',
          'model': 'llama-3.3-70b-versatile',
          'fallbackUsed': false,
          'fallbackReason': null,
          'rationale': 'Requires multi-step trade-off analysis.',
        };
      },
    );

    final result = await service.routeIntent(
      'Compare architectural trade-offs for hybrid LLM routing',
    );

    expect(result.intent, LlmRouterIntent.deepReasoning);
    expect(result.targetAgent, 'reasoning_specialist');
    expect(result.targetHandler, 'claude-sonnet-5');
    expect(result.provider, 'groq');
    expect(result.fallbackUsed, isFalse);
    expect(result.withinSla500ms, isTrue);
    expect(result.latencyMs, 185);
    expect(service.slaStats.totalRequests, 1);
    expect(service.slaStats.withinSla500msCount, 1);
    expect(service.slaStats.fallbackCount, 0);
  });

  test('routeIntent fails open on edge invoker exception and tracks fallback',
      () async {
    final service = LlmIntentRouterService(
      invoker: (_, __) async => throw StateError('network unavailable'),
    );

    final result = await service.routeIntent('今月のレシート支出を記録して');

    expect(result.intent, LlmRouterIntent.financeLedger);
    expect(result.targetAgent, 'finance_analyst');
    expect(result.targetHandler, 'core-hub');
    expect(result.provider, 'deterministic_fallback');
    expect(result.fallbackUsed, isTrue);
    expect(result.fallbackReason, 'edge_invoker_error');
    expect(service.slaStats.fallbackCount, 1);
  });

  test('routeIntent fails open on timeout exceeding budgetMs', () async {
    final service = LlmIntentRouterService(
      invoker: (_, __) async {
        await Future<void>.delayed(const Duration(milliseconds: 120));
        return {'intent': 'quick_qa'};
      },
    );

    final result = await service.routeIntent(
      'Flutterのテストエラーを修正して',
      budgetMs: 50,
    );

    expect(result.intent, LlmRouterIntent.codingDebug);
    expect(result.fallbackUsed, isTrue);
    expect(result.fallbackReason, 'timeout_budget_exceeded');
  });

  test('classifyLocally handles all major intents deterministically', () {
    final service = LlmIntentRouterService();

    expect(
      service.classifyLocally('前回のノートを思い出して').intent,
      LlmRouterIntent.memoryRecall,
    );
    expect(
      service.classifyLocally('来週のWBSタスク計画を立てたい').intent,
      LlmRouterIntent.taskPlanning,
    );
    expect(
      service.classifyLocally('Groqとは何?').intent,
      LlmRouterIntent.quickQa,
    );
    expect(
      service.classifyLocally('こんにちは').intent,
      LlmRouterIntent.generalChat,
    );
  });
}
