import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _migrationPath =
    'supabase/migrations/20260816040645_create_department_kpi_links.sql';

void main() {
  group('department KPI links schema migration', () {
    late final String sql;

    setUpAll(() {
      sql = File(_migrationPath).readAsStringSync().replaceAll('\r\n', '\n');
    });

    test('defines a single routing row per department', () {
      final block = _createTableBlock(sql, 'department_kpi_links');

      expect(block, contains('id uuid primary key default gen_random_uuid()'));
      expect(block, contains('department text not null unique'));
      expect(block, contains('feature_module text'));
      expect(block, contains('kpi_query text'));
      expect(block, contains('created_at timestamptz not null default now()'));
      expect(block, contains('updated_at timestamptz not null default now()'));
    });

    test('locks department keys to the six supported views', () {
      final block = _createTableBlock(sql, 'department_kpi_links');

      for (final department in [
        'accounting',
        'hr',
        'marketing',
        'sales',
        'development',
        'legal',
      ]) {
        expect(block, contains("'$department'"));
      }
    });

    test('stores allowlisted ai-hub action identifiers instead of SQL', () {
      final block = _createTableBlock(sql, 'department_kpi_links');

      expect(
        block,
        contains(r"kpi_query ~ '^ai_hub\.[a-z][a-z0-9_]*$'"),
      );
      expect(
        block,
        contains('check ((feature_module is null) = (kpi_query is null))'),
      );
      expect(
        sql,
        contains('This value must never be executed as SQL.'),
      );
    });

    test('seeds accounting and five explicit placeholders', () {
      final seedBlock = _seedBlock(sql);

      expect(seedBlock, contains("'accounting',\n    'asset_management',"));
      expect(
        seedBlock,
        contains("'ai_hub.department_finance_summary'"),
      );
      for (final department in [
        'hr',
        'marketing',
        'sales',
        'development',
        'legal',
      ]) {
        expect(seedBlock, contains("('$department', null, null)"));
      }
      expect(
        RegExp(r"\('(?:hr|marketing|sales|development|legal)', null, null\)")
            .allMatches(seedBlock)
            .length,
        5,
      );
    });

    test('exposes read-only rows only to authenticated clients', () {
      expect(
        sql,
        contains(
          'alter table public.department_kpi_links enable row level security;',
        ),
      );
      expect(
        sql,
        contains(
          'revoke all privileges on table public.department_kpi_links\n'
          'from public, anon, authenticated;',
        ),
      );
      expect(
        sql,
        contains(
          'grant all privileges on table public.department_kpi_links to service_role;',
        ),
      );
      expect(
        sql,
        contains(
          'grant select on table public.department_kpi_links to authenticated;',
        ),
      );
      for (final operation in ['insert', 'update', 'delete', 'truncate']) {
        expect(
          sql,
          isNot(
            contains(
              'grant $operation on table public.department_kpi_links '
              'to authenticated;',
            ),
          ),
        );
      }
      expect(
        sql,
        contains('create policy department_kpi_links_authenticated_read'),
      );
      expect(
        sql,
        contains(
          'for select\n  to authenticated\n'
          '  using ((select auth.uid()) is not null);',
        ),
      );
      expect(sql, isNot(contains('to anon')));
    });

    test('maintains updated_at with a table-specific trigger', () {
      expect(
        sql,
        contains(
          'create or replace function public.set_department_kpi_links_updated_at()',
        ),
      );
      expect(sql, contains('create trigger department_kpi_links_updated_at'));
      expect(
        sql,
        contains(
          'for each row execute function public.set_department_kpi_links_updated_at();',
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

String _seedBlock(String sql) {
  final start = sql.indexOf('insert into public.department_kpi_links');
  expect(start, isNonNegative, reason: 'missing department seed insert');

  final end = sql.indexOf('\non conflict (department)', start);
  expect(end, isNonNegative, reason: 'missing department seed upsert');

  return sql.substring(start, end);
}
