import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/evernote_search_query_service.dart';

void main() {
  final base = EvernoteSearchDocument(
    title: 'Quarterly Project Plan',
    content: 'Brave new world budget review',
    tags: <String>['Work', 'Finance'],
    notebookName: 'Planning',
    stackName: 'Company',
    createdAt: DateTime(2026, 8, 28, 10),
    updatedAt: DateTime(2026, 8, 30, 12),
    reminderTime: DateTime(2026, 9, 2, 9),
  );

  group('EvernoteSearchQueryService', () {
    test('uses implicit AND and any: switches implicit terms to OR', () {
      final all = EvernoteSearchQueryService.parse('project missing');
      final any = EvernoteSearchQueryService.parse('any: project missing');

      expect(all.isFullySupported, isTrue);
      expect(all.matches(base), isFalse);
      expect(any.isFullySupported, isTrue);
      expect(any.matches(base), isTrue);
    });

    test('implements uppercase Boolean precedence and parentheses', () {
      final precedence =
          EvernoteSearchQueryService.parse('missing OR project AND budget');
      final grouped =
          EvernoteSearchQueryService.parse('(missing OR project) AND absent');

      expect(precedence.matches(base), isTrue);
      expect(grouped.matches(base), isFalse);
    });

    test('implements NOT and minus exclusions', () {
      final notFinance =
          EvernoteSearchQueryService.parse('project NOT tag:finance');
      final minusMissing =
          EvernoteSearchQueryService.parse('project -tag:missing');

      expect(notFinance.matches(base), isFalse);
      expect(minusMissing.matches(base), isTrue);
    });

    test('matches exact phrases and suffix wildcards as whole words', () {
      expect(
        EvernoteSearchQueryService.parse('"brave new world"').matches(base),
        isTrue,
      );
      expect(
        EvernoteSearchQueryService.parse('quart*').matches(base),
        isTrue,
      );
      expect(
        EvernoteSearchQueryService.parse('arter*').matches(base),
        isFalse,
      );
    });

    test('matches title, notebook, stack, and tag modifiers', () {
      final query = EvernoteSearchQueryService.parse(
        'intitle:project notebook:Planning stack:Company tag:Work',
      );
      final wrongNotebook =
          EvernoteSearchQueryService.parse('notebook:Archive');

      expect(query.matches(base), isTrue);
      expect(wrongNotebook.matches(base), isFalse);
      expect(EvernoteSearchQueryService.parse('tag:*').matches(base), isTrue);
    });

    test('matches absolute and relative created/updated/reminder dates', () {
      final now = DateTime(2026, 8, 31, 18);
      expect(
        EvernoteSearchQueryService.parse('created:20260828')
            .matches(base, now: now),
        isTrue,
      );
      expect(
        EvernoteSearchQueryService.parse('created:day-2')
            .matches(base, now: now),
        isFalse,
      );
      expect(
        EvernoteSearchQueryService.parse('updated:day-2')
            .matches(base, now: now),
        isTrue,
      );
      expect(
        EvernoteSearchQueryService.parse('reminderTime:month')
            .matches(base, now: now),
        isTrue,
      );
    });

    test('treats Boolean operators as case-sensitive', () {
      final query = EvernoteSearchQueryService.parse('project or missing');

      expect(query.isAdvanced, isFalse);
      expect(query.matches(base), isFalse);
    });

    test('reports unsupported operators and leaves results unfiltered', () {
      final query =
          EvernoteSearchQueryService.parse('project resource:application/pdf');

      expect(query.unsupportedOperators, <String>['resource']);
      expect(query.isFullySupported, isFalse);
      expect(
        query.matches(
          const EvernoteSearchDocument(
            title: 'unrelated',
            content: '',
            tags: <String>[],
          ),
        ),
        isTrue,
      );
    });

    test('reports malformed quotes, dates, wildcard, and parentheses', () {
      expect(
        EvernoteSearchQueryService.parse('"open phrase').errors,
        isNotEmpty,
      );
      expect(
        EvernoteSearchQueryService.parse('created:20261340').errors,
        isNotEmpty,
      );
      expect(
        EvernoteSearchQueryService.parse('pro*ject').errors,
        isNotEmpty,
      );
      expect(
        EvernoteSearchQueryService.parse('(project OR budget').errors,
        isNotEmpty,
      );
    });
  });
}
