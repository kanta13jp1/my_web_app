import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _migrationPath =
    'supabase/migrations/20260824115834_create_pdf_analysis_inputs_bucket.sql';

void main() {
  group('PDF analysis temporary storage', () {
    late final String sql;

    setUpAll(() {
      sql = File(
        _migrationPath,
      ).readAsStringSync().replaceAll('\r\n', '\n').toLowerCase();
    });

    test('creates a private PDF-only 20MB bucket', () {
      expect(sql, contains("'pdf-analysis-inputs'"));
      expect(sql, contains('public = false'));
      expect(sql, contains('20971520'));
      expect(sql, contains("array['application/pdf']::text[]"));
    });

    test('limits authenticated access to the auth.uid owner folder', () {
      expect(sql, contains('to authenticated'));
      expect(sql, contains('(storage.foldername(name))[1]'));
      expect(sql, contains('(select auth.uid())::text'));
      expect(sql, contains('for insert'));
      expect(sql, contains('for select'));
      expect(sql, contains('for delete'));
      expect(sql, isNot(contains('for update')));
    });
  });
}
