import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _migrationPath =
    'supabase/migrations/20260903100032_claude_model_routing_telemetry.sql';
const _routerPath = 'supabase/functions/_shared/effort_router.ts';
const _aiHubPath = 'supabase/functions/ai-hub/index.ts';

void main() {
  group('Claude difficulty routing contract', () {
    late final String migration;
    late final String router;
    late final String aiHub;

    setUpAll(() {
      migration =
          File(_migrationPath).readAsStringSync().replaceAll('\r\n', '\n');
      router = File(_routerPath).readAsStringSync().replaceAll('\r\n', '\n');
      aiHub = File(_aiHubPath).readAsStringSync().replaceAll('\r\n', '\n');
    });

    test('keeps simple tasks on Haiku and escalates complex tasks to Sonnet',
        () {
      expect(router, contains('effort === "high" || effort === "xhigh"'));
      expect(router, contains('DEFAULT_CLAUDE_HAIKU_MODEL'));
      expect(router, contains('DEFAULT_CLAUDE_SONNET_MODEL'));
      expect(aiHub, contains('selectClaudeModelForEffort'));
      expect(aiHub, contains('claudeRoute.model'));
    });

    test('records model-level request, token, and cost evidence', () {
      expect(migration, contains('routing_effort text'));
      expect(migration, contains('input_tokens integer'));
      expect(migration, contains('output_tokens integer'));
      expect(migration, contains('claude_model_usage_daily'));
      expect(migration, contains('api_request_count'));
      expect(migration, contains('estimated_cost_usd'));
      expect(aiHub, contains('providerUsageTokens'));
    });

    test('keeps aggregate telemetry service-role-only', () {
      expect(migration, contains('WITH (security_invoker = true)'));
      expect(
        migration,
        contains('FROM PUBLIC, anon, authenticated'),
      );
      expect(
        migration,
        contains('claude_model_usage_daily TO service_role'),
      );
    });
  });
}
