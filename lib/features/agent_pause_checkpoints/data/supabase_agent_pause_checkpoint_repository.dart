import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/agent_pause_checkpoint_models.dart';

/// Supabase `agent_pause_checkpoints` テーブル向けの遅延解決リポジトリ実装。
class SupabaseAgentPauseCheckpointRepository
    implements AgentPauseCheckpointRepository {
  SupabaseAgentPauseCheckpointRepository({
    SupabaseClient Function()? clientResolver,
    DateTime Function()? nowProvider,
    bool Function()? isAdminOverride,
  })  : _clientResolver = clientResolver,
        _nowProvider = nowProvider ?? DateTime.now,
        _isAdminOverride = isAdminOverride;

  final SupabaseClient Function()? _clientResolver;
  final DateTime Function() _nowProvider;
  final bool Function()? _isAdminOverride;

  @override
  Future<bool> fetchIsAdmin() async {
    final bool Function()? override = _isAdminOverride;
    if (override != null) {
      return override();
    }
    final SupabaseClient? client = _tryResolveClient();
    final String? userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) {
      return false;
    }
    final Map<String, Object?>? profile = await client
        .from('user_profiles')
        .select('is_admin')
        .eq('user_id', userId)
        .maybeSingle();
    return profile?['is_admin'] as bool? ?? false;
  }

  static List<AgentPauseCheckpointRecord> buildSampleCheckpoints() {
    return const <AgentPauseCheckpointRecord>[
      AgentPauseCheckpointRecord(
        id: 'sample-checkpoint-paused',
        runKey: 'daily-brief-20261124',
        agentName: 'digest-coordinator',
        checkpointSeq: 3,
        pauseStatus: AgentPauseStatus.pausedLossless,
        usageRatioPct: 100.0,
        warning90ThresholdPct: 90.0,
        warning90Sent: true,
        silentPauseAlerted: true,
        pendingStep: 'step_3_publish_digest',
        snapshotSha256: 'a8d4e91f0c33b701',
        completedCount: 4,
        updatedAtIso: '2026-11-24T08:00:00Z',
      ),
      AgentPauseCheckpointRecord(
        id: 'sample-checkpoint-warning',
        runKey: 'competitor-watch-90',
        agentName: 'research-worker',
        checkpointSeq: 2,
        pauseStatus: AgentPauseStatus.warning90,
        usageRatioPct: 92.4,
        warning90ThresholdPct: 90.0,
        warning90Sent: true,
        silentPauseAlerted: false,
        pendingStep: 'step_2_score_sources',
        snapshotSha256: '5b19c0441129aa02',
        completedCount: 7,
        updatedAtIso: '2026-11-24T08:15:00Z',
      ),
    ];
  }

  @override
  Future<List<AgentPauseCheckpointRecord>> fetchCheckpoints() async {
    final SupabaseClient? client = _tryResolveClient();
    final String? userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) {
      return buildSampleCheckpoints();
    }

    final List<Object?> rows = await client
        .from('agent_pause_checkpoints')
        .select()
        .order('updated_at', ascending: false)
        .limit(20);

    return rows
        .whereType<Map<String, Object?>>()
        .map(AgentPauseCheckpointRecord.fromJson)
        .toList(growable: false);
  }

  @override
  Future<AgentPauseCheckpointRecord> saveLosslessPauseCheckpoint({
    required String runKey,
    required String agentName,
    required double usageRatioPct,
    required String pendingStep,
  }) async {
    final String nowIso = _nowProvider().toUtc().toIso8601String();
    final double clampedRatio = usageRatioPct < 0 ? 0.0 : usageRatioPct;
    final AgentPauseStatus nextStatus = clampedRatio >= 100.0
        ? AgentPauseStatus.pausedLossless
        : (clampedRatio >= 90.0
            ? AgentPauseStatus.warning90
            : AgentPauseStatus.running);
    final bool warnSent = clampedRatio >= 90.0;
    final bool silentAlerted = clampedRatio >= 100.0;

    final SupabaseClient? client = _tryResolveClient();
    final String? userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) {
      return AgentPauseCheckpointRecord(
        id: 'local-${runKey.trim()}',
        runKey: runKey.trim(),
        agentName: agentName.trim(),
        checkpointSeq: 1,
        pauseStatus: nextStatus,
        usageRatioPct: clampedRatio,
        warning90ThresholdPct: 90.0,
        warning90Sent: warnSent,
        silentPauseAlerted: silentAlerted,
        pendingStep: pendingStep.trim(),
        snapshotSha256: 'local-preview-digest',
        completedCount: 0,
        updatedAtIso: nowIso,
      );
    }

    final Map<String, Object?> inserted = await client
        .from('agent_pause_checkpoints')
        .insert(<String, Object?>{
          'user_id': userId,
          'run_key': runKey.trim(),
          'agent_name': agentName.trim(),
          'checkpoint_seq': 1,
          'usage_ratio_pct': clampedRatio,
          'warning_90_threshold_pct': 90.0,
          'pause_status': nextStatus.dbValue,
          'warning_90_sent': warnSent,
          'silent_pause_alerted': silentAlerted,
          'state_snapshot': <String, Object?>{
            'pending_step': pendingStep.trim(),
            'captured_at': nowIso,
            'completed_items': const <String>[],
          },
        })
        .select()
        .single();

    return AgentPauseCheckpointRecord.fromJson(inserted);
  }

  @override
  Future<AgentPauseCheckpointRecord> resumeCheckpoint({
    required AgentPauseCheckpointRecord record,
    required double replenishedUsagePct,
  }) async {
    if (!record.isLosslessPaused) {
      throw StateError('Only paused_lossless checkpoints can be resumed');
    }
    if (replenishedUsagePct >= 100.0) {
      throw ArgumentError('Usage ratio must be below 100% before resuming');
    }
    final bool isAdmin = await fetchIsAdmin();
    if (!isAdmin) {
      throw StateError('Administrator privilege required to resume checkpoint');
    }
    final String nowIso = _nowProvider().toUtc().toIso8601String();
    final SupabaseClient? client = _tryResolveClient();
    final String? userId = client?.auth.currentUser?.id;

    if (client == null || userId == null) {
      return record.copyWith(
        checkpointSeq: record.checkpointSeq + 1,
        pauseStatus: AgentPauseStatus.resumed,
        usageRatioPct: replenishedUsagePct,
        warning90Sent: replenishedUsagePct >= record.warning90ThresholdPct,
        resumedAtIso: nowIso,
        updatedAtIso: nowIso,
      );
    }

    final Map<String, Object?> updated = await client
        .from('agent_pause_checkpoints')
        .update(<String, Object?>{
          'checkpoint_seq': record.checkpointSeq + 1,
          'pause_status': AgentPauseStatus.resumed.dbValue,
          'usage_ratio_pct': replenishedUsagePct,
          'warning_90_sent':
              replenishedUsagePct >= record.warning90ThresholdPct,
          'resumed_by': userId,
          'resumed_at': nowIso,
        })
        .eq('id', record.id)
        .select()
        .single();

    return AgentPauseCheckpointRecord.fromJson(updated);
  }

  SupabaseClient? _tryResolveClient() {
    final SupabaseClient Function()? resolver = _clientResolver;
    if (resolver != null) {
      return resolver();
    }
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }
}
