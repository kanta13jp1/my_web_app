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
        'revoke all on function public.claim_voice_character_quota(uuid, uuid, text, integer)',
      ),
    );
    expect(
      migration,
      contains(
        'revoke all on function public.start_voice_dubbing_chunk(uuid, uuid, integer)',
      ),
    );
    expect(
      migration,
      contains(
        'revoke all on function public.reconcile_voice_dubbing_quota(uuid)',
      ),
    );
    expect(
      migration,
      contains(
        'revoke all on function public.finish_voice_dubbing_job(uuid, uuid, text, integer, jsonb, text)',
      ),
    );
    expect(migration, contains('from public, anon, authenticated'));
    expect(migration, contains('to service_role'));
    expect(
      migration,
      contains(
        'grant select on table public.voice_dubbing_jobs to service_role',
      ),
    );
  });

  test('idempotent jobs reconcile unstarted reservations in the claim month',
      () {
    expect(migration, contains("'period_start', v_period_start"));
    expect(
      migration,
      contains('create table if not exists public.voice_dubbing_jobs'),
    );
    expect(
      migration,
      contains(
        "status in ('reserved', 'processing', 'completed', 'failed', 'expired')",
      ),
    );
    expect(migration, contains('reserved_characters - started_characters'));
    expect(migration, contains('expires_at < pg_catalog.now()'));
    expect(
      migration,
      contains("status not in ('completed', 'failed', 'expired')"),
    );
    expect(migration, contains("status <> 'completed'"));
    expect(
      migration,
      contains("'terminal_conflict', v_job.status <> p_status"),
    );
    expect(edgeFunction, contains('"reconcile_voice_dubbing_quota"'));
    expect(edgeFunction, contains('p_request_id: requestId'));
    expect(edgeFunction, contains('p_request_hash: requestHash'));
    expect(edgeFunction, contains('"start_voice_dubbing_chunk"'));
    expect(edgeFunction, contains('"finish_voice_dubbing_job"'));
    expect(edgeFunction, contains('billedCharacters += chunk.length;'));
    expect(edgeFunction, contains('p_billed_characters: billedCharacters'));
  });

  test(
    'transport ambiguity keeps attempted usage and completion is replay-safe',
    () {
      expect(edgeFunction, contains('startedCharacters += chunk.length;'));
      expect(edgeFunction, contains('providerCallAmbiguous = true;'));
      expect(
        edgeFunction,
        contains('Math.max(billedCharacters, startedCharacters)'),
      );
      expect(
        edgeFunction,
        contains('p_billed_characters: accountedCharacters'),
      );
      expect(edgeFunction, contains('.from("voice_dubbing_jobs")'));
      expect(edgeFunction, contains('completionPersisted'));
      expect(edgeFunction, contains('completionUncertain = true;'));
      expect(edgeFunction, contains('error: "voice_completion_pending"'));
      expect(edgeFunction, contains('const finalizedAsFailure'));
      expect(edgeFunction, contains('if (finishError || !finalizedAsFailure)'));
    },
  );

  test('shared voices are used without mutating the provider account', () {
    expect(edgeFunction, contains('/v1/shared-voices?'));
    expect(edgeFunction, isNot(contains('/v1/voices/add/')));
    expect(edgeFunction, isNot(contains('resolveElevenLabsSharedVoice')));
  });

  test('provider details stay in server logs and responses use error ids', () {
    expect(edgeFunction, contains('voice.catalog provider failure'));
    expect(edgeFunction, contains('voice.dubbing provider failure'));
    expect(edgeFunction, contains('error_id: errorId'));
    expect(edgeFunction, contains('error: "voice_catalog_unavailable"'));
    expect(edgeFunction, contains('error: "elevenlabs_tts_unavailable"'));
    expect(edgeFunction, contains('error: "voice_usage_unavailable"'));
    expect(edgeFunction, contains('error: "voice_generation_failed"'));
  });
}
