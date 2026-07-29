import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _migrationPath =
    'supabase/migrations/20260721160000_create_investment_portfolio_history.sql';

void main() {
  group('investment portfolio history migration', () {
    late final String sql;

    setUpAll(() {
      sql = File(_migrationPath).readAsStringSync().replaceAll('\r\n', '\n');
    });

    test('stores one deterministic portfolio snapshot per user and day', () {
      final block = _createTableBlock(sql, 'investment_portfolio_history');

      expect(
        block,
        contains('user_id uuid not null references auth.users(id)'),
      );
      expect(block, contains('recorded_on date not null'));
      expect(block, contains('recorded_at timestamptz not null'));
      expect(block, contains('market_value_jpy numeric(28, 4) not null'));
      expect(block, contains('acquisition_cost_jpy numeric(28, 4) not null'));
      expect(block, contains('priced_asset_count integer not null'));
      expect(block, contains('unpriced_asset_count integer not null'));
      expect(block, contains('unique (user_id, recorded_on)'));
    });

    test('allows authenticated users to read only their own history', () {
      expect(
        sql,
        contains(
          'alter table public.investment_portfolio_history enable row level security;',
        ),
      );
      expect(
        sql,
        contains('create policy investment_portfolio_history_select_own'),
      );
      expect(sql, contains('for select\nto authenticated'));
      expect(sql, contains('using (auth.uid() = user_id)'));
      expect(sql, isNot(contains('for insert\nto authenticated')));
    });

    test('captures insert, valuation update, and delete changes', () {
      expect(
        sql,
        contains(
          'create or replace function public.capture_investment_portfolio_history()',
        ),
      );
      expect(sql, contains('security definer\nset search_path = \'\''));
      expect(sql, contains('on conflict (user_id, recorded_on) do update'));
      expect(sql, contains('after insert on public.investment_assets'));
      expect(
        sql,
        contains(
          'after update of quantity, buy_price_jpy, current_price_jpy\non public.investment_assets',
        ),
      );
      expect(sql, contains('after delete on public.investment_assets'));
    });

    test('aligns acquisition cost with priced holdings and backfills once', () {
      expect(
        RegExp(
          r'sum\(quantity \* buy_price_jpy\)\s+filter \(where current_price_jpy is not null\)',
        ).allMatches(sql),
        hasLength(2),
      );
      expect(sql, contains('from public.investment_assets\ngroup by user_id'));
      expect(sql, contains('on conflict (user_id, recorded_on) do nothing;'));
    });
  });
}

String _createTableBlock(String sql, String table) {
  final start = sql.indexOf('create table if not exists public.$table');
  expect(start, isNonNegative, reason: 'missing create table for $table');
  final end = sql.indexOf('\n);', start);
  expect(end, isNonNegative, reason: 'missing create table terminator');
  return sql.substring(start, end);
}
