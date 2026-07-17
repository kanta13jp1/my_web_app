import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _migrationPath =
    'supabase/migrations/20260717100000_complete_referral_activation.sql';

void main() {
  group('referral activation schema', () {
    late final String sql;

    setUpAll(() {
      sql = File(
        _migrationPath,
      ).readAsStringSync().replaceAll('\r\n', '\n').toLowerCase();
    });

    test('completes only activation-eligible referrals idempotently', () {
      expect(
        sql,
        contains(
          'create or replace function public.complete_referral_activation',
        ),
      );
      expect(sql, contains('security definer'));
      expect(sql, contains("set search_path = ''"));
      expect(
        sql,
        contains("status in ('pending', 'pending_activation', 'completed')"),
      );
      expect(sql, contains("status = 'completed'"));
      expect(
        sql,
        contains(
          'completed_at = coalesce(referral.completed_at, v_completed_at)',
        ),
      );
      expect(
        sql,
        contains("referral.status in ('pending', 'pending_activation')"),
      );
    });

    test('refreshes referral counters in the activation transaction', () {
      expect(sql, contains('update public.referral_codes as code'));
      expect(sql, contains('total_referrals = ('));
      expect(sql, contains('successful_referrals = ('));
      expect(sql, contains('bonus_points_earned = ('));
      expect(sql, contains("referral.status = 'completed'"));
    });

    test('preserves attribution and limits execution to service role', () {
      expect(sql, contains("'activation_source'"));
      expect(sql, contains("'stripe_checkout_session_id'"));
      expect(
        sql,
        contains(
          'revoke all on function public.complete_referral_activation(uuid, text, text)',
        ),
      );
      expect(sql, contains('from public, anon, authenticated'));
      expect(
        sql,
        contains(
          'grant execute on function public.complete_referral_activation(uuid, text, text)',
        ),
      );
      expect(sql, contains('to service_role'));
    });
  });
}
