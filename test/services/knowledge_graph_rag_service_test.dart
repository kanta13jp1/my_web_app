import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/knowledge_graph_rag_service.dart';

void main() {
  test('requests RAG answer and parses bounded citation evidence', () async {
    late Map<String, dynamic> request;
    final service = KnowledgeGraphRagService(
      invoker: (body) async {
        request = Map<String, dynamic>.from(body);
        return <String, dynamic>{
          'success': true,
          'query': body['query'],
          'answer': '根拠があります [1]。',
          'answer_status': 'ok',
          'trace_id': 'trace-1',
          'citations': <Map<String, dynamic>>[
            <String, dynamic>{
              'citation_id': '1',
              'file_name': 'roadmap.md',
              'title': 'Roadmap',
              'source_type': 'doc',
              'source_url': 'docs/roadmap.md',
              'excerpt': '根拠があります。',
              'preview_text': '根拠があります。',
              'highlight_start': 0,
              'highlight_end': 9,
              'position': <String, dynamic>{'label': 'line 12'},
              'confidence': 0.9,
            },
          ],
        };
      },
    );

    final answer = await service.query(
      query: ' 根拠は？ ',
      sources: <String>{'memory', 'docs'},
      useLlm: true,
    );

    expect(request, <String, dynamic>{
      'action': 'memory.rag.query',
      'query': '根拠は？',
      'top_k': 8,
      'sources': <String>['docs', 'memory'],
      'use_llm': true,
    });
    expect(answer.answer, contains('[1]'));
    expect(answer.citations.single.fileName, 'roadmap.md');
    expect(answer.citations.single.position.label, 'line 12');
  });

  test('rejects an overlong question before invoking the backend', () async {
    var invoked = false;
    final service = KnowledgeGraphRagService(
      invoker: (_) async {
        invoked = true;
        return <String, dynamic>{};
      },
    );

    await expectLater(
      service.query(
        query: List<String>.filled(1001, 'a').join(),
        sources: <String>{'docs'},
        useLlm: true,
      ),
      throwsA(
        isA<KnowledgeGraphRagException>().having(
          (error) => error.message,
          'message',
          contains('1,000'),
        ),
      ),
    );
    expect(invoked, isFalse);
  });
}
