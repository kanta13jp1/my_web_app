import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _migrationPath =
    'supabase/migrations/20260724120000_first_user_acquisition_events.sql';
const _zennMigrationPath =
    'supabase/migrations/20260820060752_allow_zenn_first_user_attribution.sql';
const _redditMigrationPath =
    'supabase/migrations/20260903172000_allow_reddit_first_user_attribution.sql';

void main() {
  group('first user acquisition event schema', () {
    late final String sql;
    late final String zennSql;
    late final String redditSql;

    setUpAll(() {
      sql = File(
        _migrationPath,
      ).readAsStringSync().replaceAll('\r\n', '\n').toLowerCase();
      zennSql = File(
        _zennMigrationPath,
      ).readAsStringSync().replaceAll('\r\n', '\n').toLowerCase();
      redditSql = File(
        _redditMigrationPath,
      ).readAsStringSync().replaceAll('\r\n', '\n').toLowerCase();
    });

    test('deduplicates every visitor, campaign variant, and funnel stage', () {
      expect(
        sql,
        contains('create table public.first_user_acquisition_events'),
      );
      expect(sql, contains('visitor_id uuid not null'));
      expect(sql, contains("utm_source = 'x'"));
      expect(sql, contains("utm_campaign = 'first_user_growth'"));
      expect(
        sql,
        contains(
          'primary key (\n'
          '    visitor_id,\n'
          '    utm_source,\n'
          '    utm_medium,\n'
          '    utm_campaign,\n'
          '    utm_content,\n'
          '    stage\n'
          '  )',
        ),
      );
      for (final stage in <String>[
        'view',
        'trial',
        'signup_submit',
        'signup_complete',
        'first_action_completed',
        'billing_view',
        'supporter_checkout',
      ]) {
        expect(sql, contains("'$stage'"));
      }
    });

    test('keeps raw rows private and service-role only', () {
      expect(
        sql,
        contains(
          'alter table public.first_user_acquisition_events enable row level security',
        ),
      );
      expect(
        sql,
        contains(
          'revoke all on table public.first_user_acquisition_events\n'
          '  from public, anon, authenticated',
        ),
      );
      expect(
        sql,
        contains(
          'grant select, insert on table public.first_user_acquisition_events\n'
          '  to service_role',
        ),
      );
    });

    test('adds Zenn without weakening the private table boundary', () {
      expect(
        zennSql,
        contains(
          'drop constraint if exists '
          'first_user_acquisition_events_utm_source_check',
        ),
      );
      expect(zennSql, contains("check (utm_source in ('x', 'zenn'))"));
      expect(
        zennSql,
        contains(
          'validate constraint '
          'first_user_acquisition_events_utm_source_check',
        ),
      );
      expect(zennSql, isNot(contains('disable row level security')));
      expect(zennSql, isNot(contains('grant ')));
      expect(zennSql, isNot(contains('revoke ')));
    });

    test('adds Reddit without weakening the private table boundary', () {
      expect(
        redditSql,
        contains(
          'drop constraint if exists '
          'first_user_acquisition_events_utm_source_check',
        ),
      );
      expect(
        redditSql,
        contains("check (utm_source in ('x', 'zenn', 'reddit'))"),
      );
      expect(
        redditSql,
        contains(
          'validate constraint '
          'first_user_acquisition_events_utm_source_check',
        ),
      );
      expect(redditSql, isNot(contains('disable row level security')));
      expect(redditSql, isNot(contains('grant ')));
      expect(redditSql, isNot(contains('revoke ')));
    });

    test('does not persist user content or direct personal identifiers', () {
      for (final forbiddenColumn in <String>[
        'email',
        'name',
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
}
