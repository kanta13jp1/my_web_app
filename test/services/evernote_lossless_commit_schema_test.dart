import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _migrationPath =
    'supabase/migrations/20260823050803_evernote_lossless_commit.sql';

void main() {
  group('Evernote lossless commit schema', () {
    late final String sql;

    setUpAll(() {
      sql = File(_migrationPath)
          .readAsStringSync()
          .replaceAll('\r\n', '\n')
          .toLowerCase();
    });

    test('keeps source ENEX archives private and owner scoped', () {
      expect(sql, contains("'evernote-migration-archives'"));
      expect(sql, contains('public = false'));
      expect(sql, contains('to authenticated'));
      expect(
        sql,
        contains('(storage.foldername(name))[1] = (select auth.uid())::text'),
      );
      expect(
        sql,
        isNot(contains('evernote archive owners can delete')),
      );
    });

    test('stores source hashes and loss-preserving metadata', () {
      expect(sql, contains('add column source_enml text'));
      expect(sql, contains('add column source_metadata jsonb'));
      expect(sql, contains('add column content_sha256 text'));
      expect(sql, contains('attachments_content_sha256_format_check'));
      expect(sql, contains('source_archive_path text'));
    });

    test('uses invoker RPCs and removes default execution', () {
      expect(sql, contains('function public.evernote_commit_note('));
      expect(sql, contains('function public.evernote_verify_note('));
      expect(sql, contains('security invoker'));
      expect(sql, isNot(contains('security definer')));
      expect(
        sql,
        contains('from public, anon, authenticated, service_role'),
      );
      expect(sql, contains('to authenticated;'));
    });

    test('requires note ownership for attachment metadata writes', () {
      expect(
        sql,
        contains('notes.user_id = (select auth.uid())'),
      );
      expect(sql, contains('attachments.note_id'));
    });
  });
}
