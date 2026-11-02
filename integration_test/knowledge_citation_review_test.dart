import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:my_web_app/models/knowledge_graph_rag.dart';
import 'package:my_web_app/pages/knowledge_graph_page.dart';
import 'package:my_web_app/services/knowledge_graph_rag_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('引用を開き、確認・解除・再表示できる', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: KnowledgeGraphPage(gateway: _SyntheticGateway())),
    );
    await tester.enterText(
      find.byKey(const Key('knowledge-query-field')),
      '数は？',
    );
    await tester.ensureVisible(find.byKey(const Key('knowledge-query-button')));
    await tester.tap(find.byKey(const Key('knowledge-query-button')));
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.byKey(const Key('knowledge-citation-link-1')));
    await tester.tap(find.byKey(const Key('knowledge-citation-link-1')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('knowledge-citation-preview-1')),
      findsOneWidget,
    );
    expect(find.text('回答と引用を確認 0/3'), findsOneWidget);
    final first = find.byKey(const Key('knowledge-citation-review-0'));
    await tester.ensureVisible(first);
    await tester.tap(first);
    await tester.pumpAndSettle();
    expect(find.text('回答と引用を確認 1/3'), findsOneWidget);
    await tester.tap(first);
    await tester.pumpAndSettle();
    expect(find.text('回答と引用を確認 0/3'), findsOneWidget);
    await tester.tap(first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('閉じる'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('knowledge-citation-link-1')));
    await tester.pumpAndSettle();
    expect(find.text('回答と引用を確認 0/3'), findsOneWidget);
  });
}

class _SyntheticGateway implements KnowledgeGraphRagGateway {
  @override
  Future<KnowledgeGraphRagAnswer> query({
    required String query,
    required Set<String> sources,
    required bool useLlm,
  }) async =>
      const KnowledgeGraphRagAnswer(
        query: '数は？',
        answer: '青い箱は4個です [1]。',
        status: 'ok',
        traceId: 'synthetic-only',
        citations: [
          KnowledgeGraphRagCitation(
            id: '1',
            fileName: '合成資料.txt',
            title: '合成資料',
            sourceType: 'doc',
            sourceUrl: 'synthetic.txt',
            excerpt: '青い箱は4個です。',
            previewText: '青い箱は4個です。',
            highlightStart: 0,
            highlightEnd: 9,
            highlightText: '青い箱は4個です。',
            position: KnowledgeGraphCitationPosition(label: 'line 1'),
            confidence: 1,
            previewTruncatedBefore: false,
            previewTruncatedAfter: false,
          ),
        ],
      );
}
