import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String migration;
  late String edgeFunction;

  setUpAll(() {
    migration = File(
      'supabase/migrations/20260814160000_add_voice_dubbing_usage.sql',
    ).readAsStringSync().replaceAll('\r\n', '\n').toLowerCase();
    edgeFunction = File(
      'supabase/functions/ai-hub/index.ts',
    ).readAsStringSync().replaceAll('\r\n', '\n');
  });

  test('keeps generated audio private and owner-path scoped', () {
    expect(
      migration,
      contains("'voice-dubbing',\n  'voice-dubbing',\n  false"),
    );
    expect(migration, contains('for select to authenticated'));
    expect(
      migration,
      contains('(storage.foldername(name))[1] = (select auth.uid())::text'),
    );
  });

  test('quota RPCs are service-role only with a pinned search path', () {
    expect(migration, contains("set search_path = ''"));
    expect(migration, isNot(contains('set search_path = pg_catalog, public')));
    expect(
      migration,
      contains(
        'revoke all on function public.claim_voice_character_quota(uuid, integer)',
      ),
    );
    expect(
      migration,
      contains(
        'revoke all on function public.release_voice_character_quota(uuid, date, integer)',
      ),
    );
    expect(migration, contains('from public, anon, authenticated'));
    expect(migration, contains('to service_role'));
  });

  test('failed generations release only unbilled characters in claim month',
      () {
    expect(migration, contains("'period_start', v_period_start"));
    expect(migration, contains('p_period_start date'));
    expect(edgeFunction, contains('billedCharacters += chunk.length;'));
    expect(
      edgeFunction,
      contains('reservedCharacters - billedCharacters'),
    );
    expect(edgeFunction, contains('p_period_start: usage.period_start'));
    expect(edgeFunction, contains('p_characters: releaseCharacters'));
    expect(edgeFunction, isNot(contains('p_characters: text.length')));
  });
}
