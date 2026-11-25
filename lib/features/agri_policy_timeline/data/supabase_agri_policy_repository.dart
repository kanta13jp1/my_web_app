import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/agri_policy_models.dart';

/// Supabase-backed repository for `app-hub` `agri_policy.*` actions (#2755).
class SupabaseAgriPolicyRepository implements AgriPolicyRepository {
  SupabaseAgriPolicyRepository({final SupabaseClient? client})
      : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _resolvedClient => _client ?? Supabase.instance.client;

  void _requireAuthenticatedUser(final SupabaseClient client) {
    if (client.auth.currentUser == null) {
      throw StateError('農政改革タイムラインを利用するにはログインが必要です。');
    }
  }

  Future<Map<String, Object?>> _invokeHub(
    final Map<String, Object?> body,
  ) async {
    final client = _resolvedClient;
    _requireAuthenticatedUser(client);
    try {
      final response = await client.functions.invoke(
        'app-hub',
        body: body,
      );
      final payload = normalizeAgriJsonMap(response.data);
      if (payload['success'] == false) {
        throw StateError(
          payload['error']?.toString() ?? '農政データの取得に失敗しました。',
        );
      }
      return payload;
    } on FunctionException catch (error) {
      final details = normalizeAgriJsonMap(error.details);
      final serverMessage = details['error']?.toString().trim();
      throw StateError(
        serverMessage != null && serverMessage.isNotEmpty
            ? serverMessage
            : 'Edge Function エラー (${error.status})',
      );
    }
  }

  @override
  Future<AgriPolicyTimelineSnapshot> fetchTimeline({
    final String? query,
    final String? tag,
    final AgriPolicyPhase? phase,
    final FactCheckStatus? factCheckStatus,
    final bool seedIfEmpty = true,
  }) async {
    final cleanQuery = query?.trim() ?? '';
    final cleanTag = tag?.trim() ?? '';
    final payload = await _invokeHub(<String, Object?>{
      'action': 'agri_policy.list',
      'seed_if_empty': seedIfEmpty,
      if (cleanQuery.isNotEmpty) 'query': cleanQuery,
      if (cleanTag.isNotEmpty) 'tag': cleanTag,
      if (phase != null) 'phase': phase.wireValue,
      if (factCheckStatus != null)
        'fact_check_status': factCheckStatus.wireValue,
    });
    return AgriPolicyTimelineSnapshot.fromJson(payload);
  }

  @override
  Future<AgriPolicyEvent> createEvent({
    required final String eventDate,
    required final String title,
    required final String summary,
    required final List<String> tags,
    required final List<String> relatedNodes,
    required final FactCheckStatus factCheckStatus,
    required final String sourceCitation,
    required final String policyImpactNotes,
  }) async {
    final payload = await _invokeHub(<String, Object?>{
      'action': 'agri_policy.create',
      'event_date': eventDate.trim(),
      'title': title.trim(),
      'summary': summary.trim(),
      'tags': tags,
      'related_nodes': relatedNodes,
      'fact_check_status': factCheckStatus.wireValue,
      'source_citation': sourceCitation.trim(),
      'policy_impact_notes': policyImpactNotes.trim(),
    });
    return AgriPolicyEvent.fromJson(
      normalizeAgriJsonMap(payload['event']),
    );
  }

  @override
  Future<AgriPolicyEvent> updateFactCheck({
    required final String id,
    required final FactCheckStatus factCheckStatus,
    required final String sourceCitation,
    required final String policyImpactNotes,
  }) async {
    final payload = await _invokeHub(<String, Object?>{
      'action': 'agri_policy.update',
      'id': id.trim(),
      'fact_check_status': factCheckStatus.wireValue,
      'source_citation': sourceCitation.trim(),
      'policy_impact_notes': policyImpactNotes.trim(),
    });
    return AgriPolicyEvent.fromJson(
      normalizeAgriJsonMap(payload['event']),
    );
  }
}
