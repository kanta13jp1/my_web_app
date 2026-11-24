import 'package:flutter/foundation.dart';

import '../domain/context_cache_monitor_models.dart';

/// 管理者向けコンテキストキャッシュ・USDコスト監視画面状態 (#2656).
@immutable
class ContextCacheMonitorState {
  const ContextCacheMonitorState({
    this.isLoading = false,
    this.isSubmitting = false,
    this.workflowFilter = '',
    this.userFilter = '',
    this.selectedModelId = 'claude-sonnet-4',
    this.simulateCacheHit = true,
    this.metrics = const <ContextCacheUsageMetric>[],
    this.errorMessage,
  });

  final bool isLoading;
  final bool isSubmitting;
  final String workflowFilter;
  final String userFilter;
  final String selectedModelId;
  final bool simulateCacheHit;
  final List<ContextCacheUsageMetric> metrics;
  final String? errorMessage;

  List<String> get availableWorkflows {
    final seen = <String>[];
    for (final item in metrics) {
      if (!seen.contains(item.workflowKey)) {
        seen.add(item.workflowKey);
      }
    }
    seen.sort();
    return List<String>.unmodifiable(seen);
  }

  List<ContextCacheUsageMetric> get filteredMetrics {
    final normalizedUser = userFilter.trim().toLowerCase();
    return metrics.where((item) {
      if (workflowFilter.isNotEmpty && item.workflowKey != workflowFilter) {
        return false;
      }
      if (normalizedUser.isNotEmpty &&
          !item.userId.toLowerCase().contains(normalizedUser)) {
        return false;
      }
      return true;
    }).toList(growable: false);
  }

  List<WorkflowUserCacheRollup> get rollups =>
      ContextCacheEstimator.aggregateByWorkflowAndUser(filteredMetrics);

  double get totalBaselineUsd {
    var total = 0.0;
    for (final item in filteredMetrics) {
      total += item.uncachedBaselineUsd;
    }
    return double.parse(total.toStringAsFixed(6));
  }

  double get totalActualUsd {
    var total = 0.0;
    for (final item in filteredMetrics) {
      total += item.actualEstimatedUsd;
    }
    return double.parse(total.toStringAsFixed(6));
  }

  double get totalSavingsUsd =>
      double.parse((totalBaselineUsd - totalActualUsd).toStringAsFixed(6));

  double get weightedSavingsPercent =>
      totalBaselineUsd > 0 ? (totalSavingsUsd / totalBaselineUsd) * 100.0 : 0.0;

  int get cacheHitCount =>
      filteredMetrics.where((item) => item.cacheHit).length;

  ContextCacheMonitorState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    String? workflowFilter,
    String? userFilter,
    String? selectedModelId,
    bool? simulateCacheHit,
    List<ContextCacheUsageMetric>? metrics,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ContextCacheMonitorState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      workflowFilter: workflowFilter ?? this.workflowFilter,
      userFilter: userFilter ?? this.userFilter,
      selectedModelId: selectedModelId ?? this.selectedModelId,
      simulateCacheHit: simulateCacheHit ?? this.simulateCacheHit,
      metrics: metrics ?? this.metrics,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// コンテキストキャッシュ消費計測・管理者フィルタ制御 Controller (#2656).
class ContextCacheMonitorController extends ChangeNotifier {
  ContextCacheMonitorController({
    required ContextCacheMonitorRepository repository,
  }) : _repository = repository;

  final ContextCacheMonitorRepository _repository;
  ContextCacheMonitorState _state = const ContextCacheMonitorState();
  bool _disposed = false;

  ContextCacheMonitorState get state => _state;

  bool get isDisposed => _disposed;

  void _emit(ContextCacheMonitorState next) {
    if (_disposed) {
      return;
    }
    _state = next;
    notifyListeners();
  }

  void setWorkflowFilter(String workflowKey) {
    if (_disposed) {
      return;
    }
    _emit(_state.copyWith(workflowFilter: workflowKey.trim()));
  }

  void setUserFilter(String query) {
    if (_disposed) {
      return;
    }
    _emit(_state.copyWith(userFilter: query));
  }

  void selectModel(String modelId) {
    if (_disposed) {
      return;
    }
    _emit(_state.copyWith(selectedModelId: modelId));
  }

  void toggleSimulateCacheHit({required bool value}) {
    if (_disposed) {
      return;
    }
    _emit(_state.copyWith(simulateCacheHit: value));
  }

  Future<void> loadMetrics() async {
    if (_disposed) {
      return;
    }
    _emit(_state.copyWith(isLoading: true, clearError: true));
    try {
      final fetched = await _repository.fetchUsageMetrics();
      if (_disposed) {
        return;
      }
      _emit(
        _state.copyWith(
          isLoading: false,
          metrics: List<ContextCacheUsageMetric>.unmodifiable(fetched),
        ),
      );
    } on StateError catch (error) {
      if (_disposed) {
        return;
      }
      _emit(_state.copyWith(isLoading: false, errorMessage: error.message));
    } on Exception catch (error) {
      if (_disposed) {
        return;
      }
      _emit(
        _state.copyWith(
          isLoading: false,
          errorMessage: 'コンテキストキャッシュ利用状況の取得に失敗しました: $error',
        ),
      );
    }
  }

  Future<void> recordSimulatedRequest({
    required String workflowKey,
    String userId = 'admin-operator',
  }) async {
    if (_disposed || _state.isSubmitting) {
      return;
    }
    final cleanedWorkflow = workflowKey.trim();
    if (cleanedWorkflow.isEmpty) {
      _emit(_state.copyWith(errorMessage: 'ワークフロー名を入力してください。'));
      return;
    }
    _emit(_state.copyWith(isSubmitting: true, clearError: true));
    try {
      final draft = ContextCacheEstimator.buildSimulatedMetric(
        workflowKey: cleanedWorkflow,
        modelId: _state.selectedModelId,
        simulateCacheHit: _state.simulateCacheHit,
        userId: userId,
      );
      final saved = await _repository.recordUsageMetric(draft);
      if (_disposed) {
        return;
      }
      final updated = <ContextCacheUsageMetric>[
        saved,
        ..._state.metrics.where((item) => item.id != saved.id),
      ];
      _emit(
        _state.copyWith(
          isSubmitting: false,
          metrics: List<ContextCacheUsageMetric>.unmodifiable(updated),
        ),
      );
    } on StateError catch (error) {
      if (_disposed) {
        return;
      }
      _emit(_state.copyWith(isSubmitting: false, errorMessage: error.message));
    } on Exception catch (error) {
      if (_disposed) {
        return;
      }
      _emit(
        _state.copyWith(
          isSubmitting: false,
          errorMessage: 'キャッシュ利用ログの保存に失敗しました: $error',
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
