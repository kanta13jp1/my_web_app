import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/local_rag_runtime_service.dart';
import 'package:my_web_app/widgets/pleias_citation_text.dart';

void main() {
  testWidgets('renders Pleias source marker and opens source detail', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: false),
        home: const Scaffold(
          body: PleiasCitationText(
            text: 'Common Corpus [source:1]',
            isDark: false,
            citations: <LocalRagCitation>[
              LocalRagCitation(
                sourceId: '1',
                title: 'common-corpus.md',
                path: 'C:/rag/common-corpus.md',
                snippet: 'Common Corpus is traceable training data.',
                score: 0.92,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('[source:1]'), findsOneWidget);
    expect(find.text('common-corpus.md'), findsOneWidget);

    expect(
      find.byTooltip(
        'common-corpus.md\n'
        'Common Corpus is traceable training data.\n'
        'C:/rag/common-corpus.md\n'
        'score 0.92',
      ),
      findsNWidgets(2),
    );
  });

  testWidgets(
      'renders structured backend parsed_answer and opens Supabase citation dialog',
      (tester) async {
    final parsed = PleiasCitationParseResult.fromMap(<String, Object?>{
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
        <String, Object?>{'text': 'です '},
        <String, Object?>{
          'text': '[1]',
          'reference_id': '1',
          'marker_only': true,
        },
        <String, Object?>{'text': '。'},
      ],
    });

    final citation = LocalRagCitation.fromMap(<String, Object?>{
      'citation_id': '1',
      'file_name': 'approval.md',
      'title': 'Approval Policy',
      'source_url': 'docs/approval.md',
      'highlight_text': '承認期限は申請から3営業日です。',
      'position': <String, Object?>{'label': 'line 8'},
      'confidence': 0.88,
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: false),
        home: Scaffold(
          body: SingleChildScrollView(
            child: PleiasCitationText(
              text: parsed.plainText,
              parsedAnswer: parsed,
              isDark: false,
              citations: <LocalRagCitation>[citation],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byTooltip(
        'Approval Policy\n'
        '承認期限は申請から3営業日です。\n'
        'line 8\n'
        'docs/approval.md\n'
        'score 0.88',
      ),
      findsNWidgets(3),
    );

    final marker =
        find.byKey(const ValueKey<String>('pleias-citation-marker-1'));
    await tester.ensureVisible(marker);
    await tester.tap(marker);
    await tester.pumpAndSettle();

    expect(find.text('Approval Policy'), findsWidgets);
    expect(find.textContaining('承認期限は申請から3営業日です。'), findsOneWidget);
    expect(find.textContaining('line 8'), findsOneWidget);
  });
}
