import 'package:flutter/foundation.dart';

import '../domain/ai_reasoning_depth_models.dart';

/// AI推論深度UIのイミュータブル状態 (#2654).
@immutable
class AiReasoningDepthState {
  const AiReasoningDepthState({
    this.isLoading = false,
    this.isSubmitting = false,
    this.isPolling = false,
    this.selectedMode = ReasoningDepthMode.standard,
    this.jobs = const <ReasoningDepthJob>[],
    this.selectedJobId,
    this.errorMessage,
    this.comparisons = const <ReasoningModeComparison>[],
  });

  final bool isLoading;
  final bool isSubmitting;
  final bool isPolling;
  final ReasoningDepthMode selectedMode;
  final List<ReasoningDepthJob> jobs;
  final String? selectedJobId;
  final String? errorMessage;
  final List<ReasoningModeComparison> comparisons;

  ReasoningDepthJob? get selectedJob {
    if (jobs.isEmpty) {
      return null;
    }
    final targetId = selectedJobId;
    if (targetId != null) {
      for (final job in jobs) {
        if (job.id == targetId) {
          return job;
        }
      }
    }
    return jobs.first;
  }

  ReasoningModeComparison get selectedComparison {
    for (final entry in comparisons) {
      if (entry.mode == selectedMode) {
        return entry;
      }
    }
    return ReasoningDepthPlanner.compareAllModes().first;
  }

  AiReasoningDepthState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    bool? isPolling,
    ReasoningDepthMode? selectedMode,
    List<ReasoningDepthJob>? jobs,
    String? selectedJobId,
    bool clearSelectedJobId = false,
    String? errorMessage,
    bool clearError = false,
    List<ReasoningModeComparison>? comparisons,
  }) {
    return AiReasoningDepthState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isPolling: isPolling ?? this.isPolling,
      selectedMode: selectedMode ?? this.selectedMode,
      jobs: jobs ?? this.jobs,
      selectedJobId:
          clearSelectedJobId ? null : (selectedJobId ?? this.selectedJobId),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      comparisons: comparisons ?? this.comparisons,
    );
  }
}

/// AI推論深度の切替・コスト比較・非同期キューポーリング制御 Controller (#2654).
class AiReasoningDepthController extends ChangeNotifier {
  AiReasoningDepthController({
    required AiReasoningDepthRepository repository,
  })  : _repository = repository,
        _state = AiReasoningDepthState(
          comparisons: ReasoningDepthPlanner.compareAllModes(),
        );

  final AiReasoningDepthRepository _repository;
  AiReasoningDepthState _state;
  bool _disposed = false;

  AiReasoningDepthState get state => _state;

  bool get isDisposed => _disposed;

  void _emit(AiReasoningDepthState next) {
    if (_disposed) {
      return;
    }
    _state = next;
    notifyListeners();
  }

  void selectMode(ReasoningDepthMode mode) {
    if (_disposed || _state.selectedMode == mode) {
      return;
    }
    _emit(
      _state.copyWith(
        selectedMode: mode,
        clearError: true,
      ),
    );
  }

  void selectJob(String jobId) {
    if (_disposed || _state.selectedJobId == jobId) {
      return;
    }
    _emit(_state.copyWith(selectedJobId: jobId));
  }

  Future<void> loadJobs() async {
    if (_disposed) {
      return;
    }
    _emit(_state.copyWith(isLoading: true, clearError: true));
    try {
      final fetched = await _repository.fetchJobs();
      if (_disposed) {
        return;
      }
      _emit(
        _state.copyWith(
          isLoading: false,
          jobs: List<ReasoningDepthJob>.unmodifiable(fetched),
          selectedJobId: fetched.isNotEmpty ? fetched.first.id : null,
          clearSelectedJobId: fetched.isEmpty,
        ),
      );
    } on StateError catch (error) {
      if (_disposed) {
        return;
      }
      _emit(
        _state.copyWith(
          isLoading: false,
          errorMessage: error.message,
        ),
      );
    } on Exception catch (error) {
      if (_disposed) {
        return;
      }
      _emit(
        _state.copyWith(
          isLoading: false,
          errorMessage: '推論ジョブ履歴の取得に失敗しました: $error',
        ),
      );
    }
  }

