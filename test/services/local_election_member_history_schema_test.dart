import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _migrationPath =
    'supabase/migrations/20261123041000_create_local_election_member_history.sql';

void main() {
  group('local election member history migration', () {
    late final String sql;

    setUpAll(() {
      sql = File(_migrationPath)
          .readAsStringSync()
          .replaceAll('\r\n', '\n')
          .toLowerCase();
    });

    test('creates daily history table with positive member checks', () {
      expect(
        sql,
        contains(
          'create table if not exists public.local_election_member_history',
        ),
      );
      expect(sql, contains('snapshot_date date primary key'));
      expect(sql, contains('fetched_at timestamptz not null'));
      expect(
        sql,
        contains('official_current_local_members integer not null'),
      );
      expect(sql, contains('check (official_current_local_members > 0)'));
      expect(sql, contains('actual_net_increase_required integer not null'));
      expect(sql, contains('check (actual_net_increase_required >= 0)'));
    });

    test('enforces read-only public RLS and service-role writes', () {
      expect(
        sql,
        contains(
          'alter table public.local_election_member_history enable row level security;',
        ),
      );
      expect(
        sql,
        contains(
          'revoke all on public.local_election_member_history\n  from public, anon, authenticated;',
        ),
      );
      expect(
        sql,
        contains(
          'grant select on public.local_election_member_history\n  to anon, authenticated;',
        ),
      );
      expect(
        sql,
        contains(
          'grant all on public.local_election_member_history\n  to service_role;',
        ),
      );
      expect(
        sql,
        contains('create policy local_election_member_history_public_read'),
      );
      expect(sql, contains('for select\n  to anon, authenticated'));
      expect(
        sql,
        contains('create policy local_election_member_history_service_write'),
      );
      expect(sql, contains('for all\n  to service_role'));
    });

    test('idempotently backfills existing hub_data snapshots', () {
      expect(sql, contains("to_regclass('public.hub_data') is not null"));
      expect(sql, contains("source = 'local_election_dataset_snapshot'"));
      expect(sql, contains("'kokumin_local_election_intelligence'"));
      expect(sql, contains("at time zone 'asia/tokyo'"));
      expect(sql, contains('on conflict (snapshot_date) do nothing;'));
    });
  });
}
