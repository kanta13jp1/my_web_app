import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _migrationPath =
    'supabase/migrations/20260722030000_create_micro_mentor_proposals.sql';

void main() {
  group('micro mentor proposal migration', () {
    late final String sql;

    setUpAll(() {
      sql = File(
        _migrationPath,
      ).readAsStringSync().replaceAll('\r\n', '\n').toLowerCase();
    });

    test('stores editable task and schedule proposals', () {
      expect(
        sql,
        contains('create table if not exists public.micro_mentor_proposals'),
      );
      expect(
        sql,
        contains('mentor_id uuid not null references public.agents(id)'),
      );
      expect(sql, contains("proposal_type in ('task', 'schedule')"));
      expect(sql, contains("status in ('proposed', 'accepted', 'rejected')"));
      expect(sql, contains('original_payload jsonb not null'));
      expect(sql, contains('scheduled_for timestamptz'));
    });

    test('limits every authenticated operation to the owning user', () {
      expect(
        sql,
        contains(
          'alter table public.micro_mentor_proposals enable row level security;',
        ),
      );
      expect(sql, contains('micro_mentor_proposals_select_own'));
      expect(sql, contains('micro_mentor_proposals_insert_own'));
      expect(sql, contains('micro_mentor_proposals_update_own'));
      expect(sql, contains('micro_mentor_proposals_delete_own'));
      expect(
        RegExp(r'auth\.uid\(\) = user_id').allMatches(sql).length,
        greaterThanOrEqualTo(4),
      );
    });

    test('only accepts proposals for an owned micro mentor profile', () {
      expect(sql, contains('agents.id = mentor_id'));
      expect(sql, contains('agents.user_id = auth.uid()'));
      expect(
        sql,
        contains("agents.metadata ->> 'profile_type' = 'micro_mentor'"),
      );
    });
  });
}
