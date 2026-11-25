import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/ai_token_cache_monitor_models.dart';

class SupabaseAiTokenCacheMonitorRepository
    implements AiTokenCacheMonitorRepository {
  const SupabaseAiTokenCacheMonitorRepository(this._client);

  final SupabaseClient _client;

  void _requireAuthenticatedUser() {
    if (_client.auth.currentUser == null) {
      throw StateError(
        'Authentication required to access AI usage and cache monitoring.',
      );
    }
  }

  @override
  Future<TokenCacheSummarySnapshot> fetchSummary({int limit = 50}) async {
    _requireAuthenticatedUser();
    final response = await _client.functions.invoke(
      'ai-hub',
      body: <String, Object?>{
        'action': 'ai_monitor.token_cache.summary',
        'limit': limit,
      },
    );
    final payload = normalizeJsonObject(
      response.data,
      'ai_monitor.token_cache.summary',
    );
    return TokenCacheSummarySnapshot.fromJson(
      normalizeJsonObject(payload['summary'], 'summary'),
    );
  }

  @override
  Future<PrefixStabilityDiagnostic> diagnosePrefix({
    required String systemPrompt,
    required int toolCount,
    required bool useToolSearch,
    required int breakpointCount,
  }) async {
    _requireAuthenticatedUser();
    final response = await _client.functions.invoke(
      'ai-hub',
      body: <String, Object?>{
        'action': 'ai_monitor.token_cache.diagnose_prefix',
        'system_prompt': systemPrompt,
        'tool_count': toolCount,
        'use_tool_search': useToolSearch,
        'breakpoint_count': breakpointCount,
      },
    );
    final payload = normalizeJsonObject(
      response.data,
      'ai_monitor.token_cache.diagnose_prefix',
    );
    return PrefixStabilityDiagnostic.fromJson(
      normalizeJsonObject(payload['diagnostics'], 'diagnostics'),
    );
  }

  @override
  Future<PrefixStabilityDiagnostic> recordToolUsage({
    required String toolName,
    required String modelId,
    required int inputUnits,
    required int outputUnits,
    required int cachedReadUnits,
    required String systemPrompt,
    required int toolCount,
    required bool useToolSearch,
    required int breakpointCount,
  }) async {
    _requireAuthenticatedUser();
    final response = await _client.functions.invoke(
      'ai-hub',
      body: <String, Object?>{
        'action': 'ai_monitor.token_cache.record_tool_usage',
        'tool_name': toolName,
        'model_id': modelId,
        'input_units': inputUnits,
        'output_units': outputUnits,
        'cached_read_units': cachedReadUnits,
        'system_prompt': systemPrompt,
        'tool_count': toolCount,
        'use_tool_search': useToolSearch,
        'breakpoint_count': breakpointCount,
      },
    );
    final payload = normalizeJsonObject(
      response.data,
      'ai_monitor.token_cache.record_tool_usage',
    );
    return PrefixStabilityDiagnostic.fromJson(
      normalizeJsonObject(payload['prefix_diagnostics'], 'prefix_diagnostics'),
    );
  }
}
