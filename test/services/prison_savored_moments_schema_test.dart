import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/domain/models/savored_moment.dart';

const _migrationPath =
    'supabase/migrations/20261117090000_create_prison_savored_moments.sql';

void main() {
  late String sql;

  setUpAll(() {
    sql = File(
      _migrationPath,
    ).readAsStringSync().replaceAll('\r\n', '\n').toLowerCase();
  });

  test('creates an indexed append-only table', () {
    expect(
      sql,
      contains('create table if not exists public.prison_savored_moments'),
    );
    expect(sql, contains('generated always as identity primary key'));
    expect(
      sql,
      contains(
        'on public.prison_savored_moments (user_id, moment_date desc, id desc)',
      ),
    );
    expect(sql, isNot(contains('grant update')));
    expect(sql, isNot(contains('grant delete')));
  });

  test('the note length check matches the client limit', () {
    expect(
      sql,
      contains(
        'check (char_length(btrim(note)) between 1 and '
        '$savoredMomentMaxLength)',
      ),
    );
  });

  test('enables owner-scoped RLS and excludes anonymous clients', () {
    expect(
      sql,
      contains(
        'alter table public.prison_savored_moments enable row level security',
      ),
    );
    expect(
      sql,
      contains('revoke all on table public.prison_savored_moments from anon'),
    );
    expect(
      sql,
      contains(
        'revoke all on table public.prison_savored_moments from authenticated',
      ),
    );
    expect(
      sql,
      contains(
        'grant select, insert on table public.prison_savored_moments '
        'to authenticated',
      ),
    );
    expect(sql, contains('for select\n  to authenticated'));
    expect(sql, contains('for insert\n  to authenticated'));
    expect(sql, contains('using ((select auth.uid()) = user_id)'));
    expect(sql, contains('with check ((select auth.uid()) = user_id)'));
  });
}
