import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _migrationPath =
    'supabase/migrations/20260815165819_company_agent_runtime.sql';
const _aiHubPath = 'supabase/functions/ai-hub/index.ts';

void main() {
  group('AI Company Builder durable runtime', () {
    late final String sql;
    late final String aiHub;

    setUpAll(() {
      sql = File(_migrationPath)
          .readAsStringSync()
          .replaceAll('\r\n', '\n')
          .toLowerCase();
      aiHub = File(_aiHubPath).readAsStringSync().replaceAll('\r\n', '\n');
    });

    test('uses pgmq with atomic skip-locked task claiming', () {
      expect(sql, contains('create extension if not exists pgmq'));
      expect(sql, contains("pgmq.create('company_agent_runtime')"));
      expect(sql, contains('for update skip locked'));
      expect(sql, contains('claim_company_agent_task'));
      expect(sql, contains('finish_company_agent_task'));
      expect(sql, contains('dispatch_company_agent_runtime_worker'));
      expect(sql, contains("'company_agent_runtime_worker_1m'"));
    });

    test('keeps events owner-readable and server-written', () {
      expect(sql, contains('company_agent_events_select_own'));
      expect(sql, contains('using ((select auth.uid()) = user_id)'));
      expect(
        sql,
        contains(
          'revoke all on public.company_agent_events\n  from public, anon, authenticated',
        ),
      );
      expect(sql, contains('add table public.company_agent_events'));
    });

    test('backfills runtime controls for existing company instances', () {
      expect(
        sql,
        contains("where source = 'company_builder_company'"),
      );
      expect(
        sql,
        contains(
          "case when company.metadata ->> 'passed' = 'true' then 'idle' else 'blocked' end",
        ),
      );
      expect(sql, contains('join auth.users as owner'));
      expect(sql, contains('on conflict (user_id, company_id) do nothing'));
    });

    test('returns before provisioning agents when the gate fails', () {
      final rejection = aiHub.indexOf('if (!passed) {');
      final provisioning = aiHub.indexOf(
        'const toolIds = await ensureSharedToolAgents',
        rejection,
      );
      expect(rejection, greaterThan(0));
      expect(provisioning, greaterThan(rejection));
      expect(
        aiHub.substring(rejection, provisioning),
        contains('status: "gate_rejected"'),
      );
      expect(
        aiHub.substring(rejection, provisioning),
        contains('return json({'),
      );
    });

    test('exposes start, pause, resume, stop, and global kill actions', () {
      for (final action in [
        'company_builder.start',
        'company_builder.pause',
        'company_builder.resume',
        'company_builder.stop',
        'company_builder.global_kill_switch',
      ]) {
        expect(aiHub, contains(action));
      }
    });

    test('exposes cited research and the A2A 1.0 HTTP surface', () {
      expect(aiHub, contains('company_builder.research.add'));
      expect(aiHub, contains('/.well-known/agent-card.json'));
      expect(aiHub, contains('/message:send'));
      expect(aiHub, contains('relative === "/tasks"'));
      expect(aiHub, contains(':cancel'));
      expect(aiHub, contains('"WWW-Authenticate"'));
    });
  });
}
