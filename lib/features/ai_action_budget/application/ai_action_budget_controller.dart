import 'package:flutter/foundation.dart';

import '../domain/ai_action_budget_models.dart';

/// 月次 AI 予算監視画面のイミュータブル状態 (#2609).
@immutable
class AiActionBudgetState {
  const AiActionBudgetState({
    required this.billingMonth,
    required this.config,
    required this.entries,
    required this.isLoading,
    required this.isSubmitting,
    this.errorMessage,
  });

  factory AiActionBudgetState.initial({String billingMonth = '2026-11'}) {
    final now = DateTime.now().toUtc();
    return AiActionBudgetState(
      billingMonth: billingMonth,
      config: AiActionBudgetConfig(
        id: 'default-config',
        monthlyUsdCap: 50.0,
        warningThresholdPct: 80.0,
        hardStopPct: 100.0,
        isPaused: false,
        createdAt: now,
        updatedAt: now,
      ),
      entries: const <AiActionLedgerEntry>[],
      isLoading: false,
      isSubmitting: false,
    );
  }

  final String billingMonth;
  final AiActionBudgetConfig config;
  final List<AiActionLedgerEntry> entries;
  final bool isLoading;
  final bool isSubmitting;
  final String? errorMessage;

  double get totalSpentUsd {
    double sum = 0.0;
    for (final entry in entries) {
      if (entry.billingMonth == billingMonth) {
        sum += entry.estimatedUsd;
      }
    }
    return double.parse(sum.toStringAsFixed(6));
  }

  double get usagePct {
    if (config.monthlyUsdCap <= 0) {
      return 100.0;
    }
    return double.parse(
      ((totalSpentUsd / config.monthlyUsdCap) * 100.0).toStringAsFixed(2),
    );
  }

  BudgetTierStatus get tierStatus => LocalActionCostEstimator.classifyTier(
        usagePct: usagePct,
        isPaused: config.isPaused,
        warningThresholdPct: config.warningThresholdPct,
        hardStopPct: config.hardStopPct,
      );

  bool get isEffectivePaused => tierStatus == BudgetTierStatus.paused100;

