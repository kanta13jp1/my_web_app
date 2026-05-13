import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_persistence.dart';

const _migrationPath =
    'supabase/migrations/20260514040900_create_asset_liability_supabase_schema.sql';

void main() {
  group('asset liability Supabase schema migration', () {
    late final String sql;

    setUpAll(() {
      sql = File(_migrationPath).readAsStringSync().replaceAll('\r\n', '\n');
    });

    test('defines the planned payload tables with common columns', () {
      for (final table in AssetLiabilitySupabaseTablePlan.payloadTables) {
        final block = _createTableBlock(sql, table);

        expect(
          block,
          contains('id uuid primary key default gen_random_uuid()'),
        );
        expect(
          block,
          contains('user_id uuid not null references auth.users(id)'),
        );
        expect(block, contains('month_key text not null'));
        expect(block, contains("payload jsonb not null default '{}'::jsonb"));
        expect(
          block,
          contains('created_at timestamptz not null default now()'),
        );
        expect(
          block,
          contains('updated_at timestamptz not null default now()'),
        );
      }
    });

    test('enforces month identity uniqueness and jsonb object payloads', () {
      for (final table in AssetLiabilitySupabaseTablePlan.payloadTables) {
        final block = _createTableBlock(sql, table);

        expect(block, contains("month_key = 'global'"));
        expect(block, contains("month_key ~ '^[0-9]{4}-[0-9]{2}\$'"));
        expect(block, contains("check (jsonb_typeof(payload) = 'object')"));
        expect(block, contains('unique (user_id, month_key)'));
      }
    });

    test('enables owner-only RLS for each table and operation', () {
      for (final table in AssetLiabilitySupabaseTablePlan.payloadTables) {
        expect(
          sql,
          contains('alter table public.$table enable row level security;'),
        );
        expect(sql, contains('create policy ${table}_select_own'));
        expect(sql, contains('on public.$table\nfor select\nto authenticated'));
        expect(sql, contains('create policy ${table}_insert_own'));
        expect(sql, contains('on public.$table\nfor insert\nto authenticated'));
        expect(sql, contains('create policy ${table}_update_own'));
        expect(sql, contains('on public.$table\nfor update\nto authenticated'));
        expect(sql, contains('create policy ${table}_delete_own'));
        expect(sql, contains('on public.$table\nfor delete\nto authenticated'));
      }

      expect(sql, contains('using (auth.uid() = user_id)'));
      expect(sql, contains('with check (auth.uid() = user_id)'));
    });

    test('documents SharedPreferences migration and rollback policy', () {
      expect(
        sql,
        contains('SharedPreferences remains the primary runtime store'),
      );
      expect(sql, contains('Initial sync'));
      expect(sql, contains('Conflict priority'));
      expect(sql, contains('Device sync'));
      expect(sql, contains('Rollback'));
      expect(sql, contains('UI must not call Supabase directly'));
    });

    test('keeps the Dart table plan aligned with the migration', () {
      expect(
        AssetLiabilitySupabaseTablePlan.payloadTables,
        containsAll(<String>[
          'asset_liability_monthly_states',
          'asset_liability_income_plans',
          'asset_liability_recurring_income_templates',
          'asset_liability_payment_source_settings',
          'asset_liability_monthly_snapshots',
        ]),
      );
      expect(AssetLiabilitySupabaseTablePlan.commonPayloadColumns, <String>[
        'id',
        'user_id',
        'month_key',
        'payload',
        'created_at',
        'updated_at',
      ]);
      expect(AssetLiabilitySupabaseTablePlan.globalMonthKey, 'global');
    });
  });
}

String _createTableBlock(String sql, String table) {
  final start = sql.indexOf('create table if not exists public.$table');
  expect(start, isNonNegative, reason: 'missing create table for $table');

  final end = sql.indexOf(');', start);
  expect(
    end,
    isNonNegative,
    reason: 'missing create table terminator for $table',
  );

  return sql.substring(start, end);
}
