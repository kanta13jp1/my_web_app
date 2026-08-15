import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _migrationPath =
    'supabase/migrations/20260724120000_first_user_acquisition_events.sql';

void main() {
  group('first user acquisition event schema', () {
    late final String sql;

    setUpAll(() {
      sql = File(
        _migrationPath,
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
