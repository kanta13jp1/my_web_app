import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _migrationPath =
    'supabase/migrations/20260822035059_create_prison_rule_events.sql';

void main() {
  late String sql;

  setUpAll(() {
    sql = File(
      _migrationPath,
    ).readAsStringSync().replaceAll('\r\n', '\n').toLowerCase();
  });

  test('creates an indexed append-only event table', () {
    expect(
      sql,
      contains('create table if not exists public.prison_rule_events'),
    );
    expect(sql, contains('create index if not exists'));
    expect(sql, contains('generated always as identity primary key'));
    expect(sql, contains("'check_in'"));
    expect(sql, contains("'urge_resisted'"));
    expect(sql, contains("'required_action_started'"));
    expect(sql, contains("'violation'"));
    expect(
      sql,
      contains(
        'on public.prison_rule_events (user_id, event_date, created_at desc)',
      ),
    );
    expect(sql, isNot(contains('grant update')));
    expect(sql, isNot(contains('grant delete')));
  });

  test('enables owner-scoped RLS and excludes anonymous clients', () {
    expect(
      sql,
      contains(
        'alter table public.prison_rule_events enable row level security',
      ),
    );
    expect(
      sql,
      contains('revoke all on table public.prison_rule_events from anon'),
    );
    expect(
      sql,
      contains(
        'revoke all on table public.prison_rule_events from authenticated',
      ),
    );
    expect(
      sql,
      contains(
        'grant select, insert on table public.prison_rule_events to authenticated',
      ),
    );
    expect(sql, contains('drop policy if exists'));
    expect(sql, contains('for select\n  to authenticated'));
    expect(sql, contains('for insert\n  to authenticated'));
    expect(sql, contains('using ((select auth.uid()) = user_id)'));
    expect(sql, contains('with check ((select auth.uid()) = user_id)'));
  });
}
