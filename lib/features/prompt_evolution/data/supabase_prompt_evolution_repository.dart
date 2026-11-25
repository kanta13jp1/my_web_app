import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/prompt_evolution_models.dart';

class SupabasePromptEvolutionRepository implements PromptEvolutionRepository {
  const SupabasePromptEvolutionRepository(this._client);

  final SupabaseClient _client;

  void _requireAuthenticatedUser() {
    if (_client.auth.currentUser == null) {
      throw StateError(
        'Authentication required to run prompt evolution actions.',
      );
    }
  }

  @override
  Future<GpaBatchEvaluationReport> evaluateTraceBatch({
    required double varianceThreshold,
    required List<Map<String, Object?>> traces,
    bool persist = true,
  }) async {
    _requireAuthenticatedUser();
    final response = await _client.functions.invoke(
      'app-hub',
      body: <String, Object?>{
        'action': 'agent.evaluate_gpa_batch',
        'variance_threshold': varianceThreshold,
        'traces': traces,
        'persist': persist,
      },
    );
    final payload = normalizeJsonObject(
      response.data,
      'agent.evaluate_gpa_batch',
    );
    return GpaBatchEvaluationReport.fromJson(
      normalizeJsonObject(payload['batch'], 'agent.evaluate_gpa_batch.batch'),
    );
  }

  @override
  Future<PromptEvolutionRunResult> evolveFromTraces({
    required double varianceThreshold,
    required List<Map<String, Object?>> traces,
    required PromptEvolutionDraft basePrompt,
    bool persistCandidate = true,
  }) async {
    _requireAuthenticatedUser();
    try {
      final response = await _client.functions.invoke(
        'app-hub',
        body: <String, Object?>{
          'action': 'agent.evolve_prompts_from_gpa',
          'variance_threshold': varianceThreshold,
          'traces': traces,
          'base_prompt': basePrompt.toJson(),
          'persist_candidate': persistCandidate,
        },
      );
      final payload = normalizeJsonObject(
        response.data,
        'agent.evolve_prompts_from_gpa',
      );
      return PromptEvolutionRunResult.fromJson(payload);
    } on FunctionException catch (error) {
      final Object? details = error.details;
      if (error.status == 422 && details is Map<Object?, Object?>) {
        final detailMap = normalizeJsonObject(
          details,
          'agent.evolve_prompts_from_gpa(422)',
        );
        if (detailMap.containsKey('batch') &&
            detailMap.containsKey('candidates')) {
          return PromptEvolutionRunResult.fromJson(detailMap);
        }
      }
      rethrow;
    }
  }

  @override
  Future<List<Map<String, Object?>>> listRecentEvaluations({
    int limit = 20,
  }) async {
    _requireAuthenticatedUser();
    final response = await _client.functions.invoke(
      'app-hub',
      body: <String, Object?>{
        'action': 'agent.list_prompt_evolutions',
        'limit': limit,
      },
    );
    final payload = normalizeJsonObject(
      response.data,
      'agent.list_prompt_evolutions',
    );
    final Object? rawRows = payload['evaluations'];
    if (rawRows is! List<Object?>) {
      throw const FormatException(
        'Missing or invalid List "evaluations" from app-hub.',
      );
    }
    final normalized = <Map<String, Object?>>[];
    for (final item in rawRows) {
      normalized.add(normalizeJsonObject(item, 'evaluations[]'));
    }
    return List<Map<String, Object?>>.unmodifiable(normalized);
  }
}
