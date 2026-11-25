import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/agent_sandbox_models.dart';

/// `ai-hub` (`agent.sandbox.*`) 経由の隔離サンドボックス＆監査永続化実装 (#2722)。
class SupabaseAgentSandboxRepository implements AgentSandboxRepository {
  SupabaseAgentSandboxRepository({
    SupabaseClient Function()? clientResolver,
  }) : _clientResolver = clientResolver ?? _defaultClient;

  final SupabaseClient Function() _clientResolver;

  static SupabaseClient _defaultClient() => Supabase.instance.client;

  Future<Map<String, Object?>> _invokeAiHub(
    Map<String, Object?> payload, {
    bool allow403Decision = false,
  }) async {
    final SupabaseClient client = _clientResolver();
    try {
      final FunctionResponse response = await client.functions.invoke(
        'ai-hub',
        body: payload,
      );
      final Object? raw = response.data;
      final Map<String, Object?> body = raw is Map<Object?, Object?>
          ? Map<String, Object?>.from(raw)
          : const <String, Object?>{};
      final String err = (body['error'] as String? ?? '').trim();
      if (allow403Decision && response.status == 403) {
        return body;
      }
      if (response.status >= 400 || err.isNotEmpty) {
        throw StateError(
          err.isNotEmpty ? err : 'Sandbox API error (${response.status})',
        );
      }
      return body;
    } on FunctionException catch (exc) {
      final Object? details = exc.details;
      final Map<String, Object?> detailMap = details is Map<Object?, Object?>
          ? Map<String, Object?>.from(details)
          : const <String, Object?>{};
      if (allow403Decision && exc.status == 403 && detailMap.isNotEmpty) {
        return detailMap;
      }
      final String err = (detailMap['error'] as String? ??
              exc.reasonPhrase ??
              'Sandbox API error (${exc.status})')
          .trim();
      throw StateError(
        err.isNotEmpty ? err : 'Sandbox API error (${exc.status})',
      );
    }
  }

  @override
  Future<AgentSandboxAuditSnapshot> fetchAuditSnapshot({
    String? decisionFilter,
  }) async {
    final Map<String, Object?> data = await _invokeAiHub(
      <String, Object?>{
        'action': 'agent.sandbox.audit_list',
        if ((decisionFilter ?? '').trim().isNotEmpty)
          'decision': decisionFilter!.trim(),
      },
    );

    final Object? rawAudits = data['audits'];
    final List<AgentSandboxAuditEntry> audits = rawAudits is List<Object?>
        ? rawAudits
            .whereType<Map<Object?, Object?>>()
            .map(
              (Map<Object?, Object?> item) => AgentSandboxAuditEntry.fromJson(
                Map<String, Object?>.from(item),
              ),
            )
            .toList(growable: false)
        : const <AgentSandboxAuditEntry>[];

    final Object? rawPolicies = data['policies'];
    final List<AgentSandboxPolicy> policies = rawPolicies is List<Object?>
        ? rawPolicies
            .whereType<Map<Object?, Object?>>()
            .map(
              (Map<Object?, Object?> item) => AgentSandboxPolicy.fromJson(
                Map<String, Object?>.from(item),
              ),
            )
            .toList(growable: false)
        : const <AgentSandboxPolicy>[];

    return AgentSandboxAuditSnapshot(audits: audits, policies: policies);
  }

  @override
  Future<AgentSandboxExecutionResult> evaluateOrExecuteIsolated({
    required String toolName,
    required String actorRole,
    required List<String> requestedScopes,
    required Map<String, Object?> toolArgs,
    required int retryAttempt,
    bool executeIsolated = true,
    String promptText = '',
  }) async {
    final Map<String, Object?> data = await _invokeAiHub(
      <String, Object?>{
        'action': executeIsolated
            ? 'agent.sandbox.execute_isolated'
            : 'agent.sandbox.evaluate',
        'tool_name': toolName.trim(),
        'actor_role': actorRole.trim(),
        'requested_scopes': requestedScopes,
        'tool_args': toolArgs,
        'retry_attempt': retryAttempt,
        if (promptText.trim().isNotEmpty) 'prompt_text': promptText.trim(),
      },
      allow403Decision: true,
    );

    final Object? rawDecision = data['decision'];
    final Map<String, Object?> decision = rawDecision is Map<Object?, Object?>
        ? Map<String, Object?>.from(rawDecision)
        : const <String, Object?>{};
    final Object? rawExec = data['execution'];
    final Map<String, Object?>? executionOutput =
        rawExec is Map<Object?, Object?>
            ? Map<String, Object?>.from(rawExec)
            : null;
    final Object? rawAudit = data['audit'];
    final AgentSandboxAuditEntry? auditEntry = rawAudit is Map<Object?, Object?>
        ? AgentSandboxAuditEntry.fromJson(
            Map<String, Object?>.from(rawAudit),
          )
        : null;

    final bool allowed = decision['allowed'] as bool? ?? false;
    return AgentSandboxExecutionResult(
      allowed: allowed,
      blockedCategory: SandboxBlockedCategory.fromWire(
        decision['blockedCategory'] as String?,
      ),
      blockedReason: (decision['blockedReason'] as String? ?? '').trim(),
      errorTrace: (decision['errorTrace'] as String? ?? '').trim(),
      executionOutput: executionOutput,
      auditEntry: auditEntry,
    );
  }
}
