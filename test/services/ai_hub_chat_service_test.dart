import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/ai_hub_chat_service.dart';
import 'package:my_web_app/services/offline_secure_mode_settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    AiHubChatQuotaGuard.resetForTesting();
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('sendProviderChat returns normalized provider text', () async {
    final service = AiHubChatService(
      invoker: (body) async {
        expect(body['action'], 'provider.chat');
        expect(body['provider'], 'deepinfra');
        expect(body['model'], 'deepinfra/test-model');
        expect(body['max_tokens'], 2048);
        expect(body['message'], 'hello');
        expect(body['provider_choice_reason'], 'asset:summary; test route');
        expect(body['routing_use_case'], 'summary');
        return {
          'success': true,
          'text': 'world',
          'observability': {
            'provider': 'deepinfra',
            'model': 'deepinfra/test-model',
            'latency_ms': 321,
            'trace_id': 'trace-12345678',
            'session_id': 'session-87654321',
            'input_chars': 5,
            'output_chars': 5,
            'status_code': 200,
            'provider_choice_reason': 'asset:summary; test route',
            'routing_use_case': 'summary',
          },
        };
      },
    );

    final response = await service.sendProviderChat(
      message: 'hello',
      model: 'deepinfra/test-model',
      maxTokens: 2048,
      providerChoiceReason: 'asset:summary; test route',
      routingUseCase: 'summary',
    );

    expect(response.text, 'world');
    expect(response.source, 'ai-hub provider.chat / deepinfra');
    expect(response.observability?.provider, 'deepinfra');
    expect(response.observability?.model, 'deepinfra/test-model');
    expect(response.observability?.latencyMs, 321);
    expect(response.observability?.shortTraceId, 'trace-12');
    expect(
      response.observability?.providerChoiceReason,
      'asset:summary; test route',
    );
    expect(response.observability?.routingUseCase, 'summary');
  });

  test('sendProviderChat throws when provider response is empty', () async {
    final service = AiHubChatService(
      invoker: (_) async => {'success': false, 'message': ''},
    );

    expect(
      () => service.sendProviderChat(message: 'hello'),
      throwsA(isA<AiHubChatException>()),
    );
  });

  test('sendAutoChat surfaces paid provider errors from ai-hub', () async {
    final service = AiHubChatService(
      invoker: (_) async => {
        'success': false,
        'status': 'paidPlanRequired',
        'provider': 'deepinfra',
        'message': 'DeepInfra needs positive balance',
        'detail': 'You need positive balance to do inference.',
      },
    );

    expect(
      () => service.sendAutoChat(message: 'hello'),
      throwsA(
        isA<AiHubChatException>()
            .having((e) => e.message, 'message', contains('paidPlanRequired'))
            .having((e) => e.message, 'provider', contains('deepinfra'))
            .having((e) => e.message, 'detail', contains('positive balance')),
      ),
    );
  });

  test('sendAutoChat returns auto-routed provider metadata', () async {
    final service = AiHubChatService(
      invoker: (body) async {
        expect(body['action'], 'provider.chat_auto');
        expect(body['message'], 'hello');
        expect(body['session_id'], 'session-123');
        expect(body['max_tokens'], 3072);
        expect(body['provider_choice_reason'], 'asset:summary; auto route');
        expect(body['routing_use_case'], 'summary');
        return {
          'success': true,
          'text': 'auto-world',
          'provider': 'groq',
          'observability': {
            'provider': 'groq',
            'latency_ms': 210,
            'trace_id': 'trace-87654321',
          },
        };
      },
    );

    final response = await service.sendAutoChat(
      message: 'hello',
      maxTokens: 3072,
      sessionId: 'session-123',
      providerChoiceReason: 'asset:summary; auto route',
      routingUseCase: 'summary',
    );

    expect(response.text, 'auto-world');
    expect(response.source, 'ai-hub provider.chat_auto / groq');
    expect(response.observability?.provider, 'groq');
    expect(response.observability?.latencyMs, 210);
  });

  test('sendProviderChat includes offline secure mode policy', () async {
    const offlineSettings = OfflineSecureModeSettingsService();
    await offlineSettings.saveSettings(
      const OfflineSecureModeSettings(
        enabled: true,
        localModelPath: r'C:\models\pleias-rag.gguf',
        localVectorDbPath: r'C:\rag\lancedb',
        blockExternalApiWhenEnabled: true,
      ),
    );

    final service = AiHubChatService(
      offlineSettingsService: offlineSettings,
      invoker: (body) async {
        expect(body['action'], 'provider.chat');
        expect(body['offline_secure_mode'], true);
        expect(body['offline_external_api_blocked'], true);
        expect(body['offline_runtime_configured'], true);
        return {
          'success': true,
          'text': 'blocked before provider fetch in ai-hub',
        };
      },
    );

    final response = await service.sendProviderChat(message: 'hello');

    expect(response.text, 'blocked before provider fetch in ai-hub');
  });

  test('verifyAnnualRateEvidence calls ai-hub vision verifier', () async {
    final service = AiHubChatService(
      invoker: (body) async {
        expect(body['action'], 'asset_liability.verify_annual_rate_evidence');
        expect(body['accountName'], 'Mobit');
        expect(body['submittedAnnualRate'], 0.18);
        expect(body['imageBase64'], 'abc123');
        expect(body['mimeType'], 'image/png');
        expect(body['imageName'], 'apr.png');
        return <String, dynamic>{
          'success': true,
          'verified': true,
          'status': 'verified',
          'detected_annual_rate': 0.18,
          'summary': '18.0% APR is visible.',
        };
      },
    );

    final response = await service.verifyAnnualRateEvidence(
      accountName: 'Mobit',
      submittedAnnualRate: 0.18,
      imageBase64: 'abc123',
      mimeType: 'image/png',
      imageName: 'apr.png',
    );

    expect(response.verified, isTrue);
    expect(response.detectedAnnualRate, 0.18);
    expect(response.summary, contains('18.0%'));
  });
}
