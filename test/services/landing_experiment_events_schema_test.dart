import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _migrationPath =
    'supabase/migrations/20260722211500_create_landing_experiment_events.sql';
const _primaryMetricsMigrationPath =
    'supabase/migrations/20260723150000_landing_experiment_primary_metrics.sql';

void main() {
  group('landing experiment event schema', () {
    late final String sql;

    setUpAll(() {
      sql = File(
        _migrationPath,
      ).readAsStringSync().replaceAll('\r\n', '\n').toLowerCase();
    });

    test('deduplicates each visitor and funnel stage', () {
      expect(
        sql,
        contains('create table public.landing_experiment_events'),
      );
      expect(
        sql,
        contains(
          'primary key (visitor_id, hypothesis_id, variant, stage)',
        ),
      );
      expect(
        sql,
        contains(
          'on conflict (visitor_id, hypothesis_id, variant, stage) do nothing',
        ),
      );
      expect(sql, contains("hypothesis_id ~ '^h(0[1-9]|10)\$'"));
      expect(sql, contains("variant in ('control', 'treatment')"));
      for (final stage in <String>[
        'view',
        'hero_cta',
        'intent',
        'trial',
        'trial_fallback',
        'save_cta',
        'signup_submit',
        'signup_complete',
        'sticky_cta',
        'feature_outcome_trial',
        'feature_catalog_expand',
      ]) {
        expect(sql, contains("'$stage'"));
      }
    });

    test('accepts writes only through a validated security definer RPC', () {
      expect(
        sql,
        contains(
          'alter table public.landing_experiment_events enable row level security',
        ),
      );
      expect(
        sql,
        contains(
          'revoke all on table public.landing_experiment_events\n  from public, anon, authenticated',
        ),
      );
      expect(
        sql,
        contains(
          'create or replace function public.record_landing_experiment_event',
        ),
      );
      expect(sql, contains('security definer'));
      expect(sql, contains('set search_path = pg_catalog, public'));
      expect(sql, contains('auth.uid()'));
      expect(sql, contains("auth.jwt() ->> 'is_anonymous'"));
      expect(
        sql,
        contains(
          'grant execute on function public.record_landing_experiment_event(uuid, text)',
        ),
      );
    });

    test('exposes all twenty arms only to service role', () {
      expect(
        RegExp(r"\('h(?:0[1-9]|10)', '(?:control|treatment)'\)")
            .allMatches(sql)
            .length,
        20,
      );
      expect(sql, contains('with (security_invoker = true)'));
      expect(sql, contains('as unique_views'));
      expect(sql, contains('as non_anonymous_signup_completes'));
      expect(
        sql,
        contains(
          'revoke all on table public.landing_experiment_arm_stats\n  from public, anon, authenticated',
        ),
      );
      expect(
        sql,
        contains(
          'grant select on table public.landing_experiment_arm_stats to service_role',
        ),
      );
    });

    test('does not collect visitor PII or content', () {
      for (final forbiddenColumn in <String>[
        'email',
        'ip_address',
        'user_agent',
        'browser_fingerprint',
        'prompt_text',
        'answer_text',
      ]) {
        expect(
          RegExp('\\n\\s*$forbiddenColumn\\s').hasMatch(sql),
          isFalse,
          reason: '$forbiddenColumn must not be persisted',
        );
      }
    });

    test('keeps daily aggregate validation aligned with current stages', () {
      expect(
        sql,
        contains(
          'trial|trial_fallback|save_cta|signup_submit|signup_complete|sticky_cta|feature_outcome_trial|feature_catalog_expand',
        ),
      );
      expect(
        sql,
        contains(
          'create or replace function public.increment_app_analytics_source_detail',
        ),
      );
    });
  });

  group('landing experiment primary metrics migration', () {
    late final String sql;

    setUpAll(() {
      sql = File(
        _primaryMetricsMigrationPath,
      ).readAsStringSync().replaceAll('\r\n', '\n').toLowerCase();
    });

    test('adds deduplicated mobile funnel stages to both validators', () {
      expect(sql, contains("'mobile_view'"));
      expect(sql, contains("'mobile_signup_submit'"));
      expect(
        sql,
        contains(
          'view|mobile_view|hero_cta|intent|trial|trial_fallback|save_cta|signup_submit|mobile_signup_submit|signup_complete',
        ),
      );
      expect(
        sql,
        isNot(
          contains(
            'primary key (visitor_id, hypothesis_id, variant, stage)',
          ),
        ),
        reason: 'the existing deduplication key must not be recreated',
      );
    });

    test('exposes every hypothesis primary numerator and denominator', () {
      for (final aggregate in <String>[
        'as unique_views',
        'as unique_hero_ctas',
        'as unique_trials',
        'as unique_save_ctas',
        'as unique_signup_submits',
        'as non_anonymous_signup_completes',
        'as unique_mobile_views',
        'as unique_mobile_signup_submits',
      ]) {
        expect(sql, contains(aggregate));
      }
      expect(sql, contains('with (security_invoker = true)'));
      expect(
        sql,
        contains(
          'grant select on table public.landing_experiment_arm_stats to service_role',
        ),
      );
    });

    test('keeps raw events inaccessible to browser roles', () {
      expect(
        sql,
        isNot(
          contains(
            'grant select on table public.landing_experiment_events to anon',
          ),
        ),
      );
      expect(
        sql,
        isNot(
          contains(
            'grant select on table public.landing_experiment_events to authenticated',
          ),
        ),
      );
    });
  });
}