  Future<void> submitJob({required String promptSummary}) async {
    if (_disposed || _state.isSubmitting) {
      return;
    }
    final sanitized = ReasoningDepthPlanner.scrubSensitiveText(promptSummary);
    if (sanitized.isEmpty) {
      _emit(
        _state.copyWith(
          errorMessage: '推論を実行する課題や質問内容を入力してください。',
        ),
      );
      return;
    }
    _emit(_state.copyWith(isSubmitting: true, clearError: true));
    try {
      final draft = ReasoningDepthPlanner.buildInitialJob(
        mode: _state.selectedMode,
        promptSummary: sanitized,
      );
      final saved = await _repository.createJob(draft);
      if (_disposed) {
        return;
      }
      final updatedJobs = <ReasoningDepthJob>[
        saved,
        ..._state.jobs.where((item) => item.id != saved.id),
      ];
      _emit(
        _state.copyWith(
          isSubmitting: false,
          jobs: List<ReasoningDepthJob>.unmodifiable(updatedJobs),
          selectedJobId: saved.id,
        ),
      );
    } on StateError catch (error) {
      if (_disposed) {
        return;
      }
      _emit(
        _state.copyWith(
          isSubmitting: false,
          errorMessage: error.message,
        ),
      );
    } on Exception catch (error) {
      if (_disposed) {
        return;
      }
      _emit(
        _state.copyWith(
          isSubmitting: false,
          errorMessage: '推論ジョブの開始に失敗しました: $error',
        ),
      );
    }
  }

  Future<void> pollSelectedJob() async {
    if (_disposed || _state.isPolling) {
      return;
    }
    final current = _state.selectedJob;
    if (current == null || current.jobStatus.isTerminal) {
      return;
    }
    _emit(_state.copyWith(isPolling: true, clearError: true));
    try {
      final next = ReasoningDepthPlanner.advanceQueuedJob(current);
      final persisted = await _repository.updateJobProgress(
        jobId: current.id,
        jobStatus: next.jobStatus,
        toolCallsCompleted: next.toolCallsCompleted,
        progressNote: next.progressNote,
        resultSummary: next.resultSummary,
      );
      if (_disposed) {
        return;
      }
      final replaced = _state.jobs
          .map((item) => item.id == persisted.id ? persisted : item)
          .toList();
      _emit(
        _state.copyWith(
          isPolling: false,
          jobs: List<ReasoningDepthJob>.unmodifiable(replaced),
          selectedJobId: persisted.id,
        ),
      );
    } on StateError catch (error) {
      if (_disposed) {
        return;
      }
      _emit(
        _state.copyWith(
          isPolling: false,
          errorMessage: error.message,
        ),
      );
    } on Exception catch (error) {
      if (_disposed) {
        return;
      }
      _emit(
        _state.copyWith(
          isPolling: false,
          errorMessage: '非同期ジョブのポーリング更新に失敗しました: $error',
        ),
      );
    }
  }

  Future<void> cancelSelectedJob() async {
    if (_disposed || _state.isPolling) {
      return;
    }
    final current = _state.selectedJob;
    if (current == null || current.jobStatus.isTerminal) {
      return;
    }
    _emit(_state.copyWith(isPolling: true, clearError: true));
    try {
      final persisted = await _repository.updateJobProgress(
        jobId: current.id,
        jobStatus: ReasoningJobStatus.cancelled,
        toolCallsCompleted: current.toolCallsCompleted,
        progressNote: 'ユーザー操作により非同期推論をキャンセルしました。',
        resultSummary: current.resultSummary,
      );
      if (_disposed) {
        return;
      }
      final replaced = _state.jobs
          .map((item) => item.id == persisted.id ? persisted : item)
          .toList();
      _emit(
        _state.copyWith(
          isPolling: false,
          jobs: List<ReasoningDepthJob>.unmodifiable(replaced),
          selectedJobId: persisted.id,
        ),
      );
    } on StateError catch (error) {
      if (_disposed) {
        return;
      }
      _emit(
        _state.copyWith(
          isPolling: false,
          errorMessage: error.message,
        ),
      );
    } on Exception catch (error) {
      if (_disposed) {
        return;
      }
      _emit(
        _state.copyWith(
          isPolling: false,
          errorMessage: '推論ジョブのキャンセルに失敗しました: $error',
        ),
      );
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
