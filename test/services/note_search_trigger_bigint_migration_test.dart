import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _migrationPath =
    'supabase/migrations/20260823040700_fix_note_search_index_trigger_bigint.sql';

void main() {
  group('note search trigger bigint compatibility migration', () {
    late final String sql;

    setUpAll(() {
      sql = File(
        _migrationPath,
      ).readAsStringSync().replaceAll('\r\n', '\n').toLowerCase();
    });

    test('casts the bigint note id to the existing integer RPC contract', () {
      expect(
        sql,
        contains(
          'perform public.sync_note_search_index_note('
          'new.user_id, new.id::integer);',
        ),
      );
    });

    test('keeps the trigger function locked down', () {
      expect(sql, contains("set search_path = ''"));
      expect(
        sql,
        contains(
          'revoke execute on function public.refresh_note_search_index_row()\n'
          '  from public, anon, authenticated;',
        ),
      );
    });
  });
}
