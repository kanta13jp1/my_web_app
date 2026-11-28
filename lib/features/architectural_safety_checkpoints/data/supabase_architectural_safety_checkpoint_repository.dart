import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/architectural_safety_checkpoint_models.dart';

/// Edge Function (`ai-hub`) 経由で安全チェックポイントを操作するリポジトリ。
class SupabaseArchitecturalSafetyCheckpointRepository
    implements ArchitecturalSafetyCheckpointRepository {
  SupabaseArchitecturalSafetyCheckpointRepository({
    SupabaseClient Function()? clientResolver,
  }) : _clientResolver = clientResolver ?? _defaultClient;

  final SupabaseClient Function() _clientResolver;

  static SupabaseClient _defaultClient() => Supabase.instance.client;

  Future<Map<String, Object?>> _invokeAiHub(
    Map<String, Object?> payload,
  ) async {
    final SupabaseClient client = _clientResolver();
    final FunctionResponse response = await client.functions.invoke(
      'ai-hub',
      body: payload,
    );
    final Object? raw = response.data;
    final Map<String, Object?> body = raw is Map<Object?, Object?>
        ? Map<String, Object?>.from(raw)
        : const <String, Object?>{};
    final String errorText = (body['error'] as String? ?? '').trim();
    if (response.status >= 400 || errorText.isNotEmpty) {
      throw StateError(
        errorText.isNotEmpty
            ? errorText
            : 'Safety checkpoint request failed (${response.status})',
      );
    }
    return body;
  }

  @override
  Future<SafetyCheckpointFeed> fetchSafetyCheckpoints() async {
    final Map<String, Object?> data = await _invokeAiHub(
      const <String, Object?>{'action': 'agent.safety_checkpoint.list'},
    );
    final bool isAdmin = data['is_admin'] as bool? ?? false;
    final Object? rawList = data['checkpoints'];
    final List<SafetyCheckpointRecord> items = <SafetyCheckpointRecord>[];
    if (rawList is List<Object?>) {
      for (final Object? entry in rawList) {
        if (entry is Map<Object?, Object?>) {
          items.add(
            SafetyCheckpointRecord.fromJson(
              Map<String, Object?>.from(entry),
            ),
          );
        }
      }
    }
    return SafetyCheckpointFeed(isAdmin: isAdmin, checkpoints: items);
  }

  @override
  Future<SafetyCheckpointEvaluationResult> evaluateToolCall({
    required String toolName,
    required List<String> requestedScopes,
    required String actorRole,
    required String runKey,
    required String agentName,
    String pendingStep = '',
    int? githubIssueNumber,
    String? checkpointId,
  }) async {
    final Map<String, Object?> body = <String, Object?>{
      'action': 'agent.safety_checkpoint.evaluate',
      'tool_name': toolName.trim(),
      'requested_scopes': requestedScopes,
      'actor_role': actorRole.trim(),
      'run_key': runKey.trim(),
      'agent_name': agentName.trim(),
      if (pendingStep.trim().isNotEmpty) 'pending_step': pendingStep.trim(),
      if (githubIssueNumber != null) 'github_issue_number': githubIssueNumber,
      if ((checkpointId ?? '').trim().isNotEmpty)
        'checkpoint_id': checkpointId!.trim(),
    };
    final Map<String, Object?> data = await _invokeAiHub(body);
    return SafetyCheckpointEvaluationResult.fromJson(data);
  }

  @override
  Future<SafetyCheckpointRecord> approveCheckpoint({
    required SafetyCheckpointRecord record,
    required SafetyApprovalChannel channel,
    int? githubIssueNumber,
    String? approvalNote,
  }) async {
    final Map<String, Object?> body = <String, Object?>{
      'action': 'agent.safety_checkpoint.approve',
      'checkpoint_id': record.id,
      'approval_channel': channel.dbValue,
      if (githubIssueNumber != null) 'github_issue_number': githubIssueNumber,
      if ((approvalNote ?? '').trim().isNotEmpty)
        'approval_note': approvalNote!.trim(),
    };
    final Map<String, Object?> data = await _invokeAiHub(body);
    final Object? rawCheckpoint = data['checkpoint'];
    if (rawCheckpoint is! Map<Object?, Object?>) {
      throw StateError('Missing checkpoint in approval response');
    }
    return SafetyCheckpointRecord.fromJson(
      Map<String, Object?>.from(rawCheckpoint),
    );
  }

  @override
  Future<SafetyCheckpointRecord> rejectCheckpoint({
    required SafetyCheckpointRecord record,
    String reason = '',
  }) async {
    final Map<String, Object?> body = <String, Object?>{
      'action': 'agent.safety_checkpoint.reject',
      'checkpoint_id': record.id,
      if (reason.trim().isNotEmpty) 'reason': reason.trim(),
    };
    final Map<String, Object?> data = await _invokeAiHub(body);
    final Object? rawCheckpoint = data['checkpoint'];
    if (rawCheckpoint is! Map<Object?, Object?>) {
      throw StateError('Missing checkpoint in reject response');
    }
    return SafetyCheckpointRecord.fromJson(
      Map<String, Object?>.from(rawCheckpoint),
    );
  }
}
