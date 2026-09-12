import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('business CSV import migration', () {
    late String migration;

    setUpAll(() {
      migration = File(
        'supabase/migrations/20260610121000_business_csv_import_dry_run.sql',
      ).readAsStringSync();
    });

    test('exposes authenticated dry-run and commit RPCs', () {
      expect(migration, contains('preview_business_note_csv_import'));
      expect(migration, contains('commit_business_note_csv_import'));
      expect(migration, contains('SECURITY DEFINER'));
      expect(migration, contains('v_user_id uuid := auth.uid()'));
      expect(migration, contains('authenticated user required'));
      expect(
        migration,
        contains(
          'REVOKE ALL ON FUNCTION public.preview_business_note_csv_import(jsonb, text)',
        ),
      );
      expect(
        migration,
        contains(
          'REVOKE ALL ON FUNCTION public.commit_business_note_csv_import(jsonb, text, boolean)',
        ),
      );
      expect(
        migration,
        contains(
          'GRANT EXECUTE ON FUNCTION public.preview_business_note_csv_import',
        ),
      );
      expect(
        migration,
        contains(
          'GRANT EXECUTE ON FUNCTION public.commit_business_note_csv_import',
        ),
      );
    });

    test('performs DB-backed validation before insert', () {
      expect(migration, contains('jsonb_array_length(v_rows)'));
      expect(migration, contains('limited to 500 rows'));
      expect(migration, contains('required title missing'));
      expect(migration, contains('required content missing'));
      expect(migration, contains('duplicate note already exists'));
      expect(migration, contains('FROM public.notes'));
    });

    test('supports all-or-rollback and valid-rows-only commit modes', () {
      expect(migration, contains('p_rollback_on_error boolean DEFAULT true'));
      expect(
        migration,
        contains("WHEN p_rollback_on_error THEN 'all_or_rollback'"),
      );
      expect(migration, contains("ELSE 'valid_rows_only'"));
      expect(
        migration,
        contains('IF p_rollback_on_error AND v_error_count > 0 THEN'),
      );
      expect(migration, contains("'rolledBack', true"));
      expect(migration, contains('INSERT INTO public.notes'));
    });
  });
}
