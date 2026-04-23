import 'package:supabase_flutter/supabase_flutter.dart';

class SelfDevinControlTowerSnapshot {
  final double readiness;
  final int openFeatureRequestCount;
  final int blockedTaskCount;
  final int activeLaneCount;
  final int healthyLoopCount;
  final int totalLoopCount;
  final List<SelfDevinLaneSnapshot> lanes;
  final List<SelfDevinLoopSnapshot> loops;
  final String nextActionTitle;
  final String nextActionDetail;

  const SelfDevinControlTowerSnapshot({
    required this.readiness,
    required this.openFeatureRequestCount,
    required this.blockedTaskCount,
    required this.activeLaneCount,
    required this.healthyLoopCount,
    required this.totalLoopCount,
    required this.lanes,
    required this.loops,
    required this.nextActionTitle,
    required this.nextActionDetail,
  });
}

class SelfDevinLaneSnapshot {
  final String id;
  final String label;
  final int activeTasks;
  final int blockedTasks;
  final int overdueTasks;
  final int staleTasks;
  final int featureRequestTasks;
  final int highPriorityTasks;
  final int averageProgress;

  const SelfDevinLaneSnapshot({
    required this.id,
    required this.label,
    required this.activeTasks,
    required this.blockedTasks,
    required this.overdueTasks,
    required this.staleTasks,
    required this.featureRequestTasks,
    required this.highPriorityTasks,
    required this.averageProgress,
  });

  bool get needsAttention =>
      blockedTasks > 0 || overdueTasks > 0 || staleTasks > 0;

  String get healthLabel {
    if (activeTasks == 0) return 'Idle';
    if (blockedTasks > 0 || overdueTasks > 0) return 'Rescue';
    if (staleTasks > 0) return 'Watch';
    return 'Stable';
  }
}

class SelfDevinLoopSnapshot {
  final String id;
  final String label;
  final String cadenceLabel;
  final String status;
  final String detail;
  final DateTime? lastRunAt;

  const SelfDevinLoopSnapshot({
    required this.id,
    required this.label,
    required this.cadenceLabel,
    required this.status,
    required this.detail,
    required this.lastRunAt,
  });

  bool get isHealthy => status == 'healthy' || status == 'running';
}

class SelfDevinControlTowerService {
  const SelfDevinControlTowerService();

  static const List<_LaneDef> _laneDefs = <_LaneDef>[
    _LaneDef(id: 'vscode', label: 'VSCode'),
    _LaneDef(id: 'web', label: 'WEB'),
    _LaneDef(id: 'windows', label: 'Win'),
    _LaneDef(id: 'powershell', label: 'PowerShell'),
  ];

  static const List<_LoopDef> _loopDefs = <_LoopDef>[
    _LoopDef(
      id: 'cs-check',
      label: 'CS / health loop',
      cadenceLabel: 'hourly',
      fallbackDetail: 'Configured in .github/workflows/cs-check.yml',
      staleAfter: Duration(hours: 3),
    ),
    _LoopDef(
      id: 'github-issue-fix',
      label: 'Issue -> branch -> draft PR',
      cadenceLabel: 'daily 10:00 JST',
      fallbackDetail: 'Configured in .github/workflows/github-issue-fix.yml',
      staleAfter: Duration(hours: 36),
    ),
    _LoopDef(
      id: 'ci-auto-fix',
      label: 'CI self-heal',
      cadenceLabel: 'workflow_run',
      fallbackDetail: 'Configured in .github/workflows/ci-auto-fix.yml',
    ),
    _LoopDef(
      id: 'infra-health-check',
      label: 'Infra guard',
      cadenceLabel: 'scheduled',
      fallbackDetail: 'Configured in .github/workflows/infra-health-check.yml',
      staleAfter: Duration(hours: 36),
    ),
  ];

  Future<SelfDevinControlTowerSnapshot> load({
    SupabaseClient? supabaseClient,
  }) async {
    final supabase = supabaseClient ?? Supabase.instance.client;
    final results = await Future.wait<dynamic>(<Future<dynamic>>[
      supabase.from('wbs_tasks').select(
            'title, category, instance, owner_instance, status, progress, end_date, priority, updated_at',
          ),
      supabase
          .from('schedule_task_runs')
          .select('task_id, status, started_at, summary, error_message')
          .order('started_at', ascending: false)
          .limit(120),
    ]);

    return buildSnapshot(
      rawTasks: List<Map<String, dynamic>>.from(results[0] as List<dynamic>),
      rawRuns: List<Map<String, dynamic>>.from(results[1] as List<dynamic>),
      now: DateTime.now(),
    );
  }

