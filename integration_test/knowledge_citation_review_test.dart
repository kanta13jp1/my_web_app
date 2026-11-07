import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:my_web_app/models/knowledge_graph_rag.dart';
import 'package:my_web_app/pages/knowledge_graph_page.dart';
import 'package:my_web_app/services/knowledge_graph_rag_service.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const mobile = bool.fromEnvironment('CITATION_QA_MOBILE');
  const viewport = mobile ? Size(393, 851) : Size(1440, 900);

  Future<void> capture(WidgetTester tester, String state) async {
    for (var frame = 0; frame < 3; frame++) {
      await tester.pump(const Duration(milliseconds: 500));
      await binding.takeScreenshot(
        '${mobile ? 'mobile' : 'desktop'}-citation-$state-$frame',
        <String, Object?>{
          'width': viewport.width,
          'height': viewport.height,
          'devicePixelRatio': mobile ? 2.75 : 1.0,
          'frame': frame,
          'settling': 'Flutter pump 500ms',
        },
      );
    }
  }

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
    await tester.ensureVisible(
      find.byKey(const Key('knowledge-citation-link-1')),
    );
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
    await capture(tester, 'checked');
    await tester.tap(first);
    await tester.pumpAndSettle();
    expect(find.text('回答と引用を確認 0/3'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const Key('knowledge-citation-review-0')),
    );
    await tester.pumpAndSettle();
    await capture(tester, 'reset');
    await tester.tap(first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('閉じる'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('knowledge-citation-link-1')));
    await tester.pumpAndSettle();
    expect(find.text('回答と引用を確認 0/3'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const Key('knowledge-citation-review-0')),
    );
    await tester.pumpAndSettle();
    await capture(tester, 'reopened');
  });

  for (final fixture in <(String, String, String)>[
    ('a', '一致', '青い箱は4個で、採用する。'),
    ('b', '対象違い', '赤い箱は4個で、採用する。'),
    ('c', '数量違い', '青い箱は5個で、採用する。'),
    ('d', '結論違い', '青い箱は4個で、保留する。'),
  ]) {
    testWidgets('引用の手動照合: ${fixture.$2}', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: KnowledgeGraphPage(gateway: _SyntheticGateway(fixture.$3)),
        ),
      );
      await tester.enterText(
        find.byKey(const Key('knowledge-query-field')),
        '数と結論は？',
      );
      await tester.ensureVisible(
        find.byKey(const Key('knowledge-query-button')),
      );
      await tester.tap(find.byKey(const Key('knowledge-query-button')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('青い箱は4個で、採用する。', findRichText: true),
        findsWidgets,
      );
      await tester.ensureVisible(
        find.byKey(const Key('knowledge-citation-link-1')),
      );
      await tester.tap(find.byKey(const Key('knowledge-citation-link-1')));
      await tester.pumpAndSettle();
      final preview = tester.widget<Text>(
        find.byKey(const Key('knowledge-citation-preview-1')),
      );
      expect(
        tester
            .widget<Text>(find.byKey(const Key('knowledge-citation-answer')))
            .data,
        '青い箱は4個で、採用する。 [1]',
      );
      expect(preview.textSpan!.toPlainText(), contains(fixture.$3));
      expect(find.text('検索結果内の相対スコア 100%'), findsOneWidget);
      expect(find.text('この値は回答の正確さを示しません。'), findsOneWidget);
      expect(find.text('回答と引用を確認 0/3'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const Key('knowledge-citation-preview-1')),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await binding.takeScreenshot(
        '${mobile ? 'mobile' : 'desktop'}-citation-fixture-${fixture.$1}',
        <String, Object?>{
          'width': viewport.width,
          'height': viewport.height,
          'devicePixelRatio': mobile ? 2.75 : 1.0,
          'fixture': fixture.$2,
        },
      );
      final first = find.byKey(const Key('knowledge-citation-review-0'));
      await tester.ensureVisible(first);
      await tester.tap(first);
      await tester.pumpAndSettle();
      expect(find.text('回答と引用を確認 1/3'), findsOneWidget);
      await tester.tap(find.byTooltip('閉じる'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('knowledge-citation-link-1')));
      await tester.pumpAndSettle();
      expect(find.text('回答と引用を確認 0/3'), findsOneWidget);
    });
  }

  testWidgets('長い回答を引用ダイアログ内でスクロールできる', (tester) async {
    final longAnswer =
        '[1] ${List.generate(30, (index) => '回答の行 $index').join('\n')}';
    await tester.pumpWidget(
      MaterialApp(
        home: KnowledgeGraphPage(
          gateway: _SyntheticGateway('青い箱は4個です。', longAnswer),
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('knowledge-query-field')),
      '長い回答',
    );
    await tester.ensureVisible(find.byKey(const Key('knowledge-query-button')));
    await tester.tap(find.byKey(const Key('knowledge-query-button')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('knowledge-citation-link-1')),
    );
    await tester.tap(find.byKey(const Key('knowledge-citation-link-1')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(find.byKey(const Key('knowledge-citation-answer')))
          .data,
      longAnswer,
    );
    final answerScroll =
        find.byKey(const Key('knowledge-citation-answer-scroll'));
    final scrollable = find.descendant(
      of: answerScroll,
      matching: find.byType(Scrollable),
    );
    expect(scrollable, findsOneWidget);
    await tester.drag(answerScroll, const Offset(0, -70));
    await tester.pumpAndSettle();
    expect(
      tester.state<ScrollableState>(scrollable).position.pixels,
      greaterThan(0),
    );
    for (var attempt = 0; attempt < 30; attempt++) {
      final position = tester.state<ScrollableState>(scrollable).position;
      if (position.extentAfter <= 0.5) {
        break;
      }
      await tester.drag(answerScroll, const Offset(0, -80));
      await tester.pumpAndSettle();
    }
    expect(
      tester.state<ScrollableState>(scrollable).position.extentAfter,
      lessThanOrEqualTo(0.5),
    );
    final viewportRect = tester.getRect(answerScroll);
    final answerBottom = tester
        .getBottomLeft(
          find.byKey(const Key('knowledge-citation-answer')),
        )
        .dy;
    expect(answerBottom, greaterThan(viewportRect.top));
    expect(answerBottom, lessThanOrEqualTo(viewportRect.bottom + 1));
    await binding.takeScreenshot(
      '${mobile ? 'mobile' : 'desktop'}-citation-long-answer-bottom',
      <String, Object?>{
        'width': viewport.width,
        'height': viewport.height,
        'devicePixelRatio': mobile ? 2.75 : 1.0,
      },
    );
  });
}

class _SyntheticGateway implements KnowledgeGraphRagGateway {
  _SyntheticGateway([this.excerpt = '青い箱は4個です。', this.answerText]);

  final String excerpt;
  final String? answerText;
  @override
  Future<KnowledgeGraphRagAnswer> query({
    required String query,
    required Set<String> sources,
    required bool useLlm,
  }) async =>
      KnowledgeGraphRagAnswer(
        query: '数は？',
        answer: answerText ??
            (excerpt == '青い箱は4個です。' ? '青い箱は4個です [1]。' : '青い箱は4個で、採用する。 [1]'),
        status: 'ok',
        traceId: 'synthetic-only',
        citations: [
          KnowledgeGraphRagCitation(
            id: '1',
            fileName: '合成資料.txt',
            title: '合成資料',
            sourceType: 'doc',
            sourceUrl: 'synthetic.txt',
            excerpt: excerpt,
            previewText: excerpt,
            highlightStart: 0,
            highlightEnd: excerpt.length,
            highlightText: excerpt,
            position: const KnowledgeGraphCitationPosition(label: 'line 1'),
            confidence: 1,
            previewTruncatedBefore: false,
            previewTruncatedAfter: false,
          ),
        ],
      );
}
