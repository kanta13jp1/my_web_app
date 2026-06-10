import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _migrationPath =
    'supabase/migrations/20260610023100_inbox_semantic_capture.sql';

void main() {
  group('note inbox semantic capture schema', () {
    late final String sql;
    late final String aiHub;

    setUpAll(() {
      sql = File(_migrationPath).readAsStringSync().replaceAll('\r\n', '\n');
      aiHub = File(
        'supabase/functions/ai-hub/index.ts',
      ).readAsStringSync().replaceAll('\r\n', '\n');
    });

    test('adds inbox and classification status columns to notes', () {
      expect(sql, contains('add column if not exists capture_status text'));
      expect(sql, contains('add column if not exists capture_source text'));
      expect(
        sql,
        contains('add column if not exists classification_status text'),
      );
      expect(
        sql,
        contains('add column if not exists inbox_saved_at timestamptz'),
      );
      expect(sql, contains('notes_capture_status_check'));
      expect(sql, contains('notes_classification_status_check'));
    });

    test('extends search index and related-note RPC', () {
      expect(sql, contains('alter table public.note_search_index'));
      expect(sql, contains('capture_status = excluded.capture_status'));
      expect(
        sql,
        contains('create or replace function public.find_related_notes'),
      );
      expect(sql, contains('similarity_score real'));
      expect(
        sql,
        contains('grant execute on function public.find_related_notes'),
      );
    });

    test('routes ai-hub actions for classification and related search', () {
      expect(aiHub, contains('"notes.classify"'));
      expect(aiHub, contains('"search.related"'));
      expect(aiHub, contains('case "notes.classify"'));
      expect(aiHub, contains('case "search.related"'));
      expect(aiHub, contains('includeRelated'));
    });
  });
}
