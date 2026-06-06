import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _migrationPath =
    'supabase/migrations/20260606103000_create_debt_safety_guidance_master.sql';

void main() {
  group('debt safety guidance master migration', () {
    late final String sql;

    setUpAll(() {
      sql = File(_migrationPath).readAsStringSync().replaceAll('\r\n', '\n');
    });

    test('defines a selectable master table for debt safety content', () {
      final block = _createTableBlock(sql, 'debt_safety_guidance_master');

      expect(block, contains('guidance_key text primary key'));
      expect(block, contains('category text not null'));
      expect(block, contains('severity text not null'));
      expect(block, contains('url text not null'));
      expect(block, contains('source_url text not null'));
      expect(block, contains('active boolean not null default true'));
      expect(block, contains("check (url ~ '^https://')"));
    });

    test('locks categories and severities to known app values', () {
      expect(sql, contains("'legal_rate'"));
      expect(sql, contains("'self_exclusion'"));
      expect(sql, contains("'registered_lender'"));
      expect(sql, contains("'education'"));
      expect(
        sql,
        contains("check (severity in ('info', 'warning', 'danger'))"),
      );
    });

    test('enables active-row read policy for app clients', () {
      expect(
        sql,
        contains(
          'alter table public.debt_safety_guidance_master enable row level security;',
        ),
      );
      expect(
        sql,
        contains('create policy debt_safety_guidance_master_select_active'),
      );
      expect(
        sql,
        contains('for select\nto anon, authenticated\nusing (active)'),
      );
    });

    test('seeds official guidance and education links', () {
      expect(sql, contains('legal_rate_over_20_block'));
      expect(sql, contains('principal_based_interest_limit_warning'));
      expect(sql, contains('lending_self_exclusion'));
      expect(sql, contains('registered_lender_search'));
      expect(sql, contains('name_lending_notice'));
      expect(sql, contains('credit_card_cashing_notice'));
      expect(
        sql,
        contains(
          'https://www.j-fsa.or.jp/personal/useful/question/selfcontrol.php',
        ),
      );
      expect(
        sql,
        contains('https://www.fsa.go.jp/ordinary/kensaku/index.html'),
      );
      expect(sql, contains('https://www.fsa.go.jp/ordinary/chuui/index.html'));
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
