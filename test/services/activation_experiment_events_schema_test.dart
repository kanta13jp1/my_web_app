import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _migrationPath =
    'supabase/migrations/20260724100000_activation_experiment_unique_metrics.sql';
const _wbsMigrationPath =
    'supabase/migrations/20260724101500_wbs_activation_unique_metrics.sql';

void main() {
  group('activation experiment unique event schema', () {
    late final String sql;

    setUpAll(() {
      sql = File(
        _migrationPath,
      ).readAsStringSync().replaceAll('\r\n', '\n').toLowerCase();
    });

    test('deduplicates each signed-in user and funnel stage', () {
      expect(sql, contains('create table public.activation_experiment_events'));
      expect(
        sql,
        contains('primary key (auth_user_id, hypothesis_id, variant, stage)'),
      );
      expect(
        sql,
        contains(
          'on conflict (auth_user_id, hypothesis_id, variant, stage) do nothing',
        ),
      );
      expect(sql, contains("hypothesis_id ~ '^a(0[1-9]|10)\$'"));
      expect(sql, contains("variant in ('control', 'treatment')"));
      for (final stage in <String>[
        'onboarding_view',
        'intent_selected',
        'first_action_started',
        'first_action_completed',
        'onboarding_completed',
        'value_recap_view',
        'billing_view',
        'supporter_checkout',
        'pro_checkout',
        'checkout_return',
      ]) {
        expect(sql, contains("'$stage'"));
      }
    });

    test('accepts writes only from non-anonymous authenticated users', () {
      expect(
        sql,
        contains(
          'alter table public.activation_experiment_events enable row level security',
        ),
      );
      expect(
        sql,
        contains(
          'revoke all on table public.activation_experiment_events\n  from public, anon, authenticated',
        ),
      );
      expect(
        sql,
        contains(
          'create or replace function public.record_activation_experiment_event',
        ),
      );
      expect(sql, contains('security definer'));
      expect(sql, contains('set search_path = pg_catalog, public'));
      expect(sql, contains('auth.uid()'));
      expect(sql, contains("auth.jwt() ->> 'is_anonymous'"));
      expect(sql, contains('non-anonymous user is required'));
      expect(
        sql,
        contains(
          'grant execute on function public.record_activation_experiment_event(text)\n  to authenticated, service_role',
        ),
      );
      expect(
        sql,
        isNot(
          contains(
            'grant execute on function public.record_activation_experiment_event(text)\n  to anon',
          ),
        ),
      );
    });

    test('exposes all twenty aggregate arms only to service role', () {
      expect(
        RegExp(
          r"\('a(?:0[1-9]|10)', '(?:control|treatment)'\)",
        ).allMatches(sql).length,
        20,
      );
      expect(sql, contains('with (security_invoker = true)'));
      for (final aggregate in <String>[
        'as unique_onboarding_views',
        'as unique_intent_selections',
        'as unique_first_action_starts',
        'as unique_first_action_completions',
        'as unique_onboarding_completions',
        'as unique_value_recap_views',
        'as unique_billing_views',
        'as unique_supporter_checkouts',
        'as unique_pro_checkouts',
        'as unique_checkout_starts',
        'as unique_checkout_returns',
      ]) {
        expect(sql, contains(aggregate));
      }
      expect(
        sql,
        contains(
          'revoke all on table public.activation_experiment_arm_stats\n  from public, anon, authenticated',
        ),
      );
      expect(
        sql,
        contains(
          'grant select on table public.activation_experiment_arm_stats to service_role',
        ),
      );
    });

    test('does not persist user content or browser identifiers', () {
      for (final forbiddenColumn in <String>[
        'email',
        'ip_address',
        'user_agent',
        'browser_fingerprint',
        'prompt_text',
        'answer_text',
        'challenge_text',
      ]) {
        expect(
          RegExp('\\n\\s*$forbiddenColumn\\s').hasMatch(sql),
          isFalse,
          reason: '$forbiddenColumn must not be persisted',
        );
      }
    });
  });

  group('activation analytics WBS registration', () {
    late final String sql;

    setUpAll(() {
      sql = File(
        _wbsMigrationPath,
      ).readAsStringSync().replaceAll('\r\n', '\n').toLowerCase();
    });

    test('registers issue 4323 on the first-yen critical path', () {
      expect(sql, contains('insert into public.wbs_tasks'));
      expect(sql, contains('decide a01-a10 on unique users'));
      expect(sql, contains("'first-yen-revenue'"));
      expect(sql, contains('4323'));
      expect(sql, contains('github_issue_synced_at'));
      expect(sql, isNot(contains('github_synced_at')));
      expect(sql, contains("'open'"));
      expect(
        sql,
        contains(
          'https://github.com/kanta13jp1/my_web_app/issues/4323',
        ),
      );
      expect(
        sql,
        contains(
          '[revenue-p0][bank-payout] verify one external payment and at least jpy 1 bank deposit',
        ),
      );
    });

    test('reuses an issue-synced WBS row before attempting insert', () {
      final updateIndex = sql.indexOf('update public.wbs_tasks\nset');
      final insertIndex = sql.indexOf('insert into public.wbs_tasks');

      expect(updateIndex, greaterThanOrEqualTo(0));
      expect(insertIndex, greaterThan(updateIndex));
      expect(sql, contains('where github_issue_number = 4323'));
      expect(sql, contains('where not exists ('));
      expect(sql, contains('with activation_task as ('));
      expect(sql, contains('from activation_task'));
    });
  });
}
