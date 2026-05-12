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
}
