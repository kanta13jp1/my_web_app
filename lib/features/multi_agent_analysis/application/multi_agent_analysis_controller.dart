import 'package:flutter/foundation.dart';

import '../domain/multi_agent_analysis_models.dart';

/// 推論ステージフィルタ (#2641).
enum AgentStageFilter {
  all('all', '全て'),
  collector('data_collector', '1.収集'),
  calculator('metric_calculator', '2.計算'),
  synthesizer('synthesis_advisor', '3.統合');

  const AgentStageFilter(this.roleValue, this.label);

  final String roleValue;
  final String label;
}

/// マルチエージェント分析 UI のイミュータブル状態 (#2641).
@immutable
class MultiAgentAnalysisState {
  const MultiAgentAnalysisState({
    required this.runs,
    required this.selectedRunId,
    required this.stageFilter,
    required this.isLoading,
    required this.isSubmitting,
    this.errorMessage,
  });

  factory MultiAgentAnalysisState.initial() {
    return const MultiAgentAnalysisState(
      runs: <MultiAgentAnalysisRun>[],
      selectedRunId: '',
      stageFilter: AgentStageFilter.all,
      isLoading: false,
      isSubmitting: false,
    );
  }

  final List<MultiAgentAnalysisRun> runs;
  final String selectedRunId;
  final AgentStageFilter stageFilter;
  final bool isLoading;
  final bool isSubmitting;
  final String? errorMessage;

  MultiAgentAnalysisRun? get selectedRun {
    if (runs.isEmpty) {
      return null;
    }
    for (final run in runs) {
      if (run.id == selectedRunId) {
        return run;
      }
    }
    return runs.first;
  }

  List<AgentTraceStep> get visibleTraceSteps {
    final current = selectedRun;
    if (current == null) {
      return const <AgentTraceStep>[];
    }
    if (stageFilter == AgentStageFilter.all) {
      return current.reasoningTrace;
    }
    return current.reasoningTrace
        .where((step) => step.role == stageFilter.roleValue)
        .toList(growable: false);
  }

  MultiAgentAnalysisState copyWith({
    List<MultiAgentAnalysisRun>? runs,
    String? selectedRunId,
    AgentStageFilter? stageFilter,
    bool? isLoading,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
  }) {
    return MultiAgentAnalysisState(
      runs: runs ?? this.runs,
      selectedRunId: selectedRunId ?? this.selectedRunId,
      stageFilter: stageFilter ?? this.stageFilter,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// 3エージェント逐次分析と Human-in-the-Loop レビューを制御する Controller (#2641).
class MultiAgentAnalysisController extends ChangeNotifier {
  MultiAgentAnalysisController({
    required MultiAgentAnalysisRepository repository,
  }) : _repository = repository;

  final MultiAgentAnalysisRepository _repository;
  MultiAgentAnalysisState _state = MultiAgentAnalysisState.initial();
  bool _isDisposed = false;

  MultiAgentAnalysisState get state => _state;
  bool get isDisposed => _isDisposed;

  void _setState(MultiAgentAnalysisState next) {
    if (_isDisposed) {
      return;
    }
    _state = next;
    notifyListeners();
  }

  Future<void> loadRuns() async {
    if (_isDisposed) {
      return;
    }
    _setState(_state.copyWith(isLoading: true, clearError: true));
    try {
      final fetched = await _repository.fetchRuns();
      if (_isDisposed) {
        return;
      }
      final nextSelectedId = fetched.isNotEmpty
          ? (fetched.any((item) => item.id == _state.selectedRunId)
              ? _state.selectedRunId
              : fetched.first.id)
          : '';
      _setState(
        _state.copyWith(
          runs: List<MultiAgentAnalysisRun>.unmodifiable(fetched),
          selectedRunId: nextSelectedId,
          isLoading: false,
          clearError: true,
        ),
      );
    } catch (error) {
      _setState(
        _state.copyWith(
          isLoading: false,
          errorMessage: '分析履歴の読込に失敗しました: $error',
        ),
      );
    }
  }

  void selectRun(String runId) {
    if (_isDisposed) {
      return;
    }
    _setState(_state.copyWith(selectedRunId: runId, clearError: true));
  }

  void selectStageFilter(AgentStageFilter filter) {
    if (_isDisposed) {
      return;
    }
    _setState(_state.copyWith(stageFilter: filter));
  }

  Future<void> runNewAnalysis({required String topic}) async {
    if (_isDisposed || _state.isSubmitting) {
      return;
    }
    _setState(_state.copyWith(isSubmitting: true, clearError: true));
    try {
      final draft = LocalSequentialAnalysisRunner.execute(topic: topic);
      final saved = await _repository.createRun(draft);
      if (_isDisposed) {
        return;
      }
      final updatedList = <MultiAgentAnalysisRun>[
        saved,
        ..._state.runs.where((item) => item.id != saved.id),
      ];
      _setState(
        _state.copyWith(
          runs: List<MultiAgentAnalysisRun>.unmodifiable(updatedList),
          selectedRunId: saved.id,
          isSubmitting: false,
          clearError: true,
        ),
      );
    } catch (error) {
      _setState(
        _state.copyWith(
          isSubmitting: false,
          errorMessage: 'マルチエージェント分析の実行に失敗しました: $error',
        ),
      );
    }
  }

  Future<void> submitReview({
    required HumanReviewStatus status,
    required String note,
  }) async {
    final current = _state.selectedRun;
    if (_isDisposed || _state.isSubmitting || current == null) {
      return;
    }
    _setState(_state.copyWith(isSubmitting: true, clearError: true));
    try {
      final updated = await _repository.submitHumanReview(
        runId: current.id,
        status: status,
        note: note,
      );
      if (_isDisposed) {
        return;
      }
      final updatedList = _state.runs
          .map((item) => item.id == updated.id ? updated : item)
          .toList(growable: false);
      _setState(
        _state.copyWith(
          runs: List<MultiAgentAnalysisRun>.unmodifiable(updatedList),
          selectedRunId: updated.id,
          isSubmitting: false,
          clearError: true,
        ),
      );
    } catch (error) {
      _setState(
        _state.copyWith(
          isSubmitting: false,
          errorMessage: '人間レビュー状態の更新に失敗しました: $error',
        ),
      );
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
