import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/knowledge_graph_rag.dart';

void main() {
  test('parses independent citations with source positions and highlights', () {
    final answer = KnowledgeGraphRagAnswer.fromJson(<String, Object?>{
      'query': '優先事項は？',
      'answer': '最優先は公開準備です [1]。予算上限は10万円です [2]。',
      'answer_status': 'ok',
      'trace_id': 'trace-1',
      'citations': <Map<String, Object?>>[
        <String, Object?>{
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
          'position': <String, Object?>{
            'start_line': 2,
            'end_line': 2,
            'label': 'line 2',
          },
          'confidence': 0.96,
        },
        <String, Object?>{
          'citation_id': '2',
          'file_name': 'budget.pdf',
          'title': 'Budget policy',
          'source_type': 'doc',
          'source_url': 'https://example.com/budget.pdf',
          'excerpt': '予算上限は10万円です。',
          'preview_text': '予算上限は10万円です。',
          'highlight_start': 0,
          'highlight_end': 11,
          'position': <String, Object?>{
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
      <String, Object?>{
        'file_name': 'safe.txt',
        'preview_text': 'bounded preview',
        'highlight_start': -50,
        'highlight_end': 500,
        'position': <String, Object?>{},
      },
      fallbackIndex: 1,
    );

    expect(citation.highlightStart, 0);
    expect(citation.highlightEnd, citation.previewText.length);
    expect(citation.highlightText, 'bounded preview');
  });

  test('consumes backend parsed_answer and temperature_used cleanly', () {
    final answer = KnowledgeGraphRagAnswer.fromJson(<String, Object?>{
      'query': '承認期限は？',
      'answer': '承認期限は3営業日です [1]。',
      'answer_status': 'ok',
      'trace_id': 'trace-parsed',
      'temperature_used': 0,
      'parsed_answer': <String, Object?>{
        'plain_text': '承認期限は3営業日です [1]。',
        'has_native_tokens': true,
        'reference_ids': <String>['1'],
        'segments': <Map<String, Object?>>[
          <String, Object?>{'text': '承認期限は'},
          <String, Object?>{
            'text': '3営業日',
            'reference_id': '1',
            'marker_only': false,
          },
          <String, Object?>{
            'text': '[1]',
            'reference_id': '1',
            'marker_only': true,
          },
        ],
      },
      'citations': const <Map<String, Object?>>[],
    });

    expect(answer.temperatureUsed, 0);
    expect(answer.parsedSegments, hasLength(3));
    expect(answer.parsedSegments[1].citationId, '1');
    expect(answer.parsedSegments[1].markerOnly, isFalse);
    expect(answer.parsedSegments[2].markerOnly, isTrue);

    final nativeFallback = parseKnowledgeGraphAnswer(
      '<|answer_start|>上限は<ref id="1">10万円</ref>です。<|answer_end|>',
    );
    expect(nativeFallback.any((s) => s.citationId == '1'), isTrue);
    expect(nativeFallback.map((s) => s.text).join(), '上限は10万円です。');
  });
}
