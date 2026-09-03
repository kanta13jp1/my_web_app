import 'dart:io';

import 'package:test/test.dart';

const _migrationPath =
    'supabase/migrations/20260903174500_ai_feature_roi_dashboard.sql';

void main() {
  late String sql;

  setUpAll(() {
    sql = File(_migrationPath).readAsStringSync().toLowerCase();
  });

  test('stores bounded per-user assumptions behind forced RLS', () {
    expect(
        sql,
        contains(
            'create table if not exists public.ai_feature_roi_parameters'));
    expect(
      sql,
      contains(
        'alter table public.ai_feature_roi_parameters enable row level security',
      ),
    );
    expect(
      sql,
      contains(
        'alter table public.ai_feature_roi_parameters force row level security',
      ),
    );
    expect(sql, contains('(select auth.uid()) = user_id'));
    expect(sql, contains('minutes_saved_per_success between 0 and 1440'));
    expect(sql, contains('hourly_value_usd between 0 and 10000'));
    expect(
      sql,
      contains(
        'revoke all privileges on table public.ai_feature_roi_parameters',
      ),
    );
  });

  test('exposes only service-role aggregate usage without prompt content', () {
    expect(
      sql,
      contains('create or replace view public.ai_feature_usage_cost_daily'),
    );
    expect(sql, contains('with (security_invoker = true)'));
    expect(sql, contains('count(*)::bigint as request_count'));
    expect(sql, contains('as api_cost_usd'));
    expect(
      sql,
      contains(
        'revoke all privileges on table public.ai_feature_usage_cost_daily',
      ),
    );
    expect(
      sql,
      contains(
        'grant select on table public.ai_feature_usage_cost_daily to service_role',
      ),
    );
    expect(sql, isNot(contains('prompt')));
    expect(sql, isNot(contains('response_text')));
    expect(sql, isNot(contains('user_id uuid as')));
  });
}
