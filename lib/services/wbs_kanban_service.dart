import 'package:supabase_flutter/supabase_flutter.dart';

/// The five user-facing lanes used by the project WBS kanban board.
enum WbsKanbanLane { pending, inProgress, review, completed, blocked }

extension WbsKanbanLanePresentation on WbsKanbanLane {
  String get label => switch (this) {
        WbsKanbanLane.pending => '未着手',
        WbsKanbanLane.inProgress => '進行中',
        WbsKanbanLane.review => 'レビュー中',
        WbsKanbanLane.completed => '完了',
        WbsKanbanLane.blocked => 'ブロック中',
      };
}

/// Builds the persisted WBS values for one kanban move.
///
/// The database has four task statuses. The fifth, review, is represented by
/// `status=in_progress`, `progress=100`, and `ai_review_status=requested`, which
/// is the existing WBS review-gate contract.
Map<String, dynamic> buildWbsKanbanUpdate({
  required WbsKanbanLane lane,
  required int currentProgress,
  String? recoveryPlan,
  DateTime? now,
}) {
  final progress = currentProgress.clamp(0, 100).toInt();
  final update = switch (lane) {
    WbsKanbanLane.pending => <String, dynamic>{
        'status': 'pending',
        'progress': 0,
        'ai_review_status': 'pending',
      },
    WbsKanbanLane.inProgress => <String, dynamic>{
        'status': 'in_progress',
        'progress': progress.clamp(1, 94).toInt(),
        'ai_review_status': 'pending',
      },
    WbsKanbanLane.review => <String, dynamic>{
        'status': 'in_progress',
        'progress': 100,
        'ai_review_status': 'requested',
      },
    WbsKanbanLane.completed => <String, dynamic>{
        'status': 'completed',
        'progress': 100,
        'ai_review_status': 'manual_override',
      },
    WbsKanbanLane.blocked => _blockedUpdate(
        progress: progress,
        recoveryPlan: recoveryPlan,
        now: now,
      ),
  };
  final plan = recoveryPlan?.trim() ?? '';
  if (lane != WbsKanbanLane.blocked && plan.isNotEmpty) {
    update['recovery_plan'] = plan;
    update['recovery_planned_at'] =
        (now ?? DateTime.now()).toUtc().toIso8601String();
  }
  return update;
}

Map<String, dynamic> _blockedUpdate({
  required int progress,
  required String? recoveryPlan,
  required DateTime? now,
}) {
  final plan = recoveryPlan?.trim() ?? '';
  if (plan.isEmpty) {
    throw ArgumentError.value(
      recoveryPlan,
      'recoveryPlan',
      'ブロック中へ移動するには回復計画が必要です',
    );
  }
  return <String, dynamic>{
    'status': 'blocked',
    'progress': progress.clamp(0, 99).toInt(),
    'ai_review_status': 'pending',
    'recovery_plan': plan,
    'recovery_planned_at': (now ?? DateTime.now()).toUtc().toIso8601String(),
  };
}

/// RLS-preserving writer for WBS kanban moves.
///
/// `wbs_tasks_admin_write` remains the authorization boundary: public users
/// can view the real WBS data, while only an authenticated administrator can
/// persist a move.
class WbsKanbanService {
  WbsKanbanService(this._client);

  final SupabaseClient _client;

  Future<Map<String, dynamic>> moveTask({
    required String taskId,
    required WbsKanbanLane lane,
    required int currentProgress,
    String? recoveryPlan,
  }) async {
    final update = buildWbsKanbanUpdate(
      lane: lane,
      currentProgress: currentProgress,
      recoveryPlan: recoveryPlan,
    );
    final row = await _client
        .from('wbs_tasks')
        .update(update)
        .eq('id', taskId)
        .select()
        .single();
    return Map<String, dynamic>.from(row);
  }
}