  static SelfDevinControlTowerSnapshot buildSnapshot({
    required List<Map<String, dynamic>> rawTasks,
    required List<Map<String, dynamic>> rawRuns,
    DateTime? now,
  }) {
    final effectiveNow = now ?? DateTime.now();
    final taskRecords = rawTasks.map(_TaskRecord.fromMap).toList();
    final runRecords = rawRuns.map(_RunRecord.fromMap).toList();
    final loops = _buildLoops(runRecords, effectiveNow);
    final lanes = _buildLanes(taskRecords, effectiveNow);

    final openFeatureRequestCount = lanes.fold<int>(
      0,
      (int sum, SelfDevinLaneSnapshot lane) => sum + lane.featureRequestTasks,
    );
    final blockedTaskCount = lanes.fold<int>(
      0,
      (int sum, SelfDevinLaneSnapshot lane) => sum + lane.blockedTasks,
    );
    final activeLaneCount = lanes
        .where((SelfDevinLaneSnapshot lane) => lane.activeTasks > 0)
        .length;
    final healthyLoopCount =
        loops.where((SelfDevinLoopSnapshot loop) => loop.isHealthy).length;
    final healthyLaneCount = lanes
        .where((SelfDevinLaneSnapshot lane) => !lane.needsAttention)
        .length;

    final readiness = (((healthyLoopCount / _loopDefs.length) * 0.55) +
            ((healthyLaneCount / _laneDefs.length) * 0.45) -
            (blockedTaskCount.clamp(0, 4) * 0.05))
        .clamp(0.0, 1.0);

    final nextLane = _pickNextLane(lanes);
    final nextActionTitle = nextLane == null
        ? '4 lanes are stable'
        : nextLane.blockedTasks > 0 || nextLane.overdueTasks > 0
            ? '${nextLane.label} lane needs rescue first'
            : '${nextLane.label} lane is the next driver';
    final nextActionDetail = nextLane == null
        ? 'No blocked or overdue work. The orchestration loop can keep pulling the next feature request.'
        : _buildNextActionDetail(nextLane);

    return SelfDevinControlTowerSnapshot(
      readiness: readiness,
      openFeatureRequestCount: openFeatureRequestCount,
      blockedTaskCount: blockedTaskCount,
      activeLaneCount: activeLaneCount,
      healthyLoopCount: healthyLoopCount,
      totalLoopCount: _loopDefs.length,
      lanes: lanes,
      loops: loops,
      nextActionTitle: nextActionTitle,
      nextActionDetail: nextActionDetail,
    );
  }

  static List<SelfDevinLoopSnapshot> _buildLoops(
    List<_RunRecord> runs,
    DateTime now,
  ) {
    final latestRuns = <String, _RunRecord>{};
    for (final _RunRecord run in runs) {
      latestRuns.putIfAbsent(run.taskId, () => run);
    }

    return _loopDefs.map((final _LoopDef def) {
      final _RunRecord? run = latestRuns[def.id];
      if (run == null) {
        return SelfDevinLoopSnapshot(
          id: def.id,
          label: def.label,
          cadenceLabel: def.cadenceLabel,
          status: 'configured',
          detail: def.fallbackDetail,
          lastRunAt: null,
        );
      }

      var normalizedStatus = switch (run.status) {
        'success' => 'healthy',
        'skipped' => 'healthy',
        'running' => 'running',
        'error' => 'error',
        _ => 'watch',
      };

      if (def.staleAfter != null &&
          run.startedAt != null &&
          now.isAfter(run.startedAt!) &&
          now.difference(run.startedAt!) > def.staleAfter! &&
          normalizedStatus == 'healthy') {
        normalizedStatus = 'watch';
      }

      final detail = (run.summary?.trim().isNotEmpty ?? false)
          ? run.summary!.trim()
          : (run.errorMessage?.trim().isNotEmpty ?? false)
              ? run.errorMessage!.trim()
              : def.fallbackDetail;

      return SelfDevinLoopSnapshot(
        id: def.id,
        label: def.label,
        cadenceLabel: def.cadenceLabel,
        status: normalizedStatus,
        detail: detail,
        lastRunAt: run.startedAt,
      );
    }).toList();
  }

  static List<SelfDevinLaneSnapshot> _buildLanes(
    List<_TaskRecord> tasks,
    DateTime now,
  ) {
    final today = DateTime(now.year, now.month, now.day);
    return _laneDefs.map((final _LaneDef def) {
      final laneTasks = tasks.where((final _TaskRecord task) {
        final laneId = _normalizeLane(task.ownerInstance ?? task.instance);
        return laneId == def.id;
      }).toList();

      final activeTasks = laneTasks
          .where((final _TaskRecord task) => task.status != 'completed')
          .toList();
      final blockedTasks = activeTasks
          .where((final _TaskRecord task) => task.status == 'blocked')
          .length;
      final overdueTasks = activeTasks.where((final _TaskRecord task) {
        if (task.endDate == null) return false;
        final due = DateTime(
          task.endDate!.year,
          task.endDate!.month,
          task.endDate!.day,
        );
        return due.isBefore(today);
      }).length;
      final staleTasks = activeTasks.where((final _TaskRecord task) {
        if (task.updatedAt == null) return false;
        return now.difference(task.updatedAt!).inDays >= 3;
      }).length;
      final featureRequestTasks = activeTasks
          .where((final _TaskRecord task) => task.isFeatureRequest)
          .length;
      final highPriorityTasks = activeTasks
          .where((final _TaskRecord task) => task.priority == 'high')
          .length;
      final averageProgress = activeTasks.isEmpty
          ? 0
          : (activeTasks.fold<int>(
                    0,
                    (int sum, _TaskRecord task) => sum + task.progress,
                  ) /
                  activeTasks.length)
              .round();

      return SelfDevinLaneSnapshot(
        id: def.id,
        label: def.label,
        activeTasks: activeTasks.length,
        blockedTasks: blockedTasks,
        overdueTasks: overdueTasks,
        staleTasks: staleTasks,
        featureRequestTasks: featureRequestTasks,
        highPriorityTasks: highPriorityTasks,
        averageProgress: averageProgress,
      );
    }).toList();
  }

