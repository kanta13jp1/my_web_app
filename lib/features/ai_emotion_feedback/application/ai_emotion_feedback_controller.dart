import 'package:flutter/foundation.dart';

import '../domain/ai_emotion_feedback_models.dart';

/// Immutable UI state for AI emotion feedback monitoring (#2766).
class AiEmotionFeedbackState {
  const AiEmotionFeedbackState({
    this.isLoading = false,
    this.isSubmitting = false,
    this.isExporting = false,
    this.selectedCategoryFilter,
    this.entries = const <AiEmotionFeedbackEntry>[],
    this.summary = const AiEmotionFeedbackSummary.empty(),
    this.intakePackage,
    this.errorMessage,
    this.statusNotice,
  });

  final bool isLoading;
  final bool isSubmitting;
  final bool isExporting;
  final EmotionFeedbackCategory? selectedCategoryFilter;
  final List<AiEmotionFeedbackEntry> entries;
  final AiEmotionFeedbackSummary summary;
  final NotebookLmIntakePackage? intakePackage;
  final String? errorMessage;
  final String? statusNotice;

  AiEmotionFeedbackState copyWith({
    final bool? isLoading,
    final bool? isSubmitting,
    final bool? isExporting,
    final EmotionFeedbackCategory? selectedCategoryFilter,
    final bool clearCategoryFilter = false,
    final List<AiEmotionFeedbackEntry>? entries,
    final AiEmotionFeedbackSummary? summary,
    final NotebookLmIntakePackage? intakePackage,
    final String? errorMessage,
    final bool clearError = false,
    final String? statusNotice,
    final bool clearNotice = false,
  }) {
    return AiEmotionFeedbackState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isExporting: isExporting ?? this.isExporting,
      selectedCategoryFilter: clearCategoryFilter
          ? null
          : (selectedCategoryFilter ?? this.selectedCategoryFilter),
      entries: entries ?? this.entries,
      summary: summary ?? this.summary,
      intakePackage: intakePackage ?? this.intakePackage,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      statusNotice: clearNotice ? null : (statusNotice ?? this.statusNotice),
    );
  }
}

/// Application controller coordinating AI emotion feedback & NLM export (#2766).
class AiEmotionFeedbackController extends ChangeNotifier {
  AiEmotionFeedbackController({
    required final AiEmotionFeedbackRepository repository,
  }) : _repository = repository;

  final AiEmotionFeedbackRepository _repository;
  AiEmotionFeedbackState _state = const AiEmotionFeedbackState();
  bool _disposed = false;

  AiEmotionFeedbackState get state => _state;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _emit(final AiEmotionFeedbackState nextState) {
    if (_disposed) {
      return;
    }
    _state = nextState;
    notifyListeners();
  }

  Future<void> loadFeedbacks({
    final EmotionFeedbackCategory? categoryFilter,
    final bool clearFilter = false,
  }) async {
    if (_disposed) {
      return;
    }
    final nextFilter =
        clearFilter ? null : (categoryFilter ?? _state.selectedCategoryFilter);
    _emit(
      _state.copyWith(
        isLoading: true,
        selectedCategoryFilter: nextFilter,
        clearCategoryFilter: clearFilter,
        clearError: true,
      ),
    );
    try {
      final snapshot = await _repository.fetchFeedbacks(
        categoryFilter: nextFilter,
      );
      if (_disposed) {
        return;
      }
      _emit(
        _state.copyWith(
          isLoading: false,
          entries: snapshot.entries,
          summary: snapshot.summary,
          clearError: true,
        ),
      );
    } catch (error) {
      if (_disposed) {
        return;
      }
      _emit(
        _state.copyWith(
          isLoading: false,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> selectCategoryFilter(
    final EmotionFeedbackCategory? category,
  ) async {
    await loadFeedbacks(
      categoryFilter: category,
      clearFilter: category == null,
    );
  }

  Future<bool> submitFeedback({
    required final EmotionFeedbackCategory category,
    required final EmotionFeedbackSeverity severity,
    required final String aiSnippet,
    required final String userComment,
    final String sessionRef = '',
    final String modelRef = '',
  }) async {
    if (_disposed) {
      return false;
    }
    final trimmedSnippet = aiSnippet.trim();
    final trimmedComment = userComment.trim();
    if (trimmedSnippet.isEmpty && trimmedComment.isEmpty) {
      _emit(
        _state.copyWith(
          errorMessage: 'AI応答抜粋または改善コメントのいずれかを入力してください。',
        ),
      );
      return false;
    }
    _emit(
      _state.copyWith(
        isSubmitting: true,
        clearError: true,
        clearNotice: true,
      ),
    );
    try {
      final created = await _repository.submitFeedback(
        category: category,
        severity: severity,
        aiSnippet: trimmedSnippet,
        userComment: trimmedComment,
        sessionRef: sessionRef.trim(),
        modelRef: modelRef.trim(),
      );
      if (_disposed) {
        return false;
      }
      final snapshot = await _repository.fetchFeedbacks(
        categoryFilter: _state.selectedCategoryFilter,
      );
      if (_disposed) {
        return false;
      }
      final issueNotice = created.issueCreated && created.issueNumber != null
          ? 'フィードバックを保存し、GitHub Issue #${created.issueNumber} を起票しました。'
          : 'フィードバックを保存しました（GitHub Issue 自動起票は環境設定に応じてスキップ）。';
      _emit(
        _state.copyWith(
          isSubmitting: false,
          entries: snapshot.entries,
          summary: snapshot.summary,
          statusNotice: issueNotice,
          clearError: true,
        ),
      );
      return true;
    } catch (error) {
      if (_disposed) {
        return false;
      }
      _emit(
        _state.copyWith(
          isSubmitting: false,
          errorMessage: error.toString(),
        ),
      );
      return false;
    }
  }

  Future<void> seedDefaults() async {
    if (_disposed) {
      return;
    }
    _emit(
      _state.copyWith(
        isSubmitting: true,
        clearError: true,
        clearNotice: true,
      ),
    );
    try {
      final snapshot = await _repository.seedDefaults();
      if (_disposed) {
        return;
      }
      final notice = snapshot.seededCount > 0
          ? 'サンプルフィードバックを ${snapshot.seededCount} 件登録しました。'
          : '初期サンプルは登録済みです。';
      _emit(
        _state.copyWith(
          isSubmitting: false,
          entries: snapshot.entries,
          summary: snapshot.summary,
          statusNotice: notice,
          clearError: true,
        ),
      );
    } catch (error) {
      if (_disposed) {
        return;
      }
      _emit(
        _state.copyWith(
          isSubmitting: false,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> exportNotebookLmIntake() async {
    if (_disposed) {
      return;
    }
    _emit(
      _state.copyWith(
        isExporting: true,
        clearError: true,
      ),
    );
    try {
      final intake = await _repository.exportNotebookLmIntake();
      if (_disposed) {
        return;
      }
      _emit(
        _state.copyWith(
          isExporting: false,
          intakePackage: intake,
          statusNotice: 'NotebookLM インテークデータ (${intake.recordCount}件) を抽出しました。',
          clearError: true,
        ),
      );
    } catch (error) {
      if (_disposed) {
        return;
      }
      _emit(
        _state.copyWith(
          isExporting: false,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  void setStatusNotice(final String message) {
    _emit(_state.copyWith(statusNotice: message, clearError: true));
  }
}
