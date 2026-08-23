import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _migrationPath =
    'supabase/migrations/20260820023000_create_tax_records.sql';

void main() {
  group('tax records schema migration', () {
    late final String sql;

    setUpAll(() {
      sql = File(
        _migrationPath,
      ).readAsStringSync().replaceAll('\r\n', '\n').toLowerCase();
    });

    test('defines the owner-scoped tax record fields with exact money', () {
      final block = _createTableBlock(sql, 'tax_records');

      expect(block, contains('id uuid primary key default gen_random_uuid()'));
      expect(
        block,
        contains(
          'user_id uuid not null references auth.users(id) on delete cascade',
        ),
      );
      expect(block, contains('year smallint not null'));
      expect(block, contains('type text not null'));
      expect(block, contains('amount numeric(20, 4) not null'));
      expect(block, contains('category text not null'));
      expect(block, contains('evidence_url text'));
      expect(block, contains('created_at timestamptz not null default now()'));
      expect(block, contains('updated_at timestamptz not null default now()'));
      expect(block, isNot(contains('double precision')));
      expect(block, isNot(contains('real not null')));
    });

    test('guards year, type, amount, category, and evidence URL', () {
      final block = _createTableBlock(sql, 'tax_records');

      expect(block, contains('check (year between 1900 and 9999)'));
      expect(
        block,
        contains(
          "check (type in ('furusato', 'medical', 'business', 'realestate', 'other'))",
        ),
      );
      expect(block, contains('check (amount >= 0)'));
      expect(
        block,
        contains('check (length(btrim(category)) between 1 and 200)'),
      );
      expect(block, contains('evidence_url is null'));
      expect(block, contains('length(btrim(evidence_url)) between 1 and 2048'));
    });

    test('indexes owner, tax year, and type lookups', () {
      expect(
        sql,
        contains('create index if not exists tax_records_user_year_type_idx'),
      );
      expect(
        sql,
        contains('on public.tax_records (user_id, year desc, type, id)'),
      );
    });

    test('uses least-privilege grants and owner-only RLS', () {
      expect(
        sql,
        contains('alter table public.tax_records enable row level security;'),
      );
      expect(
        sql,
        contains(
          'revoke all privileges on table public.tax_records\n'
          'from public, anon, authenticated;',
        ),
      );
      expect(
        sql,
        contains(
          'grant all privileges on table public.tax_records to service_role;',
        ),
      );
      expect(
        sql,
        contains(
          'grant select, insert, update, delete on table public.tax_records\n'
          'to authenticated;',
        ),
      );
      expect(sql, isNot(contains('to anon;')));

      for (final operation in ['select', 'insert', 'update', 'delete']) {
        expect(sql, contains('create policy tax_records_${operation}_own'));
        expect(sql, contains('for $operation\n  to authenticated'));
      }
      expect(sql, contains('using ((select auth.uid()) = user_id)'));
      expect(sql, contains('with check ((select auth.uid()) = user_id)'));
    });

    test('maintains updated_at with a table-specific trigger', () {
      expect(
        sql,
        contains(
          'create or replace function public.set_tax_records_updated_at()',
        ),
      );
      expect(sql, contains("set search_path = ''"));
      expect(sql, contains('create trigger tax_records_updated_at'));
      expect(
        sql,
        contains(
          'for each row execute function public.set_tax_records_updated_at();',
        ),
      );
    });
  });
}

String _createTableBlock(String sql, String table) {
  final start = sql.indexOf('create table if not exists public.$table');
  expect(start, isNonNegative, reason: 'missing create table for $table');

  final end = sql.indexOf('\n);', start);
  expect(
    end,
    isNonNegative,
    reason: 'missing create table terminator for $table',
  );

  return sql.substring(start, end);
}
