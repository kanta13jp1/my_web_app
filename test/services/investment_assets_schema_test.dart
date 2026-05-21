import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _migrationPath =
    'supabase/migrations/20260522020000_create_investment_assets.sql';

void main() {
  group('investment assets schema migration', () {
    late final String sql;

    setUpAll(() {
      sql = File(_migrationPath).readAsStringSync().replaceAll('\r\n', '\n');
    });

    test('defines investment holdings with deterministic numeric fields', () {
      final block = _createTableBlock(sql, 'investment_assets');

      expect(block, contains('id uuid primary key default gen_random_uuid()'));
      expect(
        block,
        contains('user_id uuid not null references auth.users(id)'),
      );
      expect(block, contains('asset_type text not null'));
      expect(block, contains('ticker text not null'));
      expect(block, contains('quantity numeric(28, 8) not null'));
      expect(block, contains('buy_price_jpy numeric(20, 4) not null'));
      expect(block, contains('buy_date date'));
      expect(block, contains('current_price_jpy numeric(20, 4)'));
      expect(block, contains('last_priced_at timestamptz'));
    });

    test('enforces asset type, positive quantity, and price guards', () {
      final block = _createTableBlock(sql, 'investment_assets');

      expect(
        block,
        contains("check (asset_type in ('stock', 'crypto', 'reit', 'etf'))"),
      );
      expect(block, contains('check (length(btrim(ticker)) > 0)'));
      expect(block, contains('check (quantity > 0)'));
      expect(block, contains('check (buy_price_jpy >= 0)'));
      expect(
        block,
        contains('check (current_price_jpy is null or current_price_jpy >= 0)'),
      );
      expect(
        block,
        contains(
          'check (last_priced_at is null or current_price_jpy is not null)',
        ),
      );
    });

    test('adds lookup indexes for user scoped portfolio reads', () {
      expect(
        sql,
        contains(
          'create index if not exists investment_assets_user_type_ticker_idx',
        ),
      );
      expect(
        sql,
        contains('on public.investment_assets (user_id, asset_type, ticker)'),
      );
      expect(
        sql,
        contains(
          'create index if not exists investment_assets_user_last_priced_idx',
        ),
      );
      expect(
        sql,
        contains(
          'on public.investment_assets (user_id, last_priced_at desc nulls last)',
        ),
      );
    });

    test('enables owner-only RLS for authenticated users', () {
      expect(
        sql,
        contains(
          'alter table public.investment_assets enable row level security;',
        ),
      );

      for (final operation in ['select', 'insert', 'update', 'delete']) {
        expect(
          sql,
          contains('create policy investment_assets_${operation}_own'),
        );
        expect(sql, contains('for $operation\nto authenticated'));
      }

      expect(sql, contains('using (auth.uid() = user_id)'));
      expect(sql, contains('with check (auth.uid() = user_id)'));
    });

    test('touches updated_at through a table-specific trigger', () {
      expect(
        sql,
        contains(
          'create or replace function public.set_investment_assets_updated_at()',
        ),
      );
      expect(sql, contains('create trigger investment_assets_updated_at'));
      expect(
        sql,
        contains(
          'for each row execute function public.set_investment_assets_updated_at();',
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
