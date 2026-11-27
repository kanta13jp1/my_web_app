import 'package:flutter/foundation.dart';

import '../domain/vision_benchmark_models.dart';

/// Immutable UI state for the AI Vision Benchmark dashboard (#2758).
class VisionBenchmarkState {
  const VisionBenchmarkState({
    this.isLoading = false,
    this.isRecording = false,
    this.threshold = kDefaultVisionBenchmarkThreshold,
    this.selectedModel,
    this.allRuns = const <VisionBenchmarkRun>[],
    this.visibleRuns = const <VisionBenchmarkRun>[],
    this.modelSummaries = const <VisionModelSummary>[],
    this.averageScore = 0,
    this.errorMessage,
    this.statusNotice,
  });

  final bool isLoading;
  final bool isRecording;
  final int threshold;
  final String? selectedModel;
  final List<VisionBenchmarkRun> allRuns;
  final List<VisionBenchmarkRun> visibleRuns;
  final List<VisionModelSummary> modelSummaries;
  final double averageScore;
  final String? errorMessage;
  final String? statusNotice;

  List<VisionModelSummary> get alertModels => modelSummaries
      .where((final VisionModelSummary item) => item.belowThreshold)
      .toList(growable: false);

  List<VisionBenchmarkRun> get alertRuns => visibleRuns
      .where((final VisionBenchmarkRun run) => run.isBelowThreshold(threshold))
      .toList(growable: false);

  List<String> get availableModels {
    final models = <String>{};
    for (final run in allRuns) {
      models.add(run.model);
    }
    final list = models.toList(growable: false)..sort();
    return list;
  }

  VisionBenchmarkState copyWith({
    final bool? isLoading,
    final bool? isRecording,
    final int? threshold,
    final String? selectedModel,
    final bool clearSelectedModel = false,
    final List<VisionBenchmarkRun>? allRuns,
    final List<VisionBenchmarkRun>? visibleRuns,
    final List<VisionModelSummary>? modelSummaries,
    final double? averageScore,
    final String? errorMessage,
    final bool clearError = false,
    final String? statusNotice,
    final bool clearNotice = false,
  }) {
    return VisionBenchmarkState(
      isLoading: isLoading ?? this.isLoading,
      isRecording: isRecording ?? this.isRecording,
      threshold: threshold ?? this.threshold,
      selectedModel:
          clearSelectedModel ? null : (selectedModel ?? this.selectedModel),
      allRuns: allRuns ?? this.allRuns,
      visibleRuns: visibleRuns ?? this.visibleRuns,
      modelSummaries: modelSummaries ?? this.modelSummaries,
      averageScore: averageScore ?? this.averageScore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      statusNotice: clearNotice ? null : (statusNotice ?? this.statusNotice),
    );
  }
}

/// Application controller for AI Vision Benchmark monitoring (#2758).
class VisionBenchmarkController extends ChangeNotifier {
  VisionBenchmarkController({
    required final VisionBenchmarkRepository repository,
    final Future<VisionBenchmarkRun> Function(String model, int threshold)?
        onRunLiveTest,
  })  : _repository = repository,
        _onRunLiveTest = onRunLiveTest;

  final VisionBenchmarkRepository _repository;
  final Future<VisionBenchmarkRun> Function(String model, int threshold)?
      _onRunLiveTest;
  VisionBenchmarkState _state = const VisionBenchmarkState();
  bool _disposed = false;

  VisionBenchmarkState get state => _state;
  bool get canRunLiveTest => _onRunLiveTest != null;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _emit(final VisionBenchmarkState nextState) {
    if (_disposed) {
      return;
    }
    _state = nextState;
    notifyListeners();
  }

  VisionBenchmarkState _deriveFromRuns({
    required final List<VisionBenchmarkRun> runs,
    required final int threshold,
    required final String? selectedModel,
    final bool? isLoading,
    final bool? isRecording,
    final String? errorMessage,
    final bool clearError = false,
    final String? statusNotice,
    final bool clearNotice = false,
  }) {
    final fullSnapshot = VisionBenchmarkSnapshot.build(
      runs: runs,
      threshold: threshold,
    );
    final activeFilter = selectedModel != null &&
            fullSnapshot.runs.any(
              (final VisionBenchmarkRun run) => run.model == selectedModel,
            )
        ? selectedModel
        : null;
    final filteredRuns = activeFilter == null
        ? fullSnapshot.runs
        : fullSnapshot.runs
            .where((final VisionBenchmarkRun run) => run.model == activeFilter)
            .toList(growable: false);
    final filteredSnapshot = VisionBenchmarkSnapshot.build(
      runs: filteredRuns,
      threshold: threshold,
    );

    return _state.copyWith(
      isLoading: isLoading,
      isRecording: isRecording,
      threshold: fullSnapshot.threshold,
      selectedModel: activeFilter,
      clearSelectedModel: activeFilter == null,
      allRuns: fullSnapshot.runs,
      visibleRuns: filteredSnapshot.runs,
      modelSummaries: filteredSnapshot.modelSummaries,
      averageScore: filteredSnapshot.averageScore,
      errorMessage: errorMessage,
      clearError: clearError,
      statusNotice: statusNotice,
      clearNotice: clearNotice,
    );
  }

  Future<void> loadDashboard({
    final int? threshold,
    final bool clearNotice = false,
  }) async {
    final targetThreshold = (threshold ?? _state.threshold).clamp(1, 100);
    _emit(
      _state.copyWith(
        isLoading: true,
        threshold: targetThreshold,
        clearError: true,
        clearNotice: clearNotice,
      ),
    );
    try {
      final snapshot = await _repository.fetchDashboard(
        threshold: targetThreshold,
      );
      if (_disposed) return;
      _emit(
        _deriveFromRuns(
          runs: snapshot.runs,
          threshold: targetThreshold,
          selectedModel: _state.selectedModel,
          isLoading: false,
          clearError: true,
        ),
      );
    } catch (error) {
      if (_disposed) return;
      _emit(
        _state.copyWith(
          isLoading: false,
          errorMessage: error.toString().replaceFirst('Bad state: ', ''),
        ),
      );
    }
  }

  void updateThreshold(final int nextThreshold) {
    final clamped = nextThreshold.clamp(1, 100);
    _emit(
      _deriveFromRuns(
        runs: _state.allRuns,
        threshold: clamped,
        selectedModel: _state.selectedModel,
        clearError: true,
        clearNotice: true,
      ),
    );
  }

  void selectModelFilter(final String? model) {
    _emit(
      _deriveFromRuns(
        runs: _state.allRuns,
        threshold: _state.threshold,
        selectedModel: model,
        clearError: true,
        clearNotice: true,
      ),
    );
  }

  Future<void> runAndRecordBenchmark(final String model) async {
    final runner = _onRunLiveTest;
    if (runner == null || _state.isRecording) return;
    _emit(_state.copyWith(isRecording: true, clearError: true));
    try {
      final run = await runner(model, _state.threshold);
      if (_disposed) return;
      final updated = <VisionBenchmarkRun>[run, ..._state.allRuns];
      _emit(
        _deriveFromRuns(
          runs: updated,
          threshold: _state.threshold,
          selectedModel: _state.selectedModel,
          isRecording: false,
          statusNotice: '${run.model} の Vision ベンチマーク (${run.score}点) を記録しました',
          clearError: true,
        ),
      );
    } catch (error) {
      if (_disposed) return;
      _emit(
        _state.copyWith(
          isRecording: false,
          errorMessage: error.toString().replaceFirst('Bad state: ', ''),
        ),
      );
    }
  }
}
