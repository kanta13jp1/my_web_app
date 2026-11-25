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
          'memory_limit_mb': 8192,
          'memory_guard_passed': true,
          'citations': <Map<String, Object?>>[
            <String, Object?>{
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
    expect(capturedBody?['temperature'], 0);
    expect(capturedBody?['memory_limit_mb'], 8192);
    expect(capturedBody?['model_path'], r'C:\models\pleias-rag.gguf');
    expect(response.text, contains('外部ネットワークなし'));
    expect(response.citations.single.sourceId, 'doc-1');
    expect(response.networkBlocked, isTrue);
    expect(response.memoryPeakMb, 256);
    expect(response.memoryLimitMb, 8192);
    expect(response.memoryGuardPassed, isTrue);
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

  test('parsePleiasCitationText removes native source span tokens', () {
    final parsed = parsePleiasCitationText(
      'Answer <|source_start|>doc-1<|source_end|>quoted fact<|/source|> done',
    );

    expect(parsed.hasCitationTokens, isTrue);
    expect(parsed.plainText, 'Answer quoted fact done');
    expect(parsed.sourceIds, <String>['doc-1']);
    expect(parsed.segments.where((segment) => segment.cited), hasLength(1));
    expect(parsed.segments[1].text, 'quoted fact');
  });

  test('parsePleiasCitationText supports Pleias bracket source markers', () {
    final parsed = parsePleiasCitationText(
      'Pleias created Common Corpus [source:1] for traceable RAG.',
    );

    expect(parsed.hasCitationTokens, isTrue);
    expect(
      parsed.plainText,
      'Pleias created Common Corpus [source:1] for traceable RAG.',
    );
    expect(parsed.sourceIds, <String>['1']);
    expect(
      parsed.segments.where((segment) => segment.markerOnly),
      hasLength(1),
    );
  });

  test(
      'parsePleiasCitationText handles <|answer_start|>, <|citation_start|>, <ref>, and [N]',
      () {
    final parsed = parsePleiasCitationText(
      '<|thought_start|>draft<|thought_end|>'
      '<|answer_start|>Budget is <ref id="1">100k JPY</ref> '
      'with <|citation_start|>2<|citation_end|>CFO sign-off<|/citation|> [3].'
      '<|answer_end|>',
    );

    expect(parsed.hasCitationTokens, isTrue);
    expect(
      parsed.plainText,
      'Budget is 100k JPY with CFO sign-off [3].',
    );
    expect(parsed.sourceIds, <String>['1', '2', '3']);
  });

  test(
      'LocalRagCitation and PleiasCitationParseResult consume Supabase RAG JSON',
      () {
    final response = LocalRagRuntimeResponse.fromMap(<String, Object?>{
      'answer': '上限は10万円です [1]。',
      'parsed_answer': <String, Object?>{
        'plain_text': '上限は10万円です [1]。',
        'has_native_tokens': true,
        'reference_ids': <String>['1'],
        'segments': <Map<String, Object?>>[
          <String, Object?>{'text': '上限は10万円です '},
          <String, Object?>{
            'text': '10万円',
            'reference_id': '1',
            'marker_only': false,
          },
        ],
      },
      'citations': <Map<String, Object?>>[
        <String, Object?>{
          'citation_id': '1',
          'file_name': 'budget.md',
          'title': 'Budget Guide',
          'source_url': 'docs/budget.md',
          'highlight_text': '月額上限は10万円です。',
          'excerpt': '月額上限は10万円です。',
          'confidence': 0.95,
          'position': <String, Object?>{'label': 'line 12'},
        },
      ],
    });

    expect(response.citations.single.sourceId, '1');
    expect(response.citations.single.title, 'Budget Guide');
    expect(response.citations.single.path, 'docs/budget.md');
    expect(response.citations.single.snippet, '月額上限は10万円です。');
    expect(response.citations.single.locationLabel, 'line 12');
    expect(response.citations.single.score, 0.95);
    expect(response.citationText.hasCitationTokens, isTrue);
    expect(response.citationText.sourceIds, <String>['1']);
    expect(response.citationText.segments[1].text, '10万円');
  });
}
