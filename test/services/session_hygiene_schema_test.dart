import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _migrationPath =
    'supabase/migrations/20260610090000_session_hygiene_cleanup.sql';
const _healthCheckPath = 'supabase/functions/health-check/index.ts';

void main() {
  group('session hygiene schema migration', () {
    late final String sql;
    late final String healthCheck;

    setUpAll(() {
      sql = File(
        _migrationPath,
      ).readAsStringSync().replaceAll('\r\n', '\n').toLowerCase();
      healthCheck = File(
        _healthCheckPath,
      ).readAsStringSync().replaceAll('\r\n', '\n').toLowerCase();
    });

    test('adds authenticated session expiry and invalidation fields', () {
      expect(sql, contains('alter table public.user_presence'));
      expect(sql, contains('add column if not exists expires_at timestamptz'));
      expect(
        sql,
        contains('add column if not exists invalidated_at timestamptz'),
      );
      expect(
        sql,
        contains('add column if not exists invalidation_reason text'),
      );
      expect(sql, contains("interval '48 hours'"));
      expect(sql, contains('user_presence_invalidation_reason_check'));
      expect(sql, contains("in ('idle_timeout', 'manual_cleanup')"));
    });

    test(
      'keeps cleanup_old_presence compatible while invalidating idle users',
      () {
        expect(
          sql,
          contains('create or replace function public.cleanup_old_presence()'),
        );
        expect(sql, contains('returns void'));
        expect(
          sql,
          contains(
            "invalidation_reason = coalesce(invalidation_reason, 'idle_timeout')",
          ),
        );
        expect(sql, contains("last_seen < now() - interval '48 hours'"));
        expect(sql, contains("invalidated_at < now() - interval '7 days'"));
        expect(sql, contains("last_seen < now() - interval '30 minutes'"));
      },
    );

    test('exposes client status and service-role health RPCs', () {
      expect(
        sql,
        contains(
          'create or replace function public.get_session_hygiene_status',
        ),
      );
      expect(sql, contains('auth.uid() = user_id'));
      expect(sql, contains("auth.role() = 'service_role'"));
      expect(sql, contains("'requires_relogin', true"));
      expect(sql, contains('session expired. please sign in again.'));
      expect(
        sql,
        contains(
          'create or replace function public.get_session_hygiene_health',
        ),
      );
      expect(sql, contains("'timeout_hours', 48"));
      expect(
        sql,
        contains(
          'grant execute on function public.get_session_hygiene_status(text) to authenticated, service_role',
        ),
      );
      expect(
        sql,
        contains(
          'revoke all on function public.cleanup_old_presence() from public, anon, authenticated',
        ),
      );
      expect(
        sql,
        contains(
          'grant execute on function public.cleanup_old_presence() to service_role',
        ),
      );
      expect(
        sql,
        contains(
          'revoke all on function public.get_session_hygiene_health() from public, anon, authenticated',
        ),
      );
      expect(
        sql,
        contains(
          'grant execute on function public.get_session_hygiene_health() to service_role',
        ),
      );
    });

    test('schedules cleanup when pg_cron is available', () {
      expect(sql, contains('create extension if not exists pg_cron'));
      expect(sql, contains("where jobname = 'session_hygiene_cleanup_hourly'"));
      expect(
        sql,
        contains("cron.schedule(\n    'session_hygiene_cleanup_hourly'"),
      );
      expect(sql, contains("'17 * * * *'"));
      expect(sql, contains('select public.cleanup_old_presence();'));
    });

    test('adds health-check visibility without leaking session details', () {
      expect(
        healthCheck,
        contains('admin.rpc(\n      "get_session_hygiene_health"'),
      );
      expect(healthCheck, contains('checks["session_hygiene"]'));
      expect(healthCheck, contains('session hygiene'));
    });
  });
}
