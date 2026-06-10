import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _migrationPath =
    'supabase/migrations/20260606110000_create_corporate_bank_fee_plans.sql';

void main() {
  group('corporate bank fee plan migration', () {
    late final String sql;

    setUpAll(() {
      sql = File(_migrationPath).readAsStringSync().replaceAll('\r\n', '\n');
    });

    test('defines fee master columns needed for simulation', () {
      final block = _createTableBlock(sql, 'corporate_bank_fee_plans');

      expect(block, contains('plan_key text not null unique'));
      expect(block, contains('bank_key text not null'));
      expect(block, contains('bank_name text not null'));
      expect(block, contains('plan_name text not null'));
      expect(
        block,
        contains('monthly_base_fee_yen integer not null default 0'),
      );
      expect(block, contains('same_bank_transfer_fee_yen integer not null'));
      expect(block, contains('other_bank_transfer_fee_yen integer not null'));
      expect(block, contains('free_transfer_count integer not null default 0'));
      expect(block, contains('overseas_remittance_available boolean not null'));
      expect(block, contains('api_available boolean not null'));
      expect(block, contains('supported_accounting_software text[] not null'));
      expect(block, contains('source_urls text[] not null'));
      expect(block, contains('source_checked_at date not null'));
    });

    test('enforces non-negative fees and non-blank identifiers', () {
      final block = _createTableBlock(sql, 'corporate_bank_fee_plans');

      expect(block, contains('check (length(btrim(bank_key)) > 0)'));
      expect(block, contains('check (length(btrim(plan_key)) > 0)'));
      expect(block, contains('check (monthly_base_fee_yen >= 0)'));
      expect(block, contains('check (same_bank_transfer_fee_yen >= 0)'));
      expect(block, contains('check (other_bank_transfer_fee_yen >= 0)'));
      expect(block, contains('check (free_transfer_count >= 0)'));
    });

    test('allows public reads of active master data only', () {
      expect(
        sql,
        contains(
          'alter table public.corporate_bank_fee_plans enable row level security;',
        ),
      );
      expect(
        sql,
        contains('create policy corporate_bank_fee_plans_select_active'),
      );
      expect(
        sql,
        contains('for select\nto anon, authenticated\nusing (active)'),
      );
    });

    test('seeds official source-backed bank plans', () {
      for (final planKey in [
        'gmo-aozora-standard',
        'gmo-aozora-tokutoku',
        'sumishin-sbi-corporate',
        'finswer-bank-free',
      ]) {
        expect(sql, contains("'$planKey'"));
      }

      expect(
        sql,
        contains("'https://gmo-aozora.com/business/service/payment.html'"),
      );
      expect(sql, contains("'https://www.netbk.co.jp/contents/hojin/charge/'"));
      expect(sql, contains("'https://finswer-bank.finswer.jp/feature/bank'"));
      expect(sql, contains("date '2026-06-06'"));
      expect(sql, contains('on conflict (plan_key) do update set'));
    });

    test('touches updated_at through a table-specific trigger', () {
      expect(
        sql,
        contains(
          'create or replace function public.set_corporate_bank_fee_plans_updated_at()',
        ),
      );
      expect(
        sql,
        contains('create trigger corporate_bank_fee_plans_updated_at'),
      );
      expect(
        sql,
        contains(
          'for each row execute function public.set_corporate_bank_fee_plans_updated_at();',
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
