import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Keeps the market-price cache migration contract pinned without live providers.
const _migrationPath =
    'supabase/migrations/20260523090000_create_investment_market_price_cache.sql';

void main() {
  group('investment market price cache schema migration', () {
    late final String sql;

    setUpAll(() {
      sql = File(_migrationPath).readAsStringSync().replaceAll('\r\n', '\n');
    });

    test('defines cache rows with provider and JPY price fields', () {
      final block = _createTableBlock(sql, 'investment_market_price_cache');

      expect(block, contains('id uuid primary key default gen_random_uuid()'));
      expect(block, contains('asset_type text not null'));
      expect(block, contains('ticker text not null'));
      expect(block, contains("currency text not null default 'JPY'"));
      expect(block, contains('provider text not null'));
      expect(block, contains('price_jpy numeric(20, 4) not null'));
      expect(block, contains('fetched_at timestamptz not null'));
      expect(block, contains('expires_at timestamptz not null'));
      expect(
        block,
        contains("source_payload jsonb not null default '{}'::jsonb"),
      );
    });

    test('enforces asset type, nonblank keys, price, and expiry guards', () {
      final block = _createTableBlock(sql, 'investment_market_price_cache');

      expect(
        block,
        contains("check (asset_type in ('stock', 'crypto', 'reit', 'etf'))"),
      );
      expect(block, contains('check (length(btrim(ticker)) > 0)'));
      expect(block, contains('check (length(btrim(currency)) > 0)'));
      expect(block, contains('check (length(btrim(provider)) > 0)'));
      expect(block, contains('check (price_jpy >= 0)'));
      expect(block, contains('check (expires_at > fetched_at)'));
      expect(block, contains('unique (asset_type, ticker, currency)'));
    });

    test('adds freshness index and service-role-only RLS policy', () {
      expect(
        sql,
        contains(
          'create index if not exists investment_market_price_cache_freshness_idx',
        ),
      );
      expect(
        sql,
        contains(
          'on public.investment_market_price_cache (asset_type, ticker, currency, expires_at desc)',
        ),
      );
      expect(
        sql,
        contains(
          'alter table public.investment_market_price_cache enable row level security;',
        ),
      );
      expect(
        sql,
        contains(
            'create policy investment_market_price_cache_service_role_all'),
      );
      expect(sql, contains('to service_role'));
      expect(sql, contains('using (true)'));
      expect(sql, contains('with check (true)'));
    });

    test('touches updated_at through a table-specific trigger', () {
      expect(
        sql,
        contains(
          'create or replace function public.set_investment_market_price_cache_updated_at()',
        ),
      );
      expect(
        sql,
        contains('create trigger investment_market_price_cache_updated_at'),
      );
      expect(
        sql,
        contains(
          'for each row execute function public.set_investment_market_price_cache_updated_at();',
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
