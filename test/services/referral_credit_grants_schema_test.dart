import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _migrationPath =
    'supabase/migrations/20260815162827_referral_stripe_credit_grants.sql';

void main() {
  group('referral Stripe credit outbox schema', () {
    late final String sql;

    setUpAll(() {
      sql = File(
        _migrationPath,
      ).readAsStringSync().replaceAll('\r\n', '\n').toLowerCase();
    });

    test(
      'creates one grant per referral beneficiary with strict state checks',
      () {
        expect(
          sql,
          contains('create table if not exists public.referral_credit_grants'),
        );
        expect(sql, contains("beneficiary_role in ('referrer', 'referred')"));
        expect(
          sql,
          contains("status in ('pending', 'processing', 'granted', 'failed')"),
        );
        expect(sql, contains('unique (referral_id, beneficiary_role)'));
        expect(sql, contains('stripe_idempotency_key text not null unique'));
      },
    );

    test('keeps the outbox service-role-only', () {
      expect(
        sql,
        contains(
          'alter table public.referral_credit_grants enable row level security',
        ),
      );
      expect(
        sql,
        contains('revoke all on table public.referral_credit_grants'),
      );
      expect(sql, contains('from public, anon, authenticated'));
      expect(
        sql,
        contains(
          'grant select, insert, update on table public.referral_credit_grants',
        ),
      );
      expect(sql, contains('to service_role'));
    });

    test('activation atomically creates both give-get grants', () {
      expect(
        sql,
        contains(
          'create or replace function public.complete_referral_activation',
        ),
      );
      expect(sql, contains("'referrer'"));
      expect(sql, contains("'referred'"));
      expect(
        sql,
        contains('on conflict (referral_id, beneficiary_role) do nothing'),
      );
      expect(sql, contains('v_referrer_user_id = p_referred_user_id'));
      expect(
        sql,
        isNot(contains('cross join lateral')),
        reason: 'legacy signup-completed rows must not receive paid credits',
      );
    });

    test('claims queue rows without worker lock contention', () {
      expect(
        sql,
        contains(
          'create or replace function public.claim_next_referral_credit_grant',
        ),
      );
      expect(sql, contains('for update of candidate skip locked'));
      expect(sql, contains("status = 'processing'"));
      expect(
        sql,
        contains(
          'revoke all on function public.claim_next_referral_credit_grant(uuid)',
        ),
      );
    });
  });
}
