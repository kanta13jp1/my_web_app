import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _migrationPath =
    'supabase/migrations/20260903104500_anthropic_prompt_cache_telemetry.sql';
const _helperPath = 'supabase/functions/_shared/anthropic_prompt_cache.ts';
const _aiHubPath = 'supabase/functions/ai-hub/index.ts';

void main() {
  group('Anthropic prompt cache contract', () {
    late final String migration;
    late final String helper;
    late final String aiHub;

    setUpAll(() {
      migration =
          File(_migrationPath).readAsStringSync().replaceAll('\r\n', '\n');
      helper = File(_helperPath).readAsStringSync().replaceAll('\r\n', '\n');
      aiHub = File(_aiHubPath).readAsStringSync().replaceAll('\r\n', '\n');
    });

    test('separates static system content behind an environment switch', () {
      expect(helper, contains('ANTHROPIC_PROMPT_CACHE_ENABLED'));
      expect(helper, contains('cache_control: { type: "ephemeral" }'));
      expect(helper, contains('message.role === "system"'));
      expect(aiHub, contains('buildAnthropicMessagesBody'));
      expect(aiHub, contains('anthropicPromptCacheEnabled'));
    });

    test('stores provider-reported cache reads and writes', () {
      expect(migration, contains('cache_read_input_tokens integer'));
      expect(migration, contains('cache_creation_input_tokens integer'));
      expect(migration, contains('anthropic_prompt_cache_usage_daily'));
      expect(migration, contains('cache_hit_request_count'));
      expect(migration, contains('estimated_cost_usd'));
      expect(aiHub, contains('cacheReadInputTokens'));
      expect(aiHub, contains('cacheCreationInputTokens'));
    });

    test('keeps aggregate cache telemetry service-role-only', () {
      expect(migration, contains('WITH (security_invoker = true)'));
      expect(migration, contains('FROM PUBLIC, anon, authenticated'));
      expect(
        migration,
        contains('anthropic_prompt_cache_usage_daily\n  TO service_role'),
      );
    });
  });
}
