import 'package:flutter/foundation.dart';

import '../domain/ai_cost_monitor_models.dart';

class AiCostMonitorState {
  const AiCostMonitorState({
    this.isLoading = false,
    this.isSaving = false,
    this.snapshot = AiCostDashboardSnapshot.empty,
    this.selectedProviderFilter = 'all',
    this.draftModel = 'gemini-2.5-flash',
    this.draftThresholdUsd = 10.0,
    this.lastBudgetOutcome,
    this.errorMessage,
    this.noticeMessage,
  });

  final bool isLoading;
  final bool isSaving;
  final AiCostDashboardSnapshot snapshot;
  final String selectedProviderFilter;
  final String draftModel;
  final double draftThresholdUsd;
  final BudgetCheckOutcome? lastBudgetOutcome;
  final String? errorMessage;
  final String? noticeMessage;

  List<AiApiUsageLog> get filteredLogs {
    if (selectedProviderFilter == 'all') {
      return snapshot.logs;
    }
    return snapshot.logs
        .where(
          (final log) =>
              log.provider.toLowerCase() ==
              selectedProviderFilter.toLowerCase(),
        )
        .toList(growable: false);
  }

  AiCostMonitorState copyWith({
    final bool? isLoading,
    final bool? isSaving,
    final AiCostDashboardSnapshot? snapshot,
    final String? selectedProviderFilter,
    final String? draftModel,
    final double? draftThresholdUsd,
    final BudgetCheckOutcome? lastBudgetOutcome,
    final String? errorMessage,
    final bool clearError = false,
    final String? noticeMessage,
    final bool clearNotice = false,
  }) {
    return AiCostMonitorState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      snapshot: snapshot ?? this.snapshot,
      selectedProviderFilter:
          selectedProviderFilter ?? this.selectedProviderFilter,
      draftModel: draftModel ?? this.draftModel,
      draftThresholdUsd: draftThresholdUsd ?? this.draftThresholdUsd,
      lastBudgetOutcome: lastBudgetOutcome ?? this.lastBudgetOutcome,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      noticeMessage: clearNotice ? null : (noticeMessage ?? this.noticeMessage),
    );
  }
}

class AiCostMonitorController extends ChangeNotifier {
  AiCostMonitorController({required final AiCostMonitorRepository repository})
      : _repository = repository;

  final AiCostMonitorRepository _repository;
  AiCostMonitorState _state = const AiCostMonitorState();
  bool _disposed = false;

  AiCostMonitorState get state => _state;

  static const List<String> availableSampleModels = <String>[
    'gemini-2.5-flash',
    'gemini-2.5-pro',
    'gpt-4o-mini',
    'gpt-4o',
    'claude-haiku-4-5-20251001',
    'claude-sonnet-4-5',
    'deepseek-v4-flash',
    'unknown-experimental-model',
  ];

  void _emit(final AiCostMonitorState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  Future<void> loadDashboard({final String? targetDate}) async {
    _emit(
      _state.copyWith(
        isLoading: true,
        clearError: true,
        clearNotice: true,
      ),
    );
    try {
      final snapshot = await _repository.fetchDashboard(targetDate: targetDate);
      if (_disposed) return;
      _emit(
        _state.copyWith(
          isLoading: false,
          snapshot: snapshot,
        ),
      );
    } on AiCostAuthException catch (err) {
      if (_disposed) return;
      _emit(
        _state.copyWith(
          isLoading: false,
          errorMessage: err.message,
        ),
      );
    } catch (_) {
      if (_disposed) return;
      _emit(
        _state.copyWith(
          isLoading: false,
          errorMessage: 'AI API コスト集計の取得に失敗しました。通信状態を確認してください。',
        ),
      );
    }
  }

  void setProviderFilter(final String provider) {
    _emit(_state.copyWith(selectedProviderFilter: provider));
  }

  void setDraftModel(final String model) {
    _emit(_state.copyWith(draftModel: model));
  }

  Future<void> recordSampleUsage({
    required final String model,
    required final int inputUnits,
    required final int outputUnits,
    final String actionName = 'manual_test',
  }) async {
    if (inputUnits < 0 || outputUnits < 0) {
      _emit(_state.copyWith(errorMessage: '消費数は 0 以上を指定してください。'));
      return;
    }
    _emit(
      _state.copyWith(
        isSaving: true,
        clearError: true,
        clearNotice: true,
      ),
    );
    try {
      await _repository.recordUsage(
        model: model,
        inputUnits: inputUnits,
        outputUnits: outputUnits,
        actionName: actionName,
      );
      if (_disposed) return;
      final refreshed = await _repository.fetchDashboard(
        targetDate: _state.snapshot.targetDate.isEmpty
            ? null
            : _state.snapshot.targetDate,
      );
      if (_disposed) return;
      _emit(
        _state.copyWith(
          isSaving: false,
          snapshot: refreshed,
          noticeMessage: '$model の消費ログを記録しました。',
        ),
      );
    } on AiCostAuthException catch (err) {
      if (_disposed) return;
      _emit(_state.copyWith(isSaving: false, errorMessage: err.message));
    } catch (_) {
      if (_disposed) return;
      _emit(
        _state.copyWith(
          isSaving: false,
          errorMessage: '利用ログの記録に失敗しました。',
        ),
      );
    }
  }

  Future<void> checkBudgetThreshold(final double thresholdUsd) async {
    if (!thresholdUsd.isFinite || thresholdUsd <= 0) {
      _emit(
        _state.copyWith(
          errorMessage: '日次予算閾値は 0 より大きい USD 金額を指定してください。',
        ),
      );
      return;
    }
    _emit(
      _state.copyWith(
        isSaving: true,
        draftThresholdUsd: thresholdUsd,
        clearError: true,
        clearNotice: true,
      ),
    );
    try {
      final outcome = await _repository.checkBudget(
        budgetThresholdUsd: thresholdUsd,
        targetDate: _state.snapshot.targetDate.isEmpty
            ? null
            : _state.snapshot.targetDate,
      );
      if (_disposed) return;
      final refreshed = await _repository.fetchDashboard(
        targetDate: outcome.targetDate.isEmpty ? null : outcome.targetDate,
      );
      if (_disposed) return;
      _emit(
        _state.copyWith(
          isSaving: false,
          snapshot: refreshed,
          lastBudgetOutcome: outcome,
          noticeMessage: outcome.thresholdExceeded
              ? '予算閾値超過を検知しアラートを記録しました。'
              : '日次コストは予算閾値内に収まっています。',
        ),
      );
    } on AiCostAuthException catch (err) {
      if (_disposed) return;
      _emit(_state.copyWith(isSaving: false, errorMessage: err.message));
    } catch (_) {
      if (_disposed) return;
      _emit(
        _state.copyWith(
          isSaving: false,
          errorMessage: '予算超過チェックの実行に失敗しました。',
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
