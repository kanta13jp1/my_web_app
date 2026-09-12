import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _migrationPath =
    'supabase/migrations/20260902080000_create_money_forward_sync_tables.sql';

void main() {
  group('MoneyForward sync schema migration', () {
    late final String sql;

    setUpAll(() {
      sql = File(
        _migrationPath,
      ).readAsStringSync().replaceAll('\r\n', '\n').toLowerCase();
    });

    test('defines exact account and transaction snapshot fields', () {
      final accounts = _createTableBlock(sql, 'mf_accounts');
      final transactions = _createTableBlock(sql, 'mf_transactions');

      expect(
        accounts,
        contains('id uuid primary key default gen_random_uuid()'),
      );
      expect(
        accounts,
        contains(
          'user_id uuid not null references auth.users(id) on delete cascade',
        ),
      );
      expect(accounts, contains('mf_account_id text not null'));
      expect(accounts, contains('account_name text not null'));
      expect(accounts, contains('account_type text not null'));
      expect(accounts, contains('balance_jpy numeric(20, 4) not null'));
      expect(accounts, contains('last_synced_at timestamptz not null'));

      expect(
        transactions,
        contains('id uuid primary key default gen_random_uuid()'),
      );
      expect(transactions, contains('mf_account_id text not null'));
      expect(transactions, contains('mf_transaction_id text not null'));
      expect(transactions, contains('transaction_date date not null'));
      expect(transactions, contains('amount numeric(20, 4) not null'));
      expect(transactions, contains('category text not null'));
      expect(transactions, contains('description text not null'));
      expect(transactions, contains('raw_payload jsonb not null'));
      expect(accounts, isNot(contains('double precision')));
      expect(transactions, isNot(contains('double precision')));
    });

    test('supports idempotent provider upserts without cross-owner links', () {
      final accounts = _createTableBlock(sql, 'mf_accounts');
      final transactions = _createTableBlock(sql, 'mf_transactions');

      expect(accounts, contains('unique (user_id, mf_account_id)'));
      expect(transactions, contains('unique (user_id, mf_transaction_id)'));
      expect(
        transactions,
        contains(
          'foreign key (user_id, mf_account_id)\n'
          '    references public.mf_accounts (user_id, mf_account_id)',
        ),
      );
      expect(
        transactions,
        contains("check (jsonb_typeof(raw_payload) = 'object')"),
      );
    });

    test('adds owner-first indexes for sync freshness and transaction reads',
        () {
      expect(
        sql,
        contains(
          'on public.mf_accounts (user_id, last_synced_at desc)',
        ),
      );
      expect(
        sql,
        contains(
          'on public.mf_transactions (user_id, transaction_date desc)',
        ),
      );
      expect(
        sql,
        contains(
          'on public.mf_transactions '
          '(user_id, mf_account_id, transaction_date desc)',
        ),
      );
    });

    test('allows owner reads but reserves all writes for the service role', () {
      for (final table in ['mf_accounts', 'mf_transactions']) {
        expect(
          sql,
          contains('alter table public.$table enable row level security;'),
        );
        expect(sql, contains('create policy ${table}_select_own'));
      }

      expect(
        sql,
        contains(
          'revoke all privileges on table public.mf_accounts, '
          'public.mf_transactions\nfrom public, anon, authenticated;',
        ),
      );
      expect(
        sql,
        contains(
          'grant all privileges on table public.mf_accounts, '
          'public.mf_transactions\nto service_role;',
        ),
      );
      expect(
        sql,
        contains(
          'grant select on table public.mf_accounts, '
          'public.mf_transactions\nto authenticated;',
        ),
      );
      expect(sql, contains('using ((select auth.uid()) = user_id)'));
      expect(sql, isNot(contains('for insert\n  to authenticated')));
      expect(sql, isNot(contains('for update\n  to authenticated')));
      expect(sql, isNot(contains('for delete\n  to authenticated')));
    });

    test('does not add provider credential storage to snapshot tables', () {
      final accounts = _createTableBlock(sql, 'mf_accounts');
      final transactions = _createTableBlock(sql, 'mf_transactions');
      final snapshots = '$accounts\n$transactions';

      expect(snapshots, isNot(contains('access_token')));
      expect(snapshots, isNot(contains('refresh_token')));
      expect(snapshots, isNot(contains('password')));
      expect(snapshots, isNot(contains('secret')));
    });

    test('maintains updated_at with table-specific triggers', () {
      for (final table in ['mf_accounts', 'mf_transactions']) {
        expect(
          sql,
          contains(
            'create or replace function public.set_${table}_updated_at()',
          ),
        );
        expect(sql, contains('create trigger ${table}_updated_at'));
        expect(
          sql,
          contains(
            'for each row execute function '
            'public.set_${table}_updated_at();',
          ),
        );
      }
      expect(sql, contains("set search_path = ''"));
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
