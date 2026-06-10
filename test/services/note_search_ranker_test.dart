import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/note_search_ranker.dart';

void main() {
  group('NoteSearchRanker', () {
    test('matches minor typos with fuzzy token scoring', () {
      final note = <String, dynamic>{
        'title': 'Weekly meeting notes',
        'content': 'Budget review and next tasks',
        'tags': <String>['meeting', 'money'],
      };

      expect(NoteSearchRanker.matches(note, 'meetng'), isTrue);
      expect(NoteSearchRanker.matches(note, 'budjet'), isTrue);
    });

    test('matches tags as searchable context', () {
      final note = <String, dynamic>{
        'title': 'Untitled',
        'content': 'Remember to check this later',
        'tags': <String>['invoice'],
      };

      expect(NoteSearchRanker.matches(note, 'invoice'), isTrue);
    });

    test('rejects unrelated queries', () {
      final note = <String, dynamic>{
        'title': 'Reading list',
        'content': 'A design systems book',
        'tags': <String>['learning'],
      };

      expect(NoteSearchRanker.matches(note, 'payroll'), isFalse);
    });
  });
}
