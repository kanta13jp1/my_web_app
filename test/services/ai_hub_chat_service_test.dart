import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/ai_hub_chat_service.dart';
import 'package:my_web_app/services/offline_secure_mode_settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('sendProviderChat returns normalized provider text', () async {
    final service = AiHubChatService(
      invoker: (body) async {
        expect(body['action'], 'provider.chat');
        expect(body['provider'], 'deepinfra');
        expect(body['message'], 'hello');
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
          },
        };
      },
    );

    final response = await service.sendProviderChat(message: 'hello');

    expect(response.text, 'world');
    expect(response.source, 'ai-hub provider.chat / deepinfra');
    expect(response.observability?.provider, 'deepinfra');
    expect(response.observability?.model, 'deepinfra/test-model');
    expect(response.observability?.latencyMs, 321);
    expect(response.observability?.shortTraceId, 'trace-12');
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

  test('sendAutoChat returns auto-routed provider metadata', () async {
    final service = AiHubChatService(
      invoker: (body) async {
        expect(body['action'], 'provider.chat_auto');
        expect(body['message'], 'hello');
        expect(body['session_id'], 'session-123');
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
      sessionId: 'session-123',
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
}
