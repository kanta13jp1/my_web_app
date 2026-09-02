enum DistractionBarrier {
  anotherRoom,
  outOfSight,
  notificationsOff;

  static DistractionBarrier fromStorage(String? value) {
    return DistractionBarrier.values.firstWhere(
      (barrier) => barrier.name == value,
      orElse: () => DistractionBarrier.anotherRoom,
    );
  }
}

class ProcrastinationResetSession {
  const ProcrastinationResetSession({
    required this.task,
    required this.fiveMinuteAction,
    required this.firstMove,
    required this.barrier,
    required this.createdAt,
    this.startedAt,
  });

  factory ProcrastinationResetSession.fromJson(Map<String, dynamic> json) {
    return ProcrastinationResetSession(
      task: json['task']?.toString() ?? '',
      fiveMinuteAction: json['five_minute_action']?.toString() ?? '',
      firstMove: json['first_move']?.toString() ?? '',
      barrier: DistractionBarrier.fromStorage(json['barrier']?.toString()),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      startedAt: DateTime.tryParse(json['started_at']?.toString() ?? ''),
    );
  }

  final String task;
  final String fiveMinuteAction;
  final String firstMove;
  final DistractionBarrier barrier;
  final DateTime createdAt;
  final DateTime? startedAt;

  bool get hasStarted => startedAt != null;

  ProcrastinationResetSession start(DateTime at) {
    return ProcrastinationResetSession(
      task: task,
      fiveMinuteAction: fiveMinuteAction,
      firstMove: firstMove,
      barrier: barrier,
      createdAt: createdAt,
      startedAt: at,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'task': task,
        'five_minute_action': fiveMinuteAction,
        'first_move': firstMove,
        'barrier': barrier.name,
        'created_at': createdAt.toIso8601String(),
        if (startedAt != null) 'started_at': startedAt!.toIso8601String(),
      };
}

class ProcrastinationResetSnapshot {
  const ProcrastinationResetSnapshot({
    this.session,
    this.completedCount = 0,
    this.lastCompletedAt,
  });

  factory ProcrastinationResetSnapshot.fromJson(Map<String, dynamic> json) {
    final rawSession = json['session'];
    return ProcrastinationResetSnapshot(
      session: rawSession is Map
          ? ProcrastinationResetSession.fromJson(
              Map<String, dynamic>.from(rawSession),
            )
          : null,
      completedCount: (json['completed_count'] as num?)?.toInt() ?? 0,
      lastCompletedAt: DateTime.tryParse(
        json['last_completed_at']?.toString() ?? '',
      ),
    );
  }

  final ProcrastinationResetSession? session;
  final int completedCount;
  final DateTime? lastCompletedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (session != null) 'session': session!.toJson(),
        'completed_count': completedCount,
        if (lastCompletedAt != null)
          'last_completed_at': lastCompletedAt!.toIso8601String(),
      };
}

class ProcrastinationPlanValidationException implements Exception {
  const ProcrastinationPlanValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class BuildProcrastinationPlan {
  const BuildProcrastinationPlan();

  ProcrastinationResetSession call({
    required String task,
    required String fiveMinuteAction,
    required String firstMove,
    required DistractionBarrier barrier,
    required DateTime createdAt,
  }) {
    final normalizedTask = _normalize(task);
    final normalizedAction = _normalize(fiveMinuteAction);
    final normalizedFirstMove = _normalize(firstMove);

    if (normalizedTask.isEmpty) {
      throw const ProcrastinationPlanValidationException(
        '先延ばししていることを入力してください。',
      );
    }
    if (normalizedAction.isEmpty) {
      throw const ProcrastinationPlanValidationException('5分で終わる行動を入力してください。');
    }
    if (normalizedFirstMove.isEmpty) {
      throw const ProcrastinationPlanValidationException('最初の一動作を入力してください。');
    }

    return ProcrastinationResetSession(
      task: normalizedTask,
      fiveMinuteAction: normalizedAction,
      firstMove: normalizedFirstMove,
      barrier: barrier,
      createdAt: createdAt,
    );
  }

  String _normalize(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }
}
