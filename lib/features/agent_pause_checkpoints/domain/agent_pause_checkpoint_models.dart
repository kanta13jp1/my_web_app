import 'package:flutter/foundation.dart';

/// エージェント一時停止チェックポイントの状態遷移ステージ。
enum AgentPauseStatus {
  running('running', '稼働中'),
  warning90('warning_90', '90%早期警告'),
  pausedLossless('paused_lossless', '無欠損一時停止'),
  resumed('resumed', '再開済み'),
  failed('failed', '失敗終了');

  const AgentPauseStatus(this.dbValue, this.labelJa);

  final String dbValue;
  final String labelJa;

  static AgentPauseStatus fromDb(String? raw) {
    final String normalized = (raw ?? '').trim().toLowerCase();
    for (final AgentPauseStatus value in AgentPauseStatus.values) {
      if (value.dbValue == normalized) {
        return value;
      }
    }
    return AgentPauseStatus.running;
  }
}

/// エージェント実行の保全状態スナップショットと 90%/100% 保護メタデータ。
@immutable
class AgentPauseCheckpointRecord {
  const AgentPauseCheckpointRecord({
    required this.id,
    required this.runKey,
    required this.agentName,
    required this.checkpointSeq,
    required this.pauseStatus,
    required this.usageRatioPct,
    this.warning90ThresholdPct = 90.0,
    this.warning90Sent = false,
    this.silentPauseAlerted = false,
    this.pendingStep = '',
    this.snapshotSha256 = '',
    this.completedCount = 0,
    this.resumedAtIso,
    this.updatedAtIso = '',
  });

  final String id;
  final String runKey;
  final String agentName;
  final int checkpointSeq;
  final AgentPauseStatus pauseStatus;
  final double usageRatioPct;
  final double warning90ThresholdPct;
  final bool warning90Sent;
  final bool silentPauseAlerted;
  final String pendingStep;
  final String snapshotSha256;
  final int completedCount;
  final String? resumedAtIso;
  final String updatedAtIso;

  bool get isLosslessPaused => pauseStatus == AgentPauseStatus.pausedLossless;

  bool get isWarning90OrAbove =>
      usageRatioPct >= warning90ThresholdPct || warning90Sent;

  AgentPauseCheckpointRecord copyWith({
    int? checkpointSeq,
    AgentPauseStatus? pauseStatus,
    double? usageRatioPct,
    bool? warning90Sent,
    bool? silentPauseAlerted,
    String? pendingStep,
    String? snapshotSha256,
    int? completedCount,
    String? resumedAtIso,
    String? updatedAtIso,
  }) {
    return AgentPauseCheckpointRecord(
      id: id,
      runKey: runKey,
      agentName: agentName,
      checkpointSeq: checkpointSeq ?? this.checkpointSeq,
      pauseStatus: pauseStatus ?? this.pauseStatus,
      usageRatioPct: usageRatioPct ?? this.usageRatioPct,
      warning90ThresholdPct: warning90ThresholdPct,
      warning90Sent: warning90Sent ?? this.warning90Sent,
      silentPauseAlerted: silentPauseAlerted ?? this.silentPauseAlerted,
      pendingStep: pendingStep ?? this.pendingStep,
      snapshotSha256: snapshotSha256 ?? this.snapshotSha256,
      completedCount: completedCount ?? this.completedCount,
      resumedAtIso: resumedAtIso ?? this.resumedAtIso,
      updatedAtIso: updatedAtIso ?? this.updatedAtIso,
    );
  }

  factory AgentPauseCheckpointRecord.fromJson(Map<String, Object?> json) {
    final Object? rawSnapshot = json['state_snapshot'];
    final Map<String, Object?> snapshot = rawSnapshot is Map<String, Object?>
        ? rawSnapshot
        : const <String, Object?>{};
    final Object? rawCompleted = snapshot['completed_items'];
    final int completed =
        rawCompleted is List<Object?> ? rawCompleted.length : 0;

    return AgentPauseCheckpointRecord(
      id: (json['id'] as String? ?? '').trim(),
      runKey: (json['run_key'] as String? ?? '').trim(),
      agentName: (json['agent_name'] as String? ?? '').trim(),
      checkpointSeq: (json['checkpoint_seq'] as num?)?.toInt() ?? 1,
      pauseStatus: AgentPauseStatus.fromDb(json['pause_status'] as String?),
      usageRatioPct: (json['usage_ratio_pct'] as num?)?.toDouble() ?? 0.0,
      warning90ThresholdPct:
          (json['warning_90_threshold_pct'] as num?)?.toDouble() ?? 90.0,
      warning90Sent: json['warning_90_sent'] as bool? ?? false,
      silentPauseAlerted: json['silent_pause_alerted'] as bool? ?? false,
      pendingStep: (snapshot['pending_step'] as String? ?? '').trim(),
      snapshotSha256: (snapshot['snapshot_sha256'] as String? ?? '').trim(),
      completedCount: completed,
      resumedAtIso: (json['resumed_at'] as String?)?.trim(),
      updatedAtIso: (json['updated_at'] as String? ?? '').trim(),
    );
  }
}

/// エージェントチェックポイントの永続化・一時停止/再開リポジトリ契約。
abstract class AgentPauseCheckpointRepository {
  Future<bool> fetchIsAdmin();

  Future<List<AgentPauseCheckpointRecord>> fetchCheckpoints();

  Future<AgentPauseCheckpointRecord> saveLosslessPauseCheckpoint({
    required String runKey,
    required String agentName,
    required double usageRatioPct,
    required String pendingStep,
  });

  Future<AgentPauseCheckpointRecord> resumeCheckpoint({
    required AgentPauseCheckpointRecord record,
    required double replenishedUsagePct,
  });
}
