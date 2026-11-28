import 'package:flutter/foundation.dart';

import '../domain/ai_emotion_models.dart';

class AiEmotionState {
  const AiEmotionState({
    required this.snapshot,
    required this.isLoading,
    required this.isSaving,
    required this.selectedToneFilter,
    required this.alertThreshold,
    required this.errorMessage,
    required this.statusNotice,
  });

  const AiEmotionState.initial()
      : snapshot = const AiEmotionDashboardSnapshot.empty(),
        isLoading = false,
        isSaving = false,
        selectedToneFilter = null,
        alertThreshold = 0.7,
        errorMessage = null,
        statusNotice = null;

  final AiEmotionDashboardSnapshot snapshot;
  final bool isLoading;
  final bool isSaving;
  final FunctionalEmotionCategory? selectedToneFilter;
  final double alertThreshold;
  final String? errorMessage;
  final String? statusNotice;

  AiEmotionState copyWith({
    final AiEmotionDashboardSnapshot? snapshot,
    final bool? isLoading,
    final bool? isSaving,
    final FunctionalEmotionCategory? selectedToneFilter,
    final bool clearToneFilter = false,
    final double? alertThreshold,
    final String? errorMessage,
    final bool clearError = false,
    final String? statusNotice,
    final bool clearNotice = false,
  }) {
    return AiEmotionState(
      snapshot: snapshot ?? this.snapshot,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      selectedToneFilter: clearToneFilter
          ? null
          : (selectedToneFilter ?? this.selectedToneFilter),
      alertThreshold: alertThreshold ?? this.alertThreshold,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      statusNotice: clearNotice ? null : (statusNotice ?? this.statusNotice),
    );
  }
}

class AiEmotionController extends ChangeNotifier {
  AiEmotionController({required final AiEmotionRepository repository})
      : _repository = repository;

  final AiEmotionRepository _repository;
  AiEmotionState _state = const AiEmotionState.initial();
  bool _disposed = false;

  AiEmotionState get state => _state;

  void _emit(final AiEmotionState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  Future<void> loadDashboard() async {
    if (_disposed) return;
    _emit(
      _state.copyWith(
        isLoading: true,
        clearError: true,
      ),
    );
    try {
      final nextSnapshot = await _repository.listDashboard(
        toneFilter: _state.selectedToneFilter,
        threshold: _state.alertThreshold,
      );
      if (_disposed) return;
      _emit(
        _state.copyWith(
          snapshot: nextSnapshot,
          isLoading: false,
          clearError: true,
        ),
      );
    } on AiEmotionAuthException {
      if (_disposed) return;
      _emit(
        _state.copyWith(
          isLoading: false,
          errorMessage: '認証が必要です。サインイン後に再読込してください。',
        ),
      );
    } catch (e) {
      if (_disposed) return;
      _emit(
        _state.copyWith(
          isLoading: false,
          errorMessage: '監視データの取得に失敗しました: $e',
        ),
      );
    }
  }

  Future<void> selectToneFilter(
    final FunctionalEmotionCategory? tone,
  ) async {
    if (_disposed) return;
    _emit(
      _state.copyWith(
        selectedToneFilter: tone,
        clearToneFilter: tone == null,
        clearNotice: true,
      ),
    );
    await loadDashboard();
  }

  Future<void> seedDefaults() async {
    if (_disposed) return;
    _emit(
      _state.copyWith(
        isSaving: true,
        clearError: true,
        clearNotice: true,
      ),
    );
    try {
      final seeded = await _repository.seedDefaults(
        threshold: _state.alertThreshold,
      );
      if (_disposed) return;
      _emit(
        _state.copyWith(
          snapshot: seeded,
          isSaving: false,
          statusNotice: 'サンプル感情ログとアラート履歴を投入しました（要検証フラグ有効）。',
        ),
      );
    } on AiEmotionAuthException {
      if (_disposed) return;
      _emit(
        _state.copyWith(
          isSaving: false,
          errorMessage: '認証が必要です。サインイン後に再試行してください。',
        ),
      );
    } catch (e) {
      if (_disposed) return;
      _emit(
        _state.copyWith(
          isSaving: false,
          errorMessage: '標準サンプル投入に失敗しました: $e',
        ),
      );
    }
  }

  Future<void> classifyAndLog({
    required final String responseText,
    required final String model,
    required final String thresholdText,
  }) async {
    if (_disposed) return;
    final trimmed = responseText.trim();
    if (trimmed.isEmpty) {
      _emit(
        _state.copyWith(
          errorMessage: '分類対象の AI 応答テキストを入力してください。',
          clearNotice: true,
        ),
      );
      return;
    }

    final parsedThreshold = double.tryParse(thresholdText.trim());
    final threshold = parsedThreshold != null
        ? parsedThreshold.clamp(0.1, 0.99).toDouble()
        : _state.alertThreshold;

    _emit(
      _state.copyWith(
        isSaving: true,
        alertThreshold: threshold,
        clearError: true,
        clearNotice: true,
      ),
    );
    try {
      final entry = await _repository.classifyAndLog(
        responseText: trimmed,
        model: model.trim().isEmpty ? 'ai-assistant' : model.trim(),
        alertThreshold: threshold,
      );
      if (_disposed) return;
      final nextSnapshot = await _repository.listDashboard(
        toneFilter: _state.selectedToneFilter,
        threshold: threshold,
      );
      if (_disposed) return;
      final alertMsg = entry.thresholdExceeded
          ? '「${entry.tone.label}」(${entry.score.toStringAsFixed(2)}) 閾値超過アラート記録'
          : '「${entry.tone.label}」(${entry.score.toStringAsFixed(2)}) として記録完了';
      _emit(
        _state.copyWith(
          snapshot: nextSnapshot,
          isSaving: false,
          statusNotice: '$alertMsg（要検証）',
        ),
      );
    } on AiEmotionAuthException {
      if (_disposed) return;
      _emit(
        _state.copyWith(
          isSaving: false,
          errorMessage: '認証が必要です。サインイン後に再試行してください。',
        ),
      );
    } catch (e) {
      if (_disposed) return;
      _emit(
        _state.copyWith(
          isSaving: false,
          errorMessage: '感情トーン記録に失敗しました: $e',
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
