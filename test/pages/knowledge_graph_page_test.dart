import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/knowledge_graph_rag.dart';
import 'package:my_web_app/pages/knowledge_graph_page.dart';
import 'package:my_web_app/services/knowledge_graph_rag_service.dart';

void main() {
  testWidgets('opens each inline citation in an in-page highlighted viewer', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final gateway = _FakeGateway();

    await tester.pumpWidget(
      MaterialApp(home: KnowledgeGraphPage(gateway: gateway)),
    );
    await tester.enterText(
      find.byKey(const Key('knowledge-query-field')),
      '今四半期の優先事項は？',
    );
    await tester.tap(find.byKey(const Key('knowledge-query-button')));
    await tester.pumpAndSettle();

    expect(gateway.lastQuery, '今四半期の優先事項は？');
    expect(find.byKey(const Key('knowledge-citation-link-1')), findsOneWidget);
    expect(find.byKey(const Key('knowledge-citation-link-2')), findsOneWidget);
    expect(find.textContaining('roadmap.md'), findsWidgets);
    expect(find.textContaining('budget.pdf'), findsWidgets);

    await tester.tap(find.byKey(const Key('knowledge-citation-link-2')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('knowledge-citation-dialog-2')),
      findsOneWidget,
    );
    expect(find.text('budget.pdf'), findsWidgets);
    expect(find.text('page 4 · 申請上限 · line 30'), findsWidgets);

    final preview = tester.widget<Text>(
      find.byKey(const Key('knowledge-citation-preview-2')),
    );
    final spans =
        (preview.textSpan! as TextSpan).children!.whereType<TextSpan>();
    expect(
      spans.any(
        (span) =>
            span.text == '予算上限は10万円です。' && span.style?.backgroundColor != null,
      ),
      isTrue,
    );
  });

  testWidgets(
    'stacks answer and sources on a narrow viewport without overflow',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(home: KnowledgeGraphPage(gateway: _FakeGateway())),
      );
      await tester.enterText(
        find.byKey(const Key('knowledge-query-field')),
        '優先事項は？',
      );
      await tester.ensureVisible(
        find.byKey(const Key('knowledge-query-button')),
      );
      await tester.tap(find.byKey(const Key('knowledge-query-button')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('knowledge-mobile-result-list')),
        findsOneWidget,
      );
      expect(find.text('根拠付きAI回答'), findsOneWidget);
      expect(find.text('参照元 2件'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _FakeGateway implements KnowledgeGraphRagGateway {
  String? lastQuery;

  @override
  Future<KnowledgeGraphRagAnswer> query({
    required String query,
    required Set<String> sources,
    required bool useLlm,
  }) async {
    lastQuery = query;
    return _answer;
  }
}

const _answer = KnowledgeGraphRagAnswer(
  query: '優先事項は？',
  answer: '最優先は公開準備です [1]。予算上限は10万円です [2]。',
  status: 'ok',
  traceId: 'trace-1252',
  citations: <KnowledgeGraphRagCitation>[
    KnowledgeGraphRagCitation(
      id: '1',
      fileName: 'roadmap.md',
      title: 'Roadmap',
      sourceType: 'doc',
      sourceUrl: 'docs/roadmap.md',
      excerpt: '最優先は公開準備です。',
      previewText: '背景\n最優先は公開準備です。\n詳細',
      highlightStart: 3,
      highlightEnd: 14,
      highlightText: '最優先は公開準備です。',
      position: KnowledgeGraphCitationPosition(label: 'line 2'),
      confidence: 0.96,
      previewTruncatedBefore: false,
      previewTruncatedAfter: false,
    ),
    KnowledgeGraphRagCitation(
      id: '2',
      fileName: 'budget.pdf',
      title: 'Budget policy',
      sourceType: 'doc',
      sourceUrl: 'https://example.com/budget.pdf',
      excerpt: '予算上限は10万円です。',
      previewText: '背景\n予算上限は10万円です。\n詳細',
      highlightStart: 3,
      highlightEnd: 15,
      highlightText: '予算上限は10万円です。',
      position: KnowledgeGraphCitationPosition(
        label: 'page 4 · 申請上限 · line 30',
        pageNumber: 4,
        section: '申請上限',
        startLine: 30,
        endLine: 30,
      ),
      confidence: 0.81,
      previewTruncatedBefore: false,
      previewTruncatedAfter: false,
    ),
  ],
);
