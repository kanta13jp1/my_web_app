import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    'supabase/migrations/20260824024535_create_ai_guardrail_events.sql',
  );
  final edgeFunction = File('supabase/functions/ai-hub/index.ts');

  test('guardrail audit schema is service-role-only and stores no raw text',
      () {
    expect(migration.existsSync(), isTrue);
    final sql = migration.readAsStringSync().toLowerCase();

    expect(sql, contains('id bigint generated always as identity primary key'));
    expect(sql, contains('enable row level security'));
    expect(sql, contains('force row level security'));
    expect(sql, contains('revoke all on table public.ai_guardrail_events'));
    expect(
      sql,
      contains(
        'grant select, insert on table public.ai_guardrail_events to service_role',
      ),
    );
    expect(sql, contains("where decision <> 'allow'"));
    expect(sql, contains('where user_id is not null'));

    final columnBlock = RegExp(
      r'create table if not exists public\.ai_guardrail_events\s*\((.*?)\);',
      dotAll: true,
    ).firstMatch(sql)?.group(1);
    expect(columnBlock, isNotNull);
    expect(columnBlock, isNot(contains('prompt')));
    expect(columnBlock, isNot(contains('response')));
    expect(columnBlock, isNot(contains('raw_content')));
    expect(columnBlock, isNot(contains('matched_value')));
  });

  test('Writer chat is guarded before and after the provider call', () {
    final source = edgeFunction.readAsStringSync();

    expect(source, contains('collectProviderInputText'));
    expect(source, contains('stage: "input"'));
    expect(source, contains('stage: "output"'));
    expect(source, contains('parseWriterNativeGuardrailBlock'));
    expect(source, contains('writerGuardrailAuditFailure'));
  });

  test(
    'guardrail observability requires admin authorization and omits user id',
    () {
      final source = edgeFunction.readAsStringSync();
      final actionBlock = RegExp(
        r'case "observability\.guardrails": \{(.*?)case "observability\.provider_health"',
        dotAll: true,
      ).firstMatch(source)?.group(1);

      expect(actionBlock, isNotNull);
      expect(actionBlock, contains('authorizeAutomationActor'));
      expect(actionBlock, contains('admin_required'));
      expect(actionBlock, isNot(contains('user_id,')));
      expect(actionBlock, contains('raw_content_stored: false'));
      expect(actionBlock, contains('user_id_returned: false'));
    },
  );
}
