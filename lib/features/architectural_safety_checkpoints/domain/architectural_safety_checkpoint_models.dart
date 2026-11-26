/// ドメインモデル: Architectural Safety Checkpoints (#2712)。
enum SafetyApprovalChannel {
  adminUi('admin_ui', '管理UI承認'),
  githubIssue('github_issue', 'GitHub Issue承認');

  const SafetyApprovalChannel(this.dbValue, this.labelJa);

  final String dbValue;
  final String labelJa;

  static SafetyApprovalChannel? fromDb(String? raw) {
    final String normalized = (raw ?? '').trim().toLowerCase();
    for (final SafetyApprovalChannel value in SafetyApprovalChannel.values) {
      if (value.dbValue == normalized) {
        return value;
      }
    }
    return null;
  }
}

enum SafetyCheckpointStatus {
  pausedLossless('paused_lossless', '承認待ち停止'),
  resumed('resumed', '承認済み再開'),
  failed('failed', '拒否・停止'),
  running('running', '実行中');

  const SafetyCheckpointStatus(this.dbValue, this.labelJa);

  final String dbValue;
  final String labelJa;

  static SafetyCheckpointStatus fromDb(String? raw) {
    final String normalized = (raw ?? '').trim().toLowerCase();
    for (final SafetyCheckpointStatus value in SafetyCheckpointStatus.values) {
      if (value.dbValue == normalized) {
        return value;
      }
    }
    return SafetyCheckpointStatus.pausedLossless;
  }
}

class SafetyCheckpointRecord {
  const SafetyCheckpointRecord({
    required this.id,
    required this.runKey,
    required this.agentName,
    required this.toolName,
    required this.requestedScopes,
    required this.highRiskScopes,
    required this.pauseStatus,
    required this.approvalState,
    required this.pendingStep,
    required this.snapshotSha256,
    required this.operationDigest,
    this.approvalChannel,
    this.approvedByActor,
    this.githubIssueNumber,
    this.githubRepo,
    this.resumedAtIso,
    this.updatedAtIso = '',
  });

  final String id;
  final String runKey;
  final String agentName;
  final String toolName;
  final List<String> requestedScopes;
  final List<String> highRiskScopes;
  final SafetyCheckpointStatus pauseStatus;
  final String approvalState;
  final SafetyApprovalChannel? approvalChannel;
  final String? approvedByActor;
  final int? githubIssueNumber;
  final String? githubRepo;
  final String pendingStep;
  final String snapshotSha256;
  final String operationDigest;
  final String? resumedAtIso;
  final String updatedAtIso;

  bool get isAwaitingApproval =>
      pauseStatus == SafetyCheckpointStatus.pausedLossless &&
      approvalState != 'rejected';

  bool get isResumed =>
      pauseStatus == SafetyCheckpointStatus.resumed &&
      approvalState == 'approved';

  bool get isRejected =>
      pauseStatus == SafetyCheckpointStatus.failed ||
      approvalState == 'rejected';

  SafetyCheckpointRecord copyWith({
    SafetyCheckpointStatus? pauseStatus,
    String? approvalState,
    SafetyApprovalChannel? approvalChannel,
    String? approvedByActor,
    int? githubIssueNumber,
    String? githubRepo,
    String? resumedAtIso,
    String? updatedAtIso,
  }) {
    return SafetyCheckpointRecord(
      id: id,
      runKey: runKey,
      agentName: agentName,
      toolName: toolName,
      requestedScopes: requestedScopes,
      highRiskScopes: highRiskScopes,
      pauseStatus: pauseStatus ?? this.pauseStatus,
      approvalState: approvalState ?? this.approvalState,
      approvalChannel: approvalChannel ?? this.approvalChannel,
      approvedByActor: approvedByActor ?? this.approvedByActor,
      githubIssueNumber: githubIssueNumber ?? this.githubIssueNumber,
      githubRepo: githubRepo ?? this.githubRepo,
      pendingStep: pendingStep,
      snapshotSha256: snapshotSha256,
      operationDigest: operationDigest,
      resumedAtIso: resumedAtIso ?? this.resumedAtIso,
      updatedAtIso: updatedAtIso ?? this.updatedAtIso,
    );
  }

