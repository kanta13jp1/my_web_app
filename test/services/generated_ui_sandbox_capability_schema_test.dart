import 'dart:io';

import 'package:test/test.dart';

const _migrationPath =
    'supabase/migrations/20260707003000_generated_ui_sandbox_capability_boundary.sql';

void main() {
  group('generated UI sandbox capability migration', () {
    late final String sql;

    setUpAll(() {
      sql = File(
        _migrationPath,
      ).readAsStringSync().replaceAll('\r\n', '\n').toLowerCase();
    });

    test('creates a dedicated capability grant table', () {
      expect(
        sql,
        contains(
          'create table if not exists public.generated_ui_sandbox_capability_grants',
        ),
      );
      expect(
        sql,
        contains("role_name text not null default 'generated_ui_sandbox'"),
      );
      expect(
        sql,
        contains(
          "allowed_scopes text[] not null default array['read']::text[]",
        ),
      );
      expect(
        sql,
        contains('backend_access_allowed boolean not null default false'),
      );
    });

    test('fails closed to read-only and backend-denied grants', () {
      expect(sql, contains("check (role_name = 'generated_ui_sandbox')"));
      expect(sql, contains("check (allowed_scopes <@ array['read']::text[])"));
      expect(sql, contains('check (backend_access_allowed = false)'));
    });

    test('enforces authenticated owner-only RLS policies', () {
      expect(
        sql,
        contains(
          'alter table public.generated_ui_sandbox_capability_grants enable row level security',
        ),
      );
      for (final operation in ['select', 'insert', 'update', 'delete']) {
        expect(
          sql,
          contains('generated_ui_sandbox_capability_${operation}_own'),
        );
        expect(sql, contains('to authenticated'));
      }
      expect(sql, contains('using (auth.uid() = user_id)'));
      expect(sql, contains('with check (auth.uid() = user_id)'));
    });
  });
}
