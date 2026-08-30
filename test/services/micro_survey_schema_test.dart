import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _migrationPath =
    'supabase/migrations/20260830130000_create_contextual_micro_surveys.sql';

void main() {
  group('contextual micro-survey schema', () {
    late final String sql;

    setUpAll(() {
      sql = File(_migrationPath).readAsStringSync().replaceAll('\r\n', '\n');
    });

    test('stores only allow-listed task context and a 90-day expiry', () {
      expect(sql, contains("survey_key = 'task_completion_v1'"));
      expect(
        sql,
        contains(
          "trigger in ('deployment_monitoring_created', 'resource_created')",
        ),
      );
      expect(
        sql,
        contains("route in ('/deployment-monitoring', '/team-workspace')"),
      );
      expect(sql, contains("default (now() + interval '90 days')"));
      expect(sql, isNot(contains('service_name')));
      expect(sql, isNot(contains('resource_id')));
      expect(sql, isNot(contains('email')));
      expect(sql, isNot(contains('ip_address')));
    });

    test('enforces cooldown, rolling cap, and opt-out atomically', () {
      expect(sql, contains("v_now - interval '14 days'"));
      expect(sql, contains("v_now - interval '30 days'"));
      expect(sql, contains('prompt_count_in_window >= 2'));
      expect(sql, contains('if v_preference.opted_out then'));
      expect(sql, contains('for update;'));
    });

    test('uses operation-specific owner RLS and least privilege', () {
      expect(
        sql,
        contains('revoke all on table public.micro_survey_responses'),
      );
      expect(sql, contains('create policy micro_survey_responses_select_own'));
      expect(sql, contains('create policy micro_survey_responses_insert_own'));
      expect(sql, contains('create policy micro_survey_responses_delete_own'));
      expect(sql, contains('using ((select auth.uid()) = user_id)'));
      expect(sql, contains('with check ((select auth.uid()) = user_id)'));
      expect(
        sql,
        isNot(contains('create policy micro_survey_responses_update_own')),
      );
    });
  });
}
