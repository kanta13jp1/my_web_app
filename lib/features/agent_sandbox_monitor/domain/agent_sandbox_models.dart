/// エージェント隔離サンドボックス・セキュリティ監視ドメインモデル (#2722)。
enum SandboxBlockedCategory {
  none('none', '許可済み'),
  hostFilesystemAccess('host_filesystem_access', 'ホストFS遮断'),
  prodDbAccess('prod_db_access', '本番DB遮断'),
  ssrfMetadata('ssrf_metadata', 'SSRF/メタデータ遮断'),
  promptInjection('prompt_injection', 'インジェクション検知'),
  excessiveRetries('excessive_retries', '過剰リトライ異常'),
  invalidToolArgs('invalid_tool_args', '不正ツール引数'),
  leastPrivilegeDenied('least_privilege_denied', '最小特権拒否'),
  sandboxEscape('sandbox_escape', '脱出試行遮断');

  const SandboxBlockedCategory(this.wireValue, this.labelJa);

  final String wireValue;
  final String labelJa;

  static SandboxBlockedCategory fromWire(String? raw) {
    final String normalized = (raw ?? '').trim().toLowerCase();
    for (final SandboxBlockedCategory value in SandboxBlockedCategory.values) {
      if (value.wireValue == normalized) {
        return value;
      }
    }
    return SandboxBlockedCategory.none;
  }
}

enum SandboxNetworkMode {
  none('none', '外部通信遮断 (deny-all)'),
  allowlistOnly('allowlist_only', '許可リストのみ');

  const SandboxNetworkMode(this.wireValue, this.labelJa);

  final String wireValue;
  final String labelJa;

  static SandboxNetworkMode fromWire(String? raw) {
    final String normalized = (raw ?? '').trim().toLowerCase();
    for (final SandboxNetworkMode value in SandboxNetworkMode.values) {
      if (value.wireValue == normalized) {
        return value;
      }
    }
    return SandboxNetworkMode.none;
  }
}

class AgentSandboxPolicy {
  const AgentSandboxPolicy({
    required this.sandboxProfile,
    required this.allowHostFs,
    required this.allowProdDb,
    required this.networkEgressMode,
    required this.maxRetriesPerTool,
    required this.maxBurstPerWindow,
    required this.allowedTools,
  });

  final String sandboxProfile;
  final bool allowHostFs;
  final bool allowProdDb;
  final SandboxNetworkMode networkEgressMode;
  final int maxRetriesPerTool;
  final int maxBurstPerWindow;
  final List<String> allowedTools;

  factory AgentSandboxPolicy.fromJson(Map<String, Object?> json) {
    final Object? rawTools = json['allowed_tools'];
    final List<String> tools = rawTools is List<Object?>
        ? rawTools
            .map((Object? item) => (item ?? '').toString().trim())
            .where((String s) => s.isNotEmpty)
            .toList(growable: false)
        : const <String>[
            'sandbox.json_validate',
            'sandbox.text_metrics',
            'sandbox.math_eval',
          ];

    return AgentSandboxPolicy(
      sandboxProfile:
          (json['sandbox_profile'] as String? ?? 'isolated_worker').trim(),
      allowHostFs: json['allow_host_fs'] as bool? ?? false,
      allowProdDb: json['allow_prod_db'] as bool? ?? false,
      networkEgressMode: SandboxNetworkMode.fromWire(
        json['network_egress_mode'] as String?,
      ),
      maxRetriesPerTool: (json['max_retries_per_tool'] as num?)?.toInt() ?? 3,
      maxBurstPerWindow: (json['max_burst_per_window'] as num?)?.toInt() ?? 10,
      allowedTools: List<String>.unmodifiable(tools),
    );
  }
}

class AgentSandboxAuditEntry {
  const AgentSandboxAuditEntry({
    required this.id,
    required this.sessionId,
    required this.sandboxId,
    required this.actorRole,
    required this.toolName,
    required this.actionKind,
    required this.decision,
    required this.blockedCategory,
    required this.blockedReason,
    required this.retryAttempt,
    required this.anomalyFlags,
    required this.errorTrace,
    required this.latencyMs,
    this.createdAtIso = '',
  });

  final String id;
  final String sessionId;
  final String sandboxId;
  final String actorRole;
  final String toolName;
  final String actionKind;
  final String decision;
  final SandboxBlockedCategory blockedCategory;
  final String blockedReason;
  final int retryAttempt;
  final List<String> anomalyFlags;
  final String errorTrace;
  final int latencyMs;
  final String createdAtIso;

  bool get isBlocked => decision == 'blocked';

  factory AgentSandboxAuditEntry.fromJson(Map<String, Object?> json) {
    final Object? rawFlags = json['anomaly_flags'];
    final List<String> parsedFlags = rawFlags is List<Object?>
        ? rawFlags
            .map((Object? item) => (item ?? '').toString().trim())
            .where((String s) => s.isNotEmpty)
            .toList(growable: false)
        : const <String>[];

    return AgentSandboxAuditEntry(
      id: (json['id'] as String? ?? '').trim(),
      sessionId: (json['session_id'] as String? ?? '').trim(),
      sandboxId: (json['sandbox_id'] as String? ?? 'isolated_worker').trim(),
      actorRole:
          (json['actor_role'] as String? ?? 'generated_ui_sandbox').trim(),
      toolName: (json['tool_name'] as String? ?? '').trim(),
      actionKind:
          (json['action_kind'] as String? ?? 'sandbox_preflight').trim(),
      decision: (json['decision'] as String? ?? 'blocked').trim(),
      blockedCategory: SandboxBlockedCategory.fromWire(
        json['blocked_category'] as String?,
      ),
      blockedReason: (json['blocked_reason'] as String? ?? '').trim(),
      retryAttempt: (json['retry_attempt'] as num?)?.toInt() ?? 0,
      anomalyFlags: List<String>.unmodifiable(parsedFlags),
      errorTrace: (json['error_trace'] as String? ?? '').trim(),
      latencyMs: (json['latency_ms'] as num?)?.toInt() ?? 0,
      createdAtIso: (json['created_at'] as String? ?? '').trim(),
    );
  }
}

class AgentSandboxExecutionResult {
  const AgentSandboxExecutionResult({
    required this.allowed,
    required this.blockedCategory,
    required this.blockedReason,
    required this.errorTrace,
    required this.executionOutput,
    required this.auditEntry,
  });

  final bool allowed;
  final SandboxBlockedCategory blockedCategory;
  final String blockedReason;
  final String errorTrace;
  final Map<String, Object?>? executionOutput;
  final AgentSandboxAuditEntry? auditEntry;
}

class AgentSandboxAuditSnapshot {
  const AgentSandboxAuditSnapshot({
    required this.audits,
    required this.policies,
  });

  final List<AgentSandboxAuditEntry> audits;
  final List<AgentSandboxPolicy> policies;
}

/// エージェント隔離サンドボックス・セキュリティ監査リポジトリ契約 (#2722)。
abstract class AgentSandboxRepository {
  Future<AgentSandboxAuditSnapshot> fetchAuditSnapshot({
    String? decisionFilter,
  });

  Future<AgentSandboxExecutionResult> evaluateOrExecuteIsolated({
    required String toolName,
    required String actorRole,
    required List<String> requestedScopes,
    required Map<String, Object?> toolArgs,
    required int retryAttempt,
    bool executeIsolated = true,
    String promptText = '',
  });
}