  AiActionBudgetState copyWith({
    AiActionBudgetConfig? config,
    List<AiActionLedgerEntry>? entries,
    bool? isLoading,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AiActionBudgetState(
      billingMonth: billingMonth,
      config: config ?? this.config,
      entries: entries ?? this.entries,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// アクション単位コスト集計と上限自動停止を制御する Controller (#2609).
class AiActionBudgetController extends ChangeNotifier {
  AiActionBudgetController({
    required AiActionBudgetRepository repository,
    String billingMonth = '2026-11',
  })  : _repository = repository,
        _state = AiActionBudgetState.initial(billingMonth: billingMonth);

  final AiActionBudgetRepository _repository;
  AiActionBudgetState _state;
  bool _isDisposed = false;

  AiActionBudgetState get state => _state;
  bool get isDisposed => _isDisposed;

  void _setState(AiActionBudgetState next) {
    if (_isDisposed) {
      return;
    }
    _state = next;
    notifyListeners();
  }

  Future<void> loadSnapshot() async {
    if (_isDisposed) {
      return;
    }
    _setState(_state.copyWith(isLoading: true, clearError: true));
    try {
      final snapshot = await _repository.fetchSnapshot(
        billingMonth: _state.billingMonth,
      );
      if (_isDisposed) {
        return;
      }
      _setState(
        _state.copyWith(
          config: snapshot.config,
          entries: List<AiActionLedgerEntry>.unmodifiable(snapshot.entries),
          isLoading: false,
          clearError: true,
        ),
      );
    } catch (error) {
      _setState(
        _state.copyWith(
          isLoading: false,
          errorMessage: '予算監視データの読込に失敗しました: $error',
        ),
      );
    }
  }

  Future<void> updateMonthlyCap({required String rawCapUsd}) async {
    if (_isDisposed || _state.isSubmitting) {
      return;
    }
    final double? parsed = double.tryParse(rawCapUsd.trim());
    if (parsed == null || !parsed.isFinite || parsed <= 0) {
      _setState(
        _state.copyWith(errorMessage: '月次 USD 上限は正の数値を入力してください。'),
      );
      return;
    }
    _setState(_state.copyWith(isSubmitting: true, clearError: true));
    try {
      final updatedConfig = await _repository.updateMonthlyCap(
        monthlyUsdCap: parsed,
      );
      if (_isDisposed) {
        return;
      }
      _setState(
        _state.copyWith(
          config: updatedConfig,
          isSubmitting: false,
          clearError: true,
        ),
      );
    } catch (error) {
      _setState(
        _state.copyWith(
          isSubmitting: false,
          errorMessage: '月次上限の更新に失敗しました: $error',
        ),
      );
    }
  }

  Future<void> resumeBudget() async {
    if (_isDisposed || _state.isSubmitting) {
      return;
    }
    _setState(_state.copyWith(isSubmitting: true, clearError: true));
    try {
      final updatedConfig = await _repository.resumePausedBudget();
      if (_isDisposed) {
        return;
      }
      _setState(
        _state.copyWith(
          config: updatedConfig,
          isSubmitting: false,
          clearError: true,
        ),
      );
    } catch (error) {
      _setState(
        _state.copyWith(
          isSubmitting: false,
          errorMessage: '一時停止の解除に失敗しました: $error',
        ),
      );
    }
  }

  Future<void> recordUsage({
    required String actionName,
    String modelId = 'gemini-2.5-pro',
    int promptCount = 500000,
    int completionCount = 200000,
  }) async {
    if (_isDisposed || _state.isSubmitting) {
      return;
    }
    if (_state.isEffectivePaused) {
      _setState(
        _state.copyWith(
          errorMessage: '月次予算上限に到達し自動停止中のため、新規 AI アクションはブロックされました。',
        ),
      );
      return;
    }
    final cleanedAction = actionName.trim();
    if (cleanedAction.isEmpty) {
      _setState(_state.copyWith(errorMessage: 'アクション名を入力してください。'));
      return;
    }
    _setState(_state.copyWith(isSubmitting: true, clearError: true));
    try {
      final estimatedUsd = LocalActionCostEstimator.estimateUsd(
        modelId: modelId,
        promptCount: promptCount,
        completionCount: completionCount,
      );
      final projectedTotal = _state.totalSpentUsd + estimatedUsd;
      final projectedPct = (_state.config.monthlyUsdCap > 0)
          ? (projectedTotal / _state.config.monthlyUsdCap) * 100.0
          : 100.0;
      final bool willPause = projectedPct >= _state.config.hardStopPct;

      final draft = AiActionLedgerEntry(
        id: 'local-${DateTime.now().toUtc().millisecondsSinceEpoch}',
        actionName: cleanedAction,
        modelId: modelId,
        promptCount: promptCount,
        completionCount: completionCount,
        estimatedUsd: estimatedUsd,
        billingMonth: _state.billingMonth,
        createdAt: DateTime.now().toUtc(),
      );
      final created = await _repository.recordActionUsage(
        draft: draft,
        triggerPauseAfterSave: willPause,
      );
      if (_isDisposed) {
        return;
      }
      final updatedEntries = <AiActionLedgerEntry>[created, ..._state.entries];
      final updatedConfig = willPause
          ? _state.config.copyWith(
              isPaused: true,
              pausedAt: DateTime.now().toUtc(),
            )
          : _state.config;
      _setState(
        _state.copyWith(
          config: updatedConfig,
          entries: List<AiActionLedgerEntry>.unmodifiable(updatedEntries),
          isSubmitting: false,
          clearError: true,
        ),
      );
    } catch (error) {
      _setState(
        _state.copyWith(
          isSubmitting: false,
          errorMessage: 'アクション消費記録の追加に失敗しました: $error',
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
