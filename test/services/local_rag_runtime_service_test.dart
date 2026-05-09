import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/local_rag_runtime_service.dart';
import 'package:my_web_app/services/offline_secure_mode_settings_service.dart';

void main() {
  test('query returns cited local RAG response', () async {
    Map<String, dynamic>? capturedBody;
    final service = LocalRagRuntimeService(
      invoker: (body) async {
        capturedBody = body;
        return <String, dynamic>{
          'success': true,
          'text': '外部ネットワークなしで回答します。',
          'engine': 'pleias-rag',
          'model': 'pleias-rag.gguf',
          'vector_db_path': r'C:\rag\lancedb',
          'offline_only': true,
          'network_blocked': true,
          'memory_peak_mb': 256,
          'citations': <Map<String, dynamic>>[
            <String, dynamic>{
              'source_id': 'doc-1',
              'title': 'manual.md',
              'path': r'C:\rag\lancedb\manual.md',
              'snippet': 'ローカル検索根拠',
              'score': 0.87,
            },
          ],
        };
      },
    );

    final response = await service.query(
      query: 'ローカルRAGの根拠は？',
      settings: const OfflineSecureModeSettings(
        enabled: true,
        localModelPath: r'C:\models\pleias-rag.gguf',
        localVectorDbPath: r'C:\rag\lancedb',
      ),
      systemPrompt: '引用を返す',
      sessionId: 'session-1',
    );

    expect(capturedBody?['offline_only'], true);
    expect(capturedBody?['network_policy'], 'offline_only');
    expect(capturedBody?['model_path'], r'C:\models\pleias-rag.gguf');
    expect(response.text, contains('外部ネットワークなし'));
    expect(response.citations.single.sourceId, 'doc-1');
    expect(response.networkBlocked, isTrue);
    expect(response.memoryPeakMb, 256);
  });

  test('query fails safely when local paths are not configured', () async {
    const service = LocalRagRuntimeService();

    expect(
      () => service.query(
        query: 'hello',
        settings: const OfflineSecureModeSettings(enabled: true),
      ),
      throwsA(isA<LocalRagRuntimeException>()),
    );
  });
}
