import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _migrationPath =
    'supabase/migrations/20260807100000_optimize_note_semantic_search_index.sql';
const _aiHubPath = 'supabase/functions/ai-hub/index.ts';

void main() {
  group('note search indexing optimization', () {
    late final String sql;
    late final String aiHub;

    setUpAll(() {
      sql = File(_migrationPath).readAsStringSync().replaceAll('\r\n', '\n');
      aiHub = File(_aiHubPath).readAsStringSync().replaceAll('\r\n', '\n');
    });

    test('keeps note text in sync with an O(1) row trigger', () {
      expect(sql, contains('sync_note_search_index_note'));
      expect(sql, contains('where n.user_id = p_user_id'));
      expect(sql, contains('and n.id = p_note_id'));
      expect(sql, contains('create trigger notes_refresh_search_index'));
      expect(sql, contains('for each row execute function'));
    });

    test('keeps caller-scoped indexing behind the service role', () {
      expect(
        sql,
        contains(
          'revoke execute on function '
          'public.sync_note_search_index_note(uuid, integer)\n'
          '  from public, anon, authenticated;',
        ),
      );
      expect(
        sql,
        contains(
          'grant execute on function '
          'public.sync_note_search_index_note(uuid, integer)\n'
          '  to service_role;',
        ),
      );
    });

    test('invalidates legacy vectors for retrieval-document reindexing', () {
      expect(
        sql,
        contains(
          'update public.note_search_index\n'
          'set embedding = null\n'
          'where embedding is not null;',
        ),
      );
    });

    test('indexes one note and avoids a full sync on every query', () {
      expect(
        aiHub,
        contains('await syncNoteSearchIndexNote(admin, userId, noteId);'),
      );
      expect(
        aiHub,
        isNot(contains('await syncNoteSearchIndex(admin, userId);')),
      );
      expect(aiHub, contains('await Promise.allSettled(['));
    });

    test('uses the documented 768-dimensional retrieval contract', () {
      expect(aiHub, contains('embedContentConfig: {'));
      expect(aiHub, contains('outputDimensionality: 768'));
      expect(aiHub, contains('"RETRIEVAL_DOCUMENT"'));
      expect(aiHub, contains('"RETRIEVAL_QUERY"'));
      expect(aiHub, contains('vector.length !== 768'));
    });

    test('returns bounded note metadata with remote search results', () {
      expect(
        aiHub,
        contains(
          '.select("id, created_at, is_pinned, is_favorite, reminder_date")',
        ),
      );
      expect(aiHub, contains('.in("id", noteIds)'));
    });
  });
}
