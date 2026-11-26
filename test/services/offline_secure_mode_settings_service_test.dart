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

  test('clamps and persists 8GB RAM limit and calls Supabase audit gateway',
      () async {
    const service = OfflineSecureModeSettingsService();
    final saved = await service.saveSettings(
      const OfflineSecureModeSettings(
        enabled: true,
        memoryLimitMb: 16384,
      ),
    );
    expect(saved.memoryLimitMb, 8192);
    expect(
      saved.toAiHubPolicyPayload(),
      containsPair('offline_memory_limit_mb', 8192),
    );

    final calls = <Map<String, Object?>>[];
    final gateway = SupabaseOfflineSecureModeAuditGateway(
      invoker: (body) async {
        calls.add(body);
        if (body['action'] == 'offline_secure_mode.audit_list') {
          return <String, Object?>{
            'success': true,
            'logs': <Map<String, Object?>>[
              <String, Object?>{
                'id': 'audit-1',
                'action': 'settings.update',
                'provider': 'pleias-rag',
                'status': 'external_api_blocked',
                'secure_mode_enabled': true,
                'external_api_blocked': true,
                'memory_limit_mb': 8192,
                'local_runtime_configured': false,
                'recorded_at': '2026-11-25T14:00:00Z',
              },
            ],
          };
        }
        return <String, Object?>{'success': true, 'recorded': true};
      },
    );

    final recorded = await gateway.recordPolicyEvent(
      settings: saved,
      auditAction: 'settings.update',
      status: 'external_api_blocked',
    );
    expect(recorded, isTrue);
    expect(calls.single['offline_memory_limit_mb'], 8192);

    final logs = await gateway.listRecent();
    expect(logs, hasLength(1));
    expect(logs.single.status, 'external_api_blocked');
    expect(logs.single.memoryLimitMb, 8192);
  });
}
