import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/ai_hub_chat_service.dart';
import 'package:my_web_app/services/asset_chat_privacy_settings_service.dart';
import 'package:my_web_app/services/offline_secure_mode_settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    AiHubChatQuotaGuard.resetForTesting();
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('sendAssetChat maps the backend thread and usage contract', () async {
    final service = AiHubChatService(
      invoker: (body) async {
        expect(body['action'], 'ai_hub.asset_chat');
        expect(body['message'], '今月の支払いを確認して');
        expect(body['thread_id'], '11111111-1111-4111-8111-111111111111');
        expect(body['snapshot_months'], 3);
        expect(body['history_messages'], 8);
        expect(body['pii_mode'], 'off');
        return <String, dynamic>{
          'success': true,
          'thread_id': '11111111-1111-4111-8111-111111111111',
          'thread_title': '今月の支払い',
          'thread_created': false,
          'reply': '未払い予定を先に確認してください。',
          'provider': 'google',
          'model': 'gemini-2.5-flash',
          'tokens_in': 123,
          'tokens_out': 45,
          'estimated_cost_usd': 0.000321,
        };
      },
    );

    final response = await service.sendAssetChat(
      message: '  今月の支払いを確認して  ',
      threadId: '11111111-1111-4111-8111-111111111111',
    );

    expect(response.threadId, '11111111-1111-4111-8111-111111111111');
    expect(response.threadTitle, '今月の支払い');
    expect(response.threadCreated, isFalse);
    expect(response.reply, '未払い予定を先に確認してください。');
    expect(response.usage.tokensIn, 123);
    expect(response.usage.tokensOut, 45);
    expect(response.usage.totalTokens, 168);
    expect(response.usage.estimatedCostUsd, 0.000321);
    expect(response.usage.provider, 'google');
    expect(response.usage.model, 'gemini-2.5-flash');
  });

  test('sendAssetChat reads persisted opt-in at the send boundary', () async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(
      AssetChatPrivacySettingsService.maskMoneyAmountsKey,
      true,
    );
    final service = AiHubChatService(
      invoker: (body) async {
        expect(body['pii_mode'], 'mask');
        return <String, dynamic>{
          'success': true,
          'thread_id': '11111111-1111-4111-8111-111111111111',
          'thread_title': 'プライバシー相談',
          'thread_created': true,
          'reply': '金額レンジで確認しました。',
        };
      },
    );

    final response = await service.sendAssetChat(message: '残高を確認して');

    expect(response.reply, '金額レンジで確認しました。');
  });

  test('sendAssetChat explicit mode overrides persisted preference', () async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(
      AssetChatPrivacySettingsService.maskMoneyAmountsKey,
      true,
    );
    final service = AiHubChatService(
      invoker: (body) async {
        expect(body['pii_mode'], 'off');
        return <String, dynamic>{
          'success': true,
          'thread_id': '11111111-1111-4111-8111-111111111111',
          'thread_title': '明示設定',
          'thread_created': true,
          'reply': '確認しました。',
        };
      },
    );

    await service.sendAssetChat(message: '確認して', piiMode: 'off');
  });

  test('sendAssetChat rejects an incomplete successful response', () async {
    final service = AiHubChatService(
      invoker: (_) async => <String, dynamic>{
        'success': true,
        'thread_id': '11111111-1111-4111-8111-111111111111',
        'reply': '',
      },
    );

    await expectLater(
      () => service.sendAssetChat(message: 'hello'),
      throwsA(
        isA<AiHubChatException>().having(
          (error) => error.message,
          'message',
          contains('Asset chat response was empty'),
        ),
      ),
    );
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

  test('quota cooldown is per-provider and does not block other providers',
      () async {
    final service = AiHubChatService(
      invoker: (body) async {
        if (body['provider'] == 'openai') {
          return <String, dynamic>{
            'success': false,
            'status': 'paidPlanRequired',
            'provider': 'openai',
            'message': 'OpenAI quota',
            'detail': 'You exceeded your current quota',
          };
        }
        return <String, dynamic>{
          'success': true,
          'text': 'gemini ok',
          'provider': 'google',
        };
      },
    );

    // OpenAI のクォータ超過は OpenAI のみクールダウンさせる。
    await expectLater(
      () => service.sendProviderChat(message: 'hi', provider: 'openai'),
      throwsA(isA<AiHubChatException>()),
    );
    expect(AiHubChatQuotaGuard.isCoolingDown('openai'), isTrue);
    expect(AiHubChatQuotaGuard.isCoolingDown('google'), isFalse);

    // Gemini は別プロバイダなのでブロックされず成功する。
    final response = await service.sendProviderChat(
      message: 'hi',
      provider: 'google',
    );
    expect(response.text, 'gemini ok');
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