  factory SafetyCheckpointRecord.fromJson(Map<String, Object?> json) {
    final List<String> requested = _stringList(json['requested_scopes']);
    final List<String> highRisk = _stringList(json['high_risk_scopes']);
    final Object? rawIssue = json['github_issue_number'];
    final int? issueNum = rawIssue is num ? rawIssue.toInt() : null;

    return SafetyCheckpointRecord(
      id: (json['id'] as String? ?? '').trim(),
      runKey: (json['run_key'] as String? ?? '').trim(),
      agentName: (json['agent_name'] as String? ?? '').trim(),
      toolName: (json['tool_name'] as String? ?? '').trim(),
      requestedScopes: requested,
      highRiskScopes: highRisk,
      pauseStatus: SafetyCheckpointStatus.fromDb(
        json['pause_status'] as String?,
      ),
      approvalState:
          (json['approval_state'] as String? ?? 'awaiting_admin_approval')
              .trim(),
      approvalChannel: SafetyApprovalChannel.fromDb(
        json['approval_channel'] as String?,
      ),
      approvedByActor: (json['approved_by_actor'] as String?)?.trim(),
      githubIssueNumber: issueNum,
      githubRepo: (json['github_repo'] as String?)?.trim(),
      pendingStep: (json['pending_step'] as String? ?? '').trim(),
      snapshotSha256: (json['snapshot_sha256'] as String? ?? '').trim(),
      operationDigest: (json['operation_digest'] as String? ?? '').trim(),
      resumedAtIso: (json['resumed_at'] as String?)?.trim(),
      updatedAtIso: (json['updated_at'] as String? ?? '').trim(),
    );
  }

  static List<String> _stringList(Object? value) {
    if (value is! List<Object?>) {
      return const <String>[];
    }
    return value
        .map((Object? item) => (item ?? '').toString().trim())
        .where((String item) => item.isNotEmpty)
        .toList(growable: false);
  }
}

class SafetyCheckpointEvaluationResult {
  const SafetyCheckpointEvaluationResult({
    required this.decision,
    required this.executionAllowed,
    required this.pauseRequired,
    this.blockedReason,
    this.checkpoint,
  });

  final String decision;
  final bool executionAllowed;
  final bool pauseRequired;
  final String? blockedReason;
  final SafetyCheckpointRecord? checkpoint;

  factory SafetyCheckpointEvaluationResult.fromJson(
    Map<String, Object?> json,
  ) {
    final Object? rawCheckpoint = json['checkpoint'];
    SafetyCheckpointRecord? parsedCheckpoint;
    if (rawCheckpoint is Map<Object?, Object?>) {
      parsedCheckpoint = SafetyCheckpointRecord.fromJson(
        Map<String, Object?>.from(rawCheckpoint),
      );
    }
    return SafetyCheckpointEvaluationResult(
      decision: (json['decision'] as String? ?? '').trim(),
      executionAllowed: json['execution_allowed'] as bool? ?? false,
      pauseRequired: json['pause_required'] as bool? ?? false,
      blockedReason: (json['blocked_reason'] as String?)?.trim(),
      checkpoint: parsedCheckpoint,
    );
  }
}

class SafetyCheckpointFeed {
  const SafetyCheckpointFeed({
    required this.isAdmin,
    required this.checkpoints,
  });

  final bool isAdmin;
  final List<SafetyCheckpointRecord> checkpoints;
}

/// Architectural Safety Checkpoints リポジトリ契約。
abstract class ArchitecturalSafetyCheckpointRepository {
  Future<SafetyCheckpointFeed> fetchSafetyCheckpoints();

  Future<SafetyCheckpointEvaluationResult> evaluateToolCall({
    required String toolName,
    required List<String> requestedScopes,
    required String actorRole,
    required String runKey,
    required String agentName,
    String pendingStep = '',
    int? githubIssueNumber,
    String? checkpointId,
  });

  Future<SafetyCheckpointRecord> approveCheckpoint({
    required SafetyCheckpointRecord record,
    required SafetyApprovalChannel channel,
    int? githubIssueNumber,
    String? approvalNote,
  });

  Future<SafetyCheckpointRecord> rejectCheckpoint({
    required SafetyCheckpointRecord record,
    String reason = '',
  });
}