  static SelfDevinLaneSnapshot? _pickNextLane(
    List<SelfDevinLaneSnapshot> lanes,
  ) {
    final candidates = lanes
        .where((SelfDevinLaneSnapshot lane) => lane.activeTasks > 0)
        .toList();
    if (candidates.isEmpty) return null;
    candidates.sort((SelfDevinLaneSnapshot a, SelfDevinLaneSnapshot b) {
      final scoreA = _laneScore(a);
      final scoreB = _laneScore(b);
      return scoreB.compareTo(scoreA);
    });
    return candidates.first;
  }

  static int _laneScore(SelfDevinLaneSnapshot lane) {
    return (lane.blockedTasks * 100) +
        (lane.overdueTasks * 40) +
        (lane.featureRequestTasks * 20) +
        (lane.highPriorityTasks * 10) +
        (lane.staleTasks * 5) +
        lane.activeTasks;
  }

  static String _buildNextActionDetail(SelfDevinLaneSnapshot lane) {
    if (lane.blockedTasks > 0 || lane.overdueTasks > 0) {
      return '${lane.label} has ${lane.blockedTasks} blocked tasks and ${lane.overdueTasks} overdue tasks. Unblock this lane before widening the queue.';
    }
    if (lane.featureRequestTasks > 0) {
      return '${lane.label} still has ${lane.featureRequestTasks} feature-request tasks in flight. Keep the next pull focused here.';
    }
    if (lane.staleTasks > 0) {
      return '${lane.label} has ${lane.staleTasks} stale tasks. Refresh the plan and keep the lane moving.';
    }
    return '${lane.label} is healthy and can pull the next highest-priority feature request.';
  }

  static String? _normalizeLane(String? rawValue) {
    final value = (rawValue ?? '').trim().toLowerCase();
    if (value.isEmpty) return null;
    if (value == 'vscode') return 'vscode';
    if (value == 'web') return 'web';
    if (value == 'win' || value == 'windows') return 'windows';
    if (value == 'ps' ||
        value == 'ps1' ||
        value == 'ps2' ||
        value == 'ps3' ||
        value == 'ps4' ||
        value == 'ps5' ||
        value == 'ps6') {
      return 'powershell';
    }
    return null;
  }
}

class _LaneDef {
  final String id;
  final String label;

  const _LaneDef({
    required this.id,
    required this.label,
  });
}

class _LoopDef {
  final String id;
  final String label;
  final String cadenceLabel;
  final String fallbackDetail;
  final Duration? staleAfter;

  const _LoopDef({
    required this.id,
    required this.label,
    required this.cadenceLabel,
    required this.fallbackDetail,
    this.staleAfter,
  });
}

class _TaskRecord {
  final String title;
  final String category;
  final String instance;
  final String? ownerInstance;
  final String status;
  final int progress;
  final DateTime? endDate;
  final String priority;
  final DateTime? updatedAt;

  const _TaskRecord({
    required this.title,
    required this.category,
    required this.instance,
    required this.ownerInstance,
    required this.status,
    required this.progress,
    required this.endDate,
    required this.priority,
    required this.updatedAt,
  });

  factory _TaskRecord.fromMap(Map<String, dynamic> map) {
    return _TaskRecord(
      title: map['title']?.toString() ?? '',
      category: map['category']?.toString() ?? '',
      instance: map['instance']?.toString() ?? '',
      ownerInstance: map['owner_instance']?.toString(),
      status: map['status']?.toString() ?? 'pending',
      progress: _toInt(map['progress']),
      endDate: _tryParseDateTime(map['end_date']),
      priority: map['priority']?.toString() ?? 'medium',
      updatedAt: _tryParseDateTime(map['updated_at']),
    );
  }

  bool get isFeatureRequest =>
      category == 'ユーザー要望' || title.startsWith('[追加要望]');
}

class _RunRecord {
  final String taskId;
  final String status;
  final DateTime? startedAt;
  final String? summary;
  final String? errorMessage;

  const _RunRecord({
    required this.taskId,
    required this.status,
    required this.startedAt,
    required this.summary,
    required this.errorMessage,
  });

  factory _RunRecord.fromMap(Map<String, dynamic> map) {
    return _RunRecord(
      taskId: map['task_id']?.toString() ?? '',
      status: map['status']?.toString() ?? 'unknown',
      startedAt: _tryParseDateTime(map['started_at']),
      summary: map['summary']?.toString(),
      errorMessage: map['error_message']?.toString(),
    );
  }
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

DateTime? _tryParseDateTime(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString())?.toLocal();
}
