import 'package:flutter/foundation.dart';

import '../domain/ai_output_validation_models.dart';

/// 決定的 AI 出力検証 UI のイミュータブル状態 (#2657).
@immutable
class AiOutputValidationState {
  const AiOutputValidationState({
    required this.logs,
    required this.selectedDecision,
    required this.searchQuery,
    required this.selectedContract,
    required this.isLoading,
    required this.isSubmitting,
    this.errorMessage,
    this.lastEvaluatedLog,
  });

  factory AiOutputValidationState.initial() {
    return const AiOutputValidationState(
      logs: <AiOutputValidationLog>[],
      selectedDecision: null,
      searchQuery: '',
      selectedContract: OutputFormatContract.markdownSections,
      isLoading: false,
      isSubmitting: false,
    );
  }

  final List<AiOutputValidationLog> logs;
  final ValidationDecision? selectedDecision;
  final String searchQuery;
  final OutputFormatContract selectedContract;
  final bool isLoading;
  final bool isSubmitting;
  final String? errorMessage;
  final AiOutputValidationLog? lastEvaluatedLog;

  int get passedCount => logs
      .where(
        (AiOutputValidationLog l) => l.decision == ValidationDecision.passed,
      )
      .length;

  int get remediatedCount => logs
      .where(
        (AiOutputValidationLog l) =>
            l.decision == ValidationDecision.remediated,
      )
      .length;

  int get blockedCount => logs
      .where(
        (AiOutputValidationLog l) => l.decision == ValidationDecision.blocked,
      )
      .length;

  double get averageDriftScore {
    if (logs.isEmpty) {
      return 0.0;
    }
    double sum = 0.0;
    for (final log in logs) {
      sum += log.driftScore;
    }
    return ((sum / logs.length) * 1000).roundToDouble() / 1000;
  }

  List<AiOutputValidationLog> get filteredLogs {
    final normalizedQuery = searchQuery.trim().toLowerCase();
    return logs.where((AiOutputValidationLog log) {
      if (selectedDecision != null && log.decision != selectedDecision) {
        return false;
      }
      if (normalizedQuery.isEmpty) {
        return true;
      }
      final matchesPrompt =
          log.promptExcerpt.toLowerCase().contains(normalizedQuery);
      final matchesOutput =
          log.remediatedOutputExcerpt.toLowerCase().contains(normalizedQuery);
      final matchesViolation = log.violations.any(
        (ValidationViolation v) =>
            v.code.toLowerCase().contains(normalizedQuery),
      );
      return matchesPrompt || matchesOutput || matchesViolation;
    }).toList(growable: false);
  }

  AiOutputValidationState copyWith({
    List<AiOutputValidationLog>? logs,
    ValidationDecision? selectedDecision,
    bool clearSelectedDecision = false,
    String? searchQuery,
    OutputFormatContract? selectedContract,
    bool? isLoading,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
    AiOutputValidationLog? lastEvaluatedLog,
  }) {
    return AiOutputValidationState(
      logs: logs ?? this.logs,
      selectedDecision: clearSelectedDecision
          ? null
          : (selectedDecision ?? this.selectedDecision),
      searchQuery: searchQuery ?? this.searchQuery,
      selectedContract: selectedContract ?? this.selectedContract,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      lastEvaluatedLog: lastEvaluatedLog ?? this.lastEvaluatedLog,
    );
  }
}

/// 決定的 AI 出力検証＆監査ログ管理 Controller (#2657).
class AiOutputValidationController extends ChangeNotifier {
  AiOutputValidationController({
    required AiOutputValidationRepository repository,
  }) : _repository = repository;

  final AiOutputValidationRepository _repository;
  AiOutputValidationState _state = AiOutputValidationState.initial();
  bool _isDisposed = false;

  AiOutputValidationState get state => _state;
  bool get isDisposed => _isDisposed;

  void _setState(AiOutputValidationState next) {
    if (_isDisposed) {
      return;
    }
    _state = next;
    notifyListeners();
  }

  Future<void> loadLogs() async {
    _setState(_state.copyWith(isLoading: true, clearError: true));
    try {
      final fetched = await _repository.fetchLogs();
      _setState(_state.copyWith(logs: fetched, isLoading: false));
    } catch (error) {
      _setState(
        _state.copyWith(
          isLoading: false,
          errorMessage: 'AI出力検証ログの読み込みに失敗しました: $error',
        ),
      );
    }
  }

  void setDecisionFilter(ValidationDecision? decision) {
    if (decision == null) {
      _setState(_state.copyWith(clearSelectedDecision: true));
      return;
    }
    _setState(_state.copyWith(selectedDecision: decision));
  }

  void setSearchQuery(String query) {
    _setState(_state.copyWith(searchQuery: query));
  }

  void setContract(OutputFormatContract contract) {
    _setState(_state.copyWith(selectedContract: contract));
  }

  Future<bool> simulateAndRecord({
    required final String prompt,
    required final String candidateOutput,
    final String requiredFieldsCsv = '',
  }) async {
    if (_isDisposed || _state.isSubmitting) {
      return false;
    }
    final requiredFields = requiredFieldsCsv
        .split(',')
        .map((final String s) => s.trim())
        .where((final String s) => s.isNotEmpty)
        .toList(growable: false);

    _setState(
      _state.copyWith(
        isSubmitting: true,
        clearError: true,
      ),
    );

    try {
      final saved = await _repository.submitValidation(
        prompt: prompt,
        candidateOutput: candidateOutput,
        formatContract: _state.selectedContract,
        requiredFields: requiredFields,
      );
      if (_isDisposed) {
        return false;
      }
      final updated = <AiOutputValidationLog>[saved, ..._state.logs];
      _setState(
        _state.copyWith(
          logs: List<AiOutputValidationLog>.unmodifiable(updated),
          isSubmitting: false,
          lastEvaluatedLog: saved,
        ),
      );
      return true;
    } catch (error) {
      if (_isDisposed) {
        return false;
      }
      _setState(
        _state.copyWith(
          isSubmitting: false,
          errorMessage: 'AI出力検証ログの保存に失敗しました: $error',
        ),
      );
      return false;
    } finally {
      if (!_isDisposed && _state.isSubmitting) {
        _setState(_state.copyWith(isSubmitting: false));
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
