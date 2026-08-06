import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/note_semantic_search_service.dart';

void main() {
  test(
    'search parses ranked results and forwards the requested limit',
    () async {
      Map<String, dynamic>? request;
      final service = NoteSemanticSearchService.withInvoker((body) async {
        request = body;
        return <String, dynamic>{
          'success': true,
          'searchMode': 'ai',
          'explanation': 'hybrid',
          'results': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 42,
              'title': 'Project decision',
              'content': 'Use the second option.',
              'created_at': '2026-04-01T12:30:00.000Z',
              'is_pinned': true,
              'is_favorite': true,
              'reminder_date': '2026-04-08T09:00:00.000Z',
              'search_score': 0.91,
              'match_reason': 'vector',
            },
          ],
        };
      });

      final response = await service.search('last project decision', limit: 8);

      expect(request, <String, dynamic>{
        'action': 'search.query',
        'query': 'last project decision',
        'limit': 8,
      });
      expect(response.searchMode, 'ai');
      expect(response.results, hasLength(1));
      expect(response.results.single.id, '42');
      expect(response.results.single.score, 0.91);
      expect(response.results.single.matchReason, 'vector');
      expect(response.results.single.isPinned, isTrue);
      expect(response.results.single.isFavorite, isTrue);
      expect(
        response.results.single.toNoteRow(),
        containsPair('created_at', '2026-04-01T12:30:00.000Z'),
      );
    },
  );

  test(
    'relatedNotes excludes the current note and caps suggestions at five',
    () async {
      final service = NoteSemanticSearchService.withInvoker((body) async {
        return <String, dynamic>{
          'success': true,
          'searchMode': 'ai',
          'results': List<Map<String, dynamic>>.generate(
            8,
            (index) => <String, dynamic>{
              'id': index,
              'title': 'Note $index',
              'content': 'Shared planning context',
              'search_score': 1 - (index / 10),
              'match_reason': 'hybrid',
            },
          ),
        };
      });

      final results = await service.relatedNotes(
        noteId: '0',
        title: 'Planning',
        content: 'Shared planning context',
        limit: 5,
      );

      expect(results, hasLength(5));
      expect(results.map((item) => item.id), isNot(contains('0')));
      expect(results.first.id, '1');
    },
  );

  test('indexNote invokes the targeted indexing action', () async {
    Map<String, dynamic>? request;
    final service = NoteSemanticSearchService.withInvoker((body) async {
      request = body;
      return <String, dynamic>{'success': true};
    });

    await service.indexNote('123');

    expect(request, <String, dynamic>{
      'action': 'search.index_note',
      'note_id': '123',
    });
  });
}
