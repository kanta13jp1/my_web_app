import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/knowledge_graph_rag.dart';

void main() {
  test('parses independent citations with source positions and highlights', () {
    final answer = KnowledgeGraphRagAnswer.fromJson(<String, dynamic>{
      'query': '優先事項は？',
      'answer': '最優先は公開準備です [1]。予算上限は10万円です [2]。',
      'answer_status': 'ok',
      'trace_id': 'trace-1',
      'citations': <Map<String, dynamic>>[
        <String, dynamic>{
          'citation_id': '1',
          'file_name': 'roadmap.md',
          'title': 'Roadmap',
          'source_type': 'doc',
          'source_url': 'docs/roadmap.md',
          'excerpt': '最優先は公開準備です。',
          'preview_text': '背景\n最優先は公開準備です。\n詳細',
          'highlight_start': 3,
          'highlight_end': 14,
          'highlight_text': '最優先は公開準備です。',
          'position': <String, dynamic>{
            'start_line': 2,
            'end_line': 2,
            'label': 'line 2',
          },
          'confidence': 0.96,
        },
        <String, dynamic>{
          'citation_id': '2',
          'file_name': 'budget.pdf',
          'title': 'Budget policy',
          'source_type': 'doc',
          'source_url': 'https://example.com/budget.pdf',
          'excerpt': '予算上限は10万円です。',
          'preview_text': '予算上限は10万円です。',
          'highlight_start': 0,
          'highlight_end': 11,
          'position': <String, dynamic>{
            'page_number': 4,
            'section': '申請上限',
            'start_line': 30,
            'end_line': 30,
            'label': 'page 4 · 申請上限 · line 30',
          },
          'confidence': 0.81,
        },
      ],
    });

    expect(answer.citations, hasLength(2));
    expect(answer.citationById('1')?.fileName, 'roadmap.md');
    expect(answer.citationById('2')?.position.pageNumber, 4);
    expect(answer.citationById('2')?.position.label, contains('申請上限'));
    expect(answer.citationById('9'), isNull);

    final segments = parseKnowledgeGraphAnswer(answer.answer);
    expect(
      segments
          .where((segment) => segment.isCitation)
          .map((segment) => segment.citationId),
      <String?>['1', '2'],
    );
  });

  test('clamps malformed highlight offsets to the bounded preview', () {
    final citation = KnowledgeGraphRagCitation.fromJson(
      <String, dynamic>{
        'file_name': 'safe.txt',
        'preview_text': 'bounded preview',
        'highlight_start': -50,
        'highlight_end': 500,
        'position': <String, dynamic>{},
      },
      fallbackIndex: 1,
    );

    expect(citation.highlightStart, 0);
    expect(citation.highlightEnd, citation.previewText.length);
    expect(citation.highlightText, 'bounded preview');
  });
}
