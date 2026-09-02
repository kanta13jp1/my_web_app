import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String migration;

  setUpAll(() {
    migration = File(
      'supabase/migrations/20260610133000_voice_ai_usage_governance.sql',
    ).readAsStringSync().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  });

  test('usage writes remain service-role-only', () {
    expect(
      migration,
      contains(
        'revoke all on function public.record_voice_ai_usage( uuid, text, '
        'text, text, numeric, numeric, boolean, boolean, jsonb, numeric, '
        'numeric ) from public, anon, authenticated',
      ),
    );
    expect(
      migration,
      contains(
        'grant execute on function public.record_voice_ai_usage( uuid, text, '
        'text, text, numeric, numeric, boolean, boolean, jsonb, numeric, '
        'numeric ) to service_role',
      ),
    );
    expect(migration, isNot(contains(') to authenticated;')));
  });

  test('users read only their rows while app admins can monitor all providers',
      () {
    expect(migration, contains('using (auth.uid() = user_id)'));
    expect(
      migration,
      contains('using ((select public.is_user_admin((select auth.uid()))))'),
    );
    expect(migration, contains('with (security_invoker = true)'));
    expect(
      migration,
      contains('view public.voice_ai_usage_provider_daily_summary'),
    );
  });

  test('voice training consent is private and opt-in by default', () {
    expect(
      migration,
      contains('create table if not exists public.voice_ai_user_preferences'),
    );
    expect(
      migration,
      contains('training_consent boolean not null default false'),
    );
    expect(
      migration,
      contains('using (auth.uid() = user_id)'),
    );
    expect(
      migration,
      contains(
        'grant update (training_consent) on public.voice_ai_user_preferences '
        'to authenticated',
      ),
    );
    expect(migration, contains('new.consent_updated_at := pg_catalog.now()'));
    expect(migration,
        isNot(contains('alter table if exists public.user_profiles')));
  });
}
