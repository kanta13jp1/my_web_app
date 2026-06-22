import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _attachmentsSetupPath =
    'supabase/migrations/20251108120000_attachments_complete_setup.sql';
const _directUploadHardeningPath =
    'supabase/migrations/20260606023000_harden_attachment_direct_upload.sql';

void main() {
  group('attachments direct upload schema', () {
    late final String setupSql;
    late final String hardeningSql;

    setUpAll(() {
      setupSql = _readSql(_attachmentsSetupPath);
      hardeningSql = _readSql(_directUploadHardeningPath);
    });

    test('stores upload metadata needed after a direct Storage write', () {
      final block = _createTableBlock(setupSql, 'attachments');

      expect(block, contains('note_id bigint not null'));
      expect(
        block,
        contains('user_id uuid not null references auth.users(id)'),
      );
      expect(block, contains('file_name text not null'));
      expect(block, contains('file_path text not null unique'));
      expect(block, contains('file_size bigint not null'));
      expect(block, contains('mime_type text not null'));
    });

    test('keeps the attachments bucket private with upload limits', () {
      expect(hardeningSql, contains('insert into storage.buckets'));
      expect(hardeningSql, contains("'attachments'"));
      expect(hardeningSql, contains('false'));
      expect(hardeningSql, contains('5242880'));
      expect(hardeningSql, contains("'application/pdf'"));
      expect(hardeningSql, contains('on conflict (id) do update'));
      expect(hardeningSql, contains('public = false'));
      expect(
        hardeningSql,
        contains('file_size_limit = excluded.file_size_limit'),
      );
      expect(
        hardeningSql,
        contains('allowed_mime_types = excluded.allowed_mime_types'),
      );
    });

    test('requires authenticated owner-only RLS for metadata rows', () {
      expect(
        hardeningSql,
        contains('alter table public.attachments enable row level security;'),
      );

      for (final operation in <String>[
        'select',
        'insert',
        'update',
        'delete',
      ]) {
        expect(
          hardeningSql,
          contains('on public.attachments for $operation\n  to authenticated'),
        );
      }

      expect(hardeningSql, contains('using (auth.uid() = user_id)'));
      expect(hardeningSql, contains('with check (auth.uid() = user_id)'));
    });

    test('requires authenticated owner-scoped Storage object paths', () {
      for (final operation in <String>[
        'insert',
        'select',
        'update',
        'delete',
      ]) {
        expect(
          hardeningSql,
          contains('on storage.objects for $operation\n  to authenticated'),
        );
      }

      expect(hardeningSql, contains("bucket_id = 'attachments'"));
      expect(
        hardeningSql,
        contains('(storage.foldername(name))[1] = auth.uid()::text'),
      );
    });
  });
}

String _readSql(final String path) {
  return File(path).readAsStringSync().replaceAll('\r\n', '\n').toLowerCase();
}

String _createTableBlock(final String sql, final String table) {
  final start = sql.indexOf('create table public.$table');
  expect(start, isNonNegative, reason: 'missing create table for $table');

  final end = sql.indexOf('\n);', start);
  expect(
    end,
    isNonNegative,
    reason: 'missing create table terminator for $table',
  );

  return sql.substring(start, end);
}
