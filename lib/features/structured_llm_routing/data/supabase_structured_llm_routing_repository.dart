import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/structured_llm_routing_models.dart';

class SupabaseStructuredLlmRoutingRepository
    implements StructuredLlmRoutingRepository {
  const SupabaseStructuredLlmRoutingRepository(this._client);

  final SupabaseClient _client;

  void _requireAuthenticatedUser() {
    if (_client.auth.currentUser == null) {
      throw StateError(
        'Authentication required to use structured LLM routing.',
      );
    }
  }

  Map<String, Object?> _asPayloadMap(Object? raw, String context) =>
      normalizeJsonObject(raw, context);

  @override
  Future<LlmRoutePlan> resolveRoute({
    required String taskType,
    required String prompt,
    required bool requiresReasoning,
    Map<String, Object?>? responseSchema,
  }) async {
    _requireAuthenticatedUser();
    final response = await _client.functions.invoke(
      'ai-hub',
      body: <String, Object?>{
        'action': 'ai_router.structured.route',
        'task_type': taskType,
        'prompt': prompt,
        'requires_reasoning': requiresReasoning,
        if (responseSchema != null) 'response_schema': responseSchema,
      },
    );
    final payload = _asPayloadMap(
      response.data,
      'ai_router.structured.route',
    );
    if (payload['success'] != true) {
      throw StateError(
        payload['error']?.toString() ?? 'Failed to resolve LLM route.',
      );
    }
    final routeMap = _asPayloadMap(
      payload['route'],
      'ai_router.structured.route.route',
    );
    return LlmRoutePlan.fromJson(routeMap);
  }

  @override
  Future<StructuredRoutingPersistResult> validateAndSave({
    required String taskType,
    required String prompt,
    required bool requiresReasoning,
    required String rawOutput,
    required Map<String, Object?> responseSchema,
    required String schemaName,
  }) async {
    _requireAuthenticatedUser();
    try {
      final response = await _client.functions.invoke(
        'ai-hub',
        body: <String, Object?>{
          'action': 'ai_router.structured.validate_and_save',
          'task_type': taskType,
          'prompt': prompt,
          'requires_reasoning': requiresReasoning,
          'raw_output': rawOutput,
          'response_schema': responseSchema,
          'schema_name': schemaName,
        },
      );
      final payload = _asPayloadMap(
        response.data,
        'ai_router.structured.validate_and_save',
      );
      return StructuredRoutingPersistResult.fromJson(payload);
    } on FunctionException catch (error) {
      final Object? details = error.details;
      if (error.status == 422 && details is Map<Object?, Object?>) {
        final detailMap = _asPayloadMap(
          details,
          'ai_router.structured.validate_and_save(422)',
        );
        if (detailMap.containsKey('validation') &&
            detailMap.containsKey('route')) {
          return StructuredRoutingPersistResult.fromJson(detailMap);
        }
      }
      rethrow;
    }
  }

  @override
  Future<List<StructuredRoutingPreferenceRecord>> listPreferences() async {
    _requireAuthenticatedUser();
    final response = await _client.functions.invoke(
      'ai-hub',
      body: const <String, Object?>{
        'action': 'ai_router.structured.list_preferences',
      },
    );
    final payload = _asPayloadMap(
      response.data,
      'ai_router.structured.list_preferences',
    );
    if (payload['success'] != true) {
      throw StateError(
        payload['error']?.toString() ?? 'Failed to load routing preferences.',
      );
    }
    final Object? rawList = payload['preferences'];
    if (rawList is! List<Object?>) {
      throw const FormatException(
        'Missing or invalid preferences list from ai-hub.',
      );
    }
    final records = <StructuredRoutingPreferenceRecord>[];
    for (final item in rawList) {
      records.add(
        StructuredRoutingPreferenceRecord.fromJson(
          _asPayloadMap(item, 'preferences[]'),
        ),
      );
    }
    return List<StructuredRoutingPreferenceRecord>.unmodifiable(records);
  }
}
