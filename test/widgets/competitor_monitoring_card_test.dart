import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/competitor_monitoring_card.dart';

void main() {
  test(
    'competitive intel queue covers routed NotebookLM sources for #1660',
    () {
      final ids = competitiveIntelNotebookQueue
          .map((final notebook) => notebook.shortId)
          .toSet();

      expect(
        ids,
        containsAll(<String>{
          '0829f536',
          'f167dcc3',
          'c60da02b',
          'd83954af',
          '17cd45cd',
        }),
      );
    },
  );

  test(
    'competitive intel queue keeps NotebookLM claims in source policy hold',
    () {
      for (final notebook in competitiveIntelNotebookQueue) {
        expect(notebook.issueNumber, 1660);
        expect(notebook.route, 'competitive-intel');
        expect(notebook.sourcePolicy, 'routing_only');
        expect(notebook.primarySourceRequired, isTrue);
        expect(notebook.evidence, isNot(contains('hold_for_source_policy')));
      }
    },
  );
}
