import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/offline_secure_mode_settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('loads safe defaults with online fallback allowed', () async {
    const service = OfflineSecureModeSettingsService();

    final settings = await service.loadSettings();

    expect(settings.enabled, isFalse);
    expect(settings.inferenceEngine, 'pleias-rag');
    expect(settings.localRuntimeConfigured, isFalse);
    expect(settings.externalApiBlocked, isFalse);
    expect(settings.onlineFallbackAllowed, isTrue);
    expect(
      settings.toAiHubPolicyPayload(),
      containsPair('offline_secure_mode', false),
    );
  });

  test('persists offline runtime paths and external API policy', () async {
    const service = OfflineSecureModeSettingsService();

    final saved = await service.saveSettings(
      const OfflineSecureModeSettings(
        enabled: true,
        localModelPath: r' C:\models\pleias-rag.gguf ',
        localVectorDbPath: r' C:\rag\lancedb ',
        inferenceEngine: 'ollama',
        localRuntimeUrl: ' http://127.0.0.1:8765/rag ',
        blockExternalApiWhenEnabled: true,
      ),
    );
    final loaded = await service.loadSettings();

    expect(saved.localModelPath, r'C:\models\pleias-rag.gguf');
    expect(loaded.localVectorDbPath, r'C:\rag\lancedb');
    expect(loaded.inferenceEngine, 'ollama');
    expect(loaded.localRuntimeUrl, 'http://127.0.0.1:8765/rag');
    expect(loaded.localRuntimeConfigured, isTrue);
    expect(loaded.externalApiBlocked, isTrue);
    expect(
      loaded.toAiHubPolicyPayload(),
      containsPair('offline_external_api_blocked', true),
    );
    expect(
      loaded.toAiHubPolicyPayload(),
      containsPair('offline_local_runtime_url', 'http://127.0.0.1:8765/rag'),
    );
  });

  test('normalizes unsupported inference engine to Pleias RAG', () async {
    const service = OfflineSecureModeSettingsService();

    await service.saveSettings(
      const OfflineSecureModeSettings(inferenceEngine: 'remote-only'),
    );

    final loaded = await service.loadSettings();
    expect(loaded.inferenceEngine, 'pleias-rag');
  });
}
