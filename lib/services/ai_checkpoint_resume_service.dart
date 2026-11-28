import 'dart:async';

enum AiCheckpointTaskStatus {
  pending('pending', '待機中'),
  running('running', '実行中'),
  retrying('retrying', '再試行待ち'),
  completed('completed', '完了'),
  dlq('dlq', 'DLQ隔離');

  final String wireKey;
  final String labelJa;

  const AiCheckpointTaskStatus(this.wireKey, this.labelJa);
}

enum AiCheckpointStepStatus {
  pending('pending', '未実行'),
  completed('completed', '完了'),
  failed('failed', '失敗');

  final String wireKey;
  final String labelJa;

  const AiCheckpointStepStatus(this.wireKey, this.labelJa);
}

class AiCheckpointStepRecord {
  final int index;
  final String name;
  final AiCheckpointStepStatus status;
  final String? errorMessage;
  final DateTime? completedAt;

  const AiCheckpointStepRecord({
    required this.index,
    required this.name,
    required this.status,
    this.errorMessage,
    this.completedAt,
  });

  AiCheckpointStepRecord copyWith({
    AiCheckpointStepStatus? status,
    String? errorMessage,
    bool clearError = false,
    DateTime? completedAt,
  }) {
    return AiCheckpointStepRecord(
      index: index,
      name: name,
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

class AiCheckpointTask {
  final String taskId;
  final AiCheckpointTaskStatus status;
  final int attemptCount;
  final int maxRetries;
  final int lastCompletedStepIndex;
  final List<AiCheckpointStepRecord> steps;
  final Map<String, Object?> stepOutputs;
  final String? lastError;
  final DateTime? quarantinedAt;
  final DateTime updatedAt;

  const AiCheckpointTask({
    required this.taskId,
    required this.status,
    required this.attemptCount,
    required this.maxRetries,
    required this.lastCompletedStepIndex,
    required this.steps,
    required this.stepOutputs,
    required this.updatedAt,
    this.lastError,
    this.quarantinedAt,
  });

  int get resumeStartIndex {
    final next = lastCompletedStepIndex + 1;
    if (next < 0) return 0;
    return next > steps.length ? steps.length : next;
  }

  double get progressRatio {
    if (steps.isEmpty) return 1.0;
    final completed = lastCompletedStepIndex + 1;
    return (completed / steps.length).clamp(0.0, 1.0);
  }

  AiCheckpointTask copyWith({
    AiCheckpointTaskStatus? status,
    int? attemptCount,
    int? maxRetries,
    int? lastCompletedStepIndex,
    List<AiCheckpointStepRecord>? steps,
    Map<String, Object?>? stepOutputs,
    String? lastError,
    bool clearLastError = false,
    DateTime? quarantinedAt,
    bool clearQuarantinedAt = false,
    DateTime? updatedAt,
  }) {
    return AiCheckpointTask(
      taskId: taskId,
      status: status ?? this.status,
      attemptCount: attemptCount ?? this.attemptCount,
      maxRetries: maxRetries ?? this.maxRetries,
      lastCompletedStepIndex:
          lastCompletedStepIndex ?? this.lastCompletedStepIndex,
      steps: steps ?? List<AiCheckpointStepRecord>.from(this.steps),
      stepOutputs: stepOutputs ?? Map<String, Object?>.from(this.stepOutputs),
      lastError: clearLastError ? null : (lastError ?? this.lastError),
      quarantinedAt:
          clearQuarantinedAt ? null : (quarantinedAt ?? this.quarantinedAt),
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

abstract class AiCheckpointStore {
  Future<AiCheckpointTask?> loadTask(String taskId);
  Future<void> saveTask(AiCheckpointTask task);
  Future<void> moveToDlq(AiCheckpointTask task);
  Future<List<AiCheckpointTask>> listDlq();
}

class InMemoryAiCheckpointStore implements AiCheckpointStore {
  final Map<String, AiCheckpointTask> _tasks = <String, AiCheckpointTask>{};
  final Map<String, AiCheckpointTask> _dlq = <String, AiCheckpointTask>{};

  @override
  Future<AiCheckpointTask?> loadTask(String taskId) async {
    return _tasks[taskId]?.copyWith();
  }

  @override
  Future<void> saveTask(AiCheckpointTask task) async {
    _tasks[task.taskId] = task.copyWith();
    if (task.status != AiCheckpointTaskStatus.dlq) {
      _dlq.remove(task.taskId);
    }
  }

  @override
  Future<void> moveToDlq(AiCheckpointTask task) async {
    final snapshot = task.copyWith();
    _tasks[task.taskId] = snapshot;
    _dlq[task.taskId] = snapshot;
  }

  @override
  Future<List<AiCheckpointTask>> listDlq() async {
    return _dlq.values.map((item) => item.copyWith()).toList(growable: false);
  }
}

class AiCheckpointStepContext {
  final String taskId;
  final int stepIndex;
  final Map<String, Object?> stepOutputs;

  const AiCheckpointStepContext({
    required this.taskId,
    required this.stepIndex,
    required this.stepOutputs,
  });
}

class AiCheckpointPipelineStep {
  final String name;
  final Future<Object?> Function(AiCheckpointStepContext context) execute;

  const AiCheckpointPipelineStep({
    required this.name,
    required this.execute,
  });
}

/// Manages step-level AI checkpoints, safe resume from the last completed step,
/// Dead Letter Queue (DLQ) isolation, and broadcast progress streams.
class AiCheckpointResumeService {
  static const int defaultMaxRetries = 3;

  final AiCheckpointStore _store;
  final DateTime Function() _now;
  final StreamController<AiCheckpointTask> _progressController =
      StreamController<AiCheckpointTask>.broadcast();

  AiCheckpointResumeService({
    AiCheckpointStore? store,
    DateTime Function()? now,
  })  : _store = store ?? InMemoryAiCheckpointStore(),
        _now = now ?? DateTime.now;

  Stream<AiCheckpointTask> get progressStream => _progressController.stream;

  Future<List<AiCheckpointTask>> listDlq() => _store.listDlq();

  Future<AiCheckpointTask> runOrResume({
    required String taskId,
    required List<AiCheckpointPipelineStep> steps,
    int maxRetries = defaultMaxRetries,
  }) async {
    final safeMaxRetries = maxRetries < 1 ? 1 : maxRetries;
    final existing = await _store.loadTask(taskId);
    var task = existing ??
        AiCheckpointTask(
          taskId: taskId,
          status: AiCheckpointTaskStatus.pending,
          attemptCount: 0,
          maxRetries: safeMaxRetries,
          lastCompletedStepIndex: -1,
          steps: List<AiCheckpointStepRecord>.generate(
            steps.length,
            (index) => AiCheckpointStepRecord(
              index: index,
              name: steps[index].name,
              status: AiCheckpointStepStatus.pending,
            ),
          ),
          stepOutputs: <String, Object?>{},
          updatedAt: _now().toUtc(),
        );

    if (task.status == AiCheckpointTaskStatus.completed ||
        task.status == AiCheckpointTaskStatus.dlq) {
      return task;
    }

    final startIndex = task.resumeStartIndex;
    task = task.copyWith(
      status: AiCheckpointTaskStatus.running,
      updatedAt: _now().toUtc(),
    );
    await _saveAndEmit(task);

    for (var i = startIndex; i < steps.length; i++) {
      final step = steps[i];
      try {
        final output = await step.execute(
          AiCheckpointStepContext(
            taskId: task.taskId,
            stepIndex: i,
            stepOutputs: Map<String, Object?>.unmodifiable(task.stepOutputs),
          ),
        );
        final completedAt = _now().toUtc();
        final nextOutputs = Map<String, Object?>.from(task.stepOutputs)
          ..[step.name] = output;
        final nextSteps = List<AiCheckpointStepRecord>.from(task.steps);
        nextSteps[i] = nextSteps[i].copyWith(
          status: AiCheckpointStepStatus.completed,
          clearError: true,
          completedAt: completedAt,
        );
        task = task.copyWith(
          lastCompletedStepIndex: i,
          steps: nextSteps,
          stepOutputs: nextOutputs,
          clearLastError: true,
          updatedAt: completedAt,
        );
        await _saveAndEmit(task);
      } catch (error) {
        final failedAt = _now().toUtc();
        final nextAttempt = task.attemptCount + 1;
        final nextSteps = List<AiCheckpointStepRecord>.from(task.steps);
        nextSteps[i] = nextSteps[i].copyWith(
          status: AiCheckpointStepStatus.failed,
          errorMessage: error.toString(),
        );
        final moveToDlq = nextAttempt >= task.maxRetries;
        task = task.copyWith(
          status: moveToDlq
              ? AiCheckpointTaskStatus.dlq
              : AiCheckpointTaskStatus.retrying,
          attemptCount: nextAttempt,
          steps: nextSteps,
          lastError: error.toString(),
          quarantinedAt: moveToDlq ? failedAt : null,
          updatedAt: failedAt,
        );
        if (moveToDlq) {
          await _store.moveToDlq(task);
          _emit(task);
        } else {
          await _saveAndEmit(task);
        }
        return task;
      }
    }

    task = await _markCompleted(task);
    return task;
  }

  Future<AiCheckpointTask> _markCompleted(AiCheckpointTask task) async {
    final completed = task.copyWith(
      status: AiCheckpointTaskStatus.completed,
      updatedAt: _now().toUtc(),
    );
    await _saveAndEmit(completed);
    return completed;
  }

  Future<AiCheckpointTask?> replayFromDlq(String taskId) async {
    final existing = await _store.loadTask(taskId);
    if (existing == null || existing.status != AiCheckpointTaskStatus.dlq) {
      return existing;
    }
    final resetTask = existing.copyWith(
      status: AiCheckpointTaskStatus.pending,
      attemptCount: 0,
      clearLastError: true,
      clearQuarantinedAt: true,
      updatedAt: _now().toUtc(),
    );
    await _saveAndEmit(resetTask);
    return resetTask;
  }

  Future<void> _saveAndEmit(AiCheckpointTask task) async {
    await _store.saveTask(task);
    _emit(task);
  }

  void _emit(AiCheckpointTask task) {
    if (!_progressController.isClosed) {
      _progressController.add(task);
    }
  }

  Future<void> dispose() async {
    if (!_progressController.isClosed) {
      await _progressController.close();
    }
  }
}
