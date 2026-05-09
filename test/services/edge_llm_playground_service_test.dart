import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/edge_llm_playground_service.dart';
import 'package:my_web_app/services/local_rag_runtime_service.dart';
import 'package:my_web_app/services/offline_secure_mode_settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('invoke sends edge_llm action with parsed context JSON', () async {
    Map<String, dynamic>? capturedBody;
    final service = EdgeLlmPlaygroundService(
      invoker: (body) async {
        capturedBody = body;
        return <String, dynamic>{
          'success': true,
          'provider': 'google',
          'tier': 'budget',
          'model': 'gemini-2.5-flash',
          'text': '{"status":"ok"}',
          'parsed_json': <String, dynamic>{'status': 'ok'},
          'observability': <String, dynamic>{
            'provider': 'google',
            'latency_ms': 120,
            'trace_id': 'trace-123',
          },
        };
      },
    );

    final response = await service.invoke(
      userPrompt: 'KPI を JSON で返してください',
      systemPrompt: 'JSON だけ返してください',
      provider: 'auto',
      tier: 'budget',
      responseFormat: 'json',
      contextDraft: '{"goal":"習慣化"}',
      sessionId: 'session-1',
    );

    expect(capturedBody?['action'], 'edge_llm.invoke');
    expect(capturedBody?['tier'], 'budget');
    expect(capturedBody?['temperature'], 0);
    expect(capturedBody?['offline_secure_mode'], false);
    expect(capturedBody?['context_data'], <String, dynamic>{'goal': '習慣化'});
    expect(response.provider, 'google');
    expect(response.parsedJson, <String, dynamic>{'status': 'ok'});
    expect(response.observability?.provider, 'google');
  });

  test('invoke keeps plain text context when JSON parse fails', () async {
    Map<String, dynamic>? capturedBody;
    final service = EdgeLlmPlaygroundService(
      invoker: (body) async {
        capturedBody = body;
        return <String, dynamic>{
          'success': true,
          'provider': 'openai',
          'text': '了解しました',
        };
      },
    );

    await service.invoke(
      userPrompt: '要約してください',
      contextDraft: 'これは plain text context です',
    );

    expect(capturedBody?['context_data'], 'これは plain text context です');
    expect(capturedBody?.containsKey('provider'), isFalse);
  });

  test('invoke includes offline secure mode policy payload', () async {
    const offlineSettings = OfflineSecureModeSettingsService();
    await offlineSettings.saveSettings(
      const OfflineSecureModeSettings(
        enabled: true,
        blockExternalApiWhenEnabled: true,
      ),
    );
    Map<String, dynamic>? capturedBody;
    final service = EdgeLlmPlaygroundService(
      offlineSettingsService: offlineSettings,
      invoker: (body) async {
        capturedBody = body;
        return <String, dynamic>{
          'success': true,
          'provider': 'openai',
          'text': 'offline guard metadata attached',
        };
      },
    );

    await service.invoke(userPrompt: 'hello');

    expect(capturedBody?['action'], 'edge_llm.invoke');
    expect(capturedBody?['offline_secure_mode'], true);
    expect(capturedBody?['offline_external_api_blocked'], true);
    expect(capturedBody?['offline_runtime_configured'], false);
  });

  test('invoke routes to local RAG runtime when offline paths are configured',
      () async {
    const offlineSettings = OfflineSecureModeSettingsService();
    await offlineSettings.saveSettings(
      const OfflineSecureModeSettings(
        enabled: true,
        localModelPath: r'C:\models\pleias-rag.gguf',
        localVectorDbPath: r'C:\rag\lancedb',
        inferenceEngine: 'pleias-rag',
        blockExternalApiWhenEnabled: true,
      ),
    );
    var aiHubCalled = false;
    Map<String, dynamic>? localBody;
    final service = EdgeLlmPlaygroundService(
      offlineSettingsService: offlineSettings,
      invoker: (_) async {
        aiHubCalled = true;
        return <String, dynamic>{'success': false};
      },
      localRagRuntimeService: LocalRagRuntimeService(
        invoker: (body) async {
          localBody = body;
          return <String, dynamic>{
            'success': true,
            'text': 'ローカル根拠だけで回答します。',
            'engine': 'pleias-rag',
            'model': 'pleias-rag.gguf',
            'vector_db_path': r'C:\rag\lancedb',
            'offline_only': true,
            'network_blocked': true,
            'citations': <Map<String, dynamic>>[
              <String, dynamic>{
                'source_id': 'doc-1',
                'title': 'policy.md',
                'path': r'C:\rag\lancedb\policy.md',
                'snippet': '外部APIなしで回答する。',
                'score': 0.91,
              },
            ],
          };
        },
      ),
    );

    final response = await service.invoke(
      userPrompt: '社内規程を要約して',
      responseFormat: 'json',
      sessionId: 'session-local',
    );

    expect(aiHubCalled, isFalse);
    expect(localBody?['query'], '社内規程を要約して');
    expect(localBody?['model_path'], r'C:\models\pleias-rag.gguf');
    expect(localBody?['vector_db_path'], r'C:\rag\lancedb');
    expect(localBody?['network_policy'], 'offline_only');
    expect(localBody?['temperature'], 0);
    expect(response.provider, 'local-rag');
    expect(response.tier, 'offline');
    expect(response.parsedJson?['citations'], isA<List>());
    expect(response.citations.single.sourceId, 'doc-1');
    expect(response.source, 'local-rag runtime / pleias-rag');
  });

  test('invoke extracts citations from parsed JSON payloads', () async {
    final service = EdgeLlmPlaygroundService(
      invoker: (_) async {
        return <String, dynamic>{
          'success': true,
          'provider': 'pleias',
          'text': 'Common Corpus [source:1]',
          'parsed_json': <String, dynamic>{
            'citations': <Map<String, dynamic>>[
              <String, dynamic>{
                'source_id': '1',
                'title': 'common-corpus.md',
                'snippet': 'Common Corpus is traceable training data.',
              },
            ],
          },
        };
      },
    );

    final response = await service.invoke(userPrompt: 'Explain citations');

    expect(response.text, 'Common Corpus [source:1]');
    expect(response.citations.single.sourceId, '1');
    expect(response.citations.single.title, 'common-corpus.md');
  });
}
