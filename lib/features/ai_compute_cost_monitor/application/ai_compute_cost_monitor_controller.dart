import 'package:flutter/foundation.dart';

import '../domain/ai_compute_cost_monitor_models.dart';

/// AI 計算規模・GPU コスト監視ダッシュボードのイミュータブル状態 (#2658).
@immutable
class AiComputeCostMonitorState {
  const AiComputeCostMonitorState({
    required this.entries,
    required this.thresholdSettings,
    required this.isAdmin,
    required this.selectedProfile,
    required this.selectedPeriod,
    required this.searchQuery,
    required this.isLoading,
    required this.isSubmitting,
    required this.isUpdatingThreshold,
    this.errorMessage,
  });

  factory AiComputeCostMonitorState.initial() {
    return AiComputeCostMonitorState(
      entries: const <AiComputeTelemetryEntry>[],
      thresholdSettings: AiComputeThresholdSettings.defaults(),
      isAdmin: false,
      selectedProfile: null,
      selectedPeriod: ComputeCostPeriod.daily,
      searchQuery: '',
      isLoading: false,
      isSubmitting: false,
      isUpdatingThreshold: false,
    );
  }

  final List<AiComputeTelemetryEntry> entries;
  final AiComputeThresholdSettings thresholdSettings;
  final bool isAdmin;
  final GpuComputeProfile? selectedProfile;
  final ComputeCostPeriod selectedPeriod;
  final String searchQuery;
  final bool isLoading;
  final bool isSubmitting;
  final bool isUpdatingThreshold;
  final String? errorMessage;

  List<AiComputeTelemetryEntry> get filteredEntries {
    final normalized = searchQuery.trim().toLowerCase();
    return entries.where((AiComputeTelemetryEntry e) {
      if (selectedProfile != null && e.gpuProfile != selectedProfile) {
        return false;
      }
      if (normalized.isEmpty) {
        return true;
      }
      return e.toolName.toLowerCase().contains(normalized) ||
          e.modelId.toLowerCase().contains(normalized) ||
          e.userId.toLowerCase().contains(normalized);
    }).toList(growable: false);
  }

  int get totalRequests {
    var sum = 0;
    for (final entry in entries) {
      sum += entry.apiRequestCount;
    }
    return sum;
  }

  int get totalTokens {
    var sum = 0;
    for (final entry in entries) {
      sum += entry.totalTokens;
    }
    return sum;
  }

  double get averageLatencyMs {
    if (entries.isEmpty) {
      return 0.0;
    }
    var sum = 0;
    for (final entry in entries) {
      sum += entry.latencyMs;
    }
    return ((sum / entries.length) * 10).roundToDouble() / 10;
  }

  double get totalEstimatedCostUsd {
    var sum = 0.0;
    for (final entry in entries) {
      sum += entry.estimatedComputeCostUsd;
    }
    return (sum * 1000000).roundToDouble() / 1000000;
  }

  List<ComputeCostPeriodBucket> get dailyBuckets => _groupByKey(
        (AiComputeTelemetryEntry e) =>
            e.recordedAt.toUtc().toIso8601String().substring(0, 10),
      );

  List<ComputeCostPeriodBucket> get monthlyBuckets => _groupByKey(
        (AiComputeTelemetryEntry e) =>
            e.recordedAt.toUtc().toIso8601String().substring(0, 7),
      );

  List<ComputeCostPeriodBucket> get activePeriodBuckets =>
      selectedPeriod == ComputeCostPeriod.daily ? dailyBuckets : monthlyBuckets;

  List<ComputeCostPeriodBucket> _groupByKey(
    String Function(AiComputeTelemetryEntry) keySelector,
  ) {
    final grouped = <String, List<AiComputeTelemetryEntry>>{};
    for (final entry in entries) {
      final key = keySelector(entry);
      grouped.putIfAbsent(key, () => <AiComputeTelemetryEntry>[]).add(entry);
    }
    final keys = grouped.keys.toList()
      ..sort((String a, String b) => b.compareTo(a));
    return keys.map((String key) {
      final list = grouped[key]!;
      var reqs = 0;
      var tokens = 0;
      var latSum = 0;
      var costSum = 0.0;
      for (final item in list) {
        reqs += item.apiRequestCount;
        tokens += item.totalTokens;
        latSum += item.latencyMs;
        costSum += item.estimatedComputeCostUsd;
      }
      return ComputeCostPeriodBucket(
        bucketKey: key,
        requestCount: reqs,
        totalTokens: tokens,
        avgLatencyMs: ((latSum / list.length) * 10).roundToDouble() / 10,
        totalEstimatedCostUsd: (costSum * 1000000).roundToDouble() / 1000000,
      );
    }).toList(growable: false);
  }

  List<UserUtilizationSummary> get userSummaries {
    final grouped = <String, List<AiComputeTelemetryEntry>>{};
    for (final entry in entries) {
      final uid = entry.userId.isEmpty ? 'current-user' : entry.userId;
      grouped.putIfAbsent(uid, () => <AiComputeTelemetryEntry>[]).add(entry);
    }
    final summaries = grouped.entries.map((
      MapEntry<String, List<AiComputeTelemetryEntry>> kv,
    ) {
      var reqs = 0;
      var tokens = 0;
      var latSum = 0;
      var costSum = 0.0;
      for (final item in kv.value) {
        reqs += item.apiRequestCount;
        tokens += item.totalTokens;
        latSum += item.latencyMs;
        costSum += item.estimatedComputeCostUsd;
      }
      return UserUtilizationSummary(
        userId: kv.key,
        requestCount: reqs,
        totalTokens: tokens,
        avgLatencyMs: ((latSum / kv.value.length) * 10).roundToDouble() / 10,
        totalEstimatedCostUsd: (costSum * 1000000).roundToDouble() / 1000000,
      );
    }).toList();
    summaries.sort(
      (UserUtilizationSummary a, UserUtilizationSummary b) =>
          b.totalEstimatedCostUsd.compareTo(a.totalEstimatedCostUsd),
    );
    return List<UserUtilizationSummary>.unmodifiable(summaries);
  }

  double get latestDailyCostUsd =>
      dailyBuckets.isEmpty ? 0.0 : dailyBuckets.first.totalEstimatedCostUsd;

  double get latestMonthlyCostUsd =>
      monthlyBuckets.isEmpty ? 0.0 : monthlyBuckets.first.totalEstimatedCostUsd;

  bool get isDailyThresholdExceeded =>
      latestDailyCostUsd >= thresholdSettings.dailyThresholdUsd;

  bool get isMonthlyThresholdExceeded =>
      latestMonthlyCostUsd >= thresholdSettings.monthlyThresholdUsd;

  bool get isThresholdAlertActive =>
      isDailyThresholdExceeded || isMonthlyThresholdExceeded;

  List<ModelTokenCostBreakdown> get modelBreakdowns {
    final grouped = <String, List<AiComputeTelemetryEntry>>{};
    var grandTotalCost = 0.0;
    for (final entry in entries) {
      final key =
          entry.modelId.trim().isEmpty ? 'unknown' : entry.modelId.trim();
      grouped.putIfAbsent(key, () => <AiComputeTelemetryEntry>[]).add(entry);
      grandTotalCost += entry.estimatedComputeCostUsd;
    }
    final items = grouped.entries.map((
      final MapEntry<String, List<AiComputeTelemetryEntry>> kv,
    ) {
      var reqs = 0;
      var inTok = 0;
      var outTok = 0;
      var costSum = 0.0;
      for (final item in kv.value) {
        reqs += item.apiRequestCount;
        inTok += item.inputTokens;
        outTok += item.outputTokens;
        costSum += item.estimatedComputeCostUsd;
      }
      final roundedCost = (costSum * 1000000).roundToDouble() / 1000000;
      final sharePct = grandTotalCost > 0
          ? (((roundedCost / grandTotalCost) * 10000).roundToDouble() / 100)
          : 0.0;
      return ModelTokenCostBreakdown(
        modelId: kv.key,
        requestCount: reqs,
        inputTokens: inTok,
        outputTokens: outTok,
        totalTokens: inTok + outTok,
        estimatedCostUsd: roundedCost,
        costSharePct: sharePct,
      );
    }).toList();
    items.sort(
      (final ModelTokenCostBreakdown a, final ModelTokenCostBreakdown b) {
        final costCmp = b.estimatedCostUsd.compareTo(a.estimatedCostUsd);
        if (costCmp != 0) return costCmp;
        return b.totalTokens.compareTo(a.totalTokens);
      },
    );
    return List<ModelTokenCostBreakdown>.unmodifiable(items);
  }

  AgentLoopDetectionReport get loopDetection {
    var consecutive = 0;
    var maxConsecutive = 0;
    String? prevSignature;
    for (final entry in entries) {
      final sig = '${entry.toolName.trim()}::${entry.modelId.trim()}';
      if (sig == prevSignature) {
        consecutive += 1;
      } else {
        consecutive = 1;
        prevSignature = sig;
      }
      if (consecutive > maxConsecutive) {
        maxConsecutive = consecutive;
      }
    }
    final triggers = <String>[];
    if (maxConsecutive >= 5) {
      triggers.add('連続反復ループ ($maxConsecutive回)');
    }
    if (totalTokens >= 120000) {
      triggers.add('トークン消費急騰 ($totalTokens tokens)');
    }
    if (isThresholdAlertActive) {
      triggers.add('日別/月別コスト上限超過');
    }
    final autoHalted = triggers.isNotEmpty;
    final haltMessage = autoHalted
        ? '異常ループまたはコスト上限超過を検知したため自動停止しました (${triggers.join(' / ')})。'
        : '';
    final tokSum = totalTokens;
    return AgentLoopDetectionReport(
      autoHalted: autoHalted,
      triggers: List<String>.unmodifiable(triggers),
      maxConsecutiveRepeats: maxConsecutive,
      totalWindowTokens: tokSum,
      haltMessage: haltMessage,
    );
  }

  AiComputeCostMonitorState copyWith({
    List<AiComputeTelemetryEntry>? entries,
    AiComputeThresholdSettings? thresholdSettings,
    bool? isAdmin,
    GpuComputeProfile? selectedProfile,
    bool clearSelectedProfile = false,
    ComputeCostPeriod? selectedPeriod,
    String? searchQuery,
    bool? isLoading,
    bool? isSubmitting,
    bool? isUpdatingThreshold,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AiComputeCostMonitorState(
      entries: entries ?? this.entries,
      thresholdSettings: thresholdSettings ?? this.thresholdSettings,
      isAdmin: isAdmin ?? this.isAdmin,
      selectedProfile: clearSelectedProfile
          ? null
          : (selectedProfile ?? this.selectedProfile),
      selectedPeriod: selectedPeriod ?? this.selectedPeriod,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isUpdatingThreshold: isUpdatingThreshold ?? this.isUpdatingThreshold,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// 計算コスト・レイテンシ監視 Controller (#2658).
class AiComputeCostMonitorController extends ChangeNotifier {
  AiComputeCostMonitorController({
    required AiComputeCostMonitorRepository repository,
  }) : _repository = repository;

  final AiComputeCostMonitorRepository _repository;
  AiComputeCostMonitorState _state = AiComputeCostMonitorState.initial();
  bool _isDisposed = false;

  AiComputeCostMonitorState get state => _state;
  bool get isDisposed => _isDisposed;

  void _setState(AiComputeCostMonitorState next) {
    if (_isDisposed) {
      return;
    }
    _state = next;
    notifyListeners();
  }

  Future<void> loadDashboard() async {
    _setState(_state.copyWith(isLoading: true, clearError: true));
    try {
      final snapshot = await _repository.fetchDashboard();
      _setState(
        _state.copyWith(
          entries: snapshot.entries,
          thresholdSettings: snapshot.thresholdSettings,
          isAdmin: snapshot.isAdmin,
          isLoading: false,
          clearError: true,
        ),
      );
    } catch (error) {
      _setState(
        _state.copyWith(
          isLoading: false,
          errorMessage: '計算コストテレメトリの読み込みに失敗しました: $error',
        ),
      );
    }
  }

  void setPeriod(ComputeCostPeriod period) {
    _setState(_state.copyWith(selectedPeriod: period, clearError: true));
  }

  void setProfileFilter(GpuComputeProfile? profile) {
    if (profile == null) {
      _setState(
        _state.copyWith(clearSelectedProfile: true, clearError: true),
      );
      return;
    }
    _setState(_state.copyWith(selectedProfile: profile, clearError: true));
  }

  void setSearchQuery(String query) {
    _setState(_state.copyWith(searchQuery: query, clearError: true));
  }

  Future<bool> recordInvocation({
    required String toolName,
    required GpuComputeProfile gpuProfile,
    required String modelId,
    required int inputTokens,
    required int outputTokens,
    required int apiRequestCount,
    required int latencyMs,
  }) async {
    final loopStatus = _state.loopDetection;
    if (loopStatus.autoHalted) {
      _setState(
        _state.copyWith(
          isSubmitting: false,
          errorMessage: loopStatus.haltMessage,
        ),
      );
      return false;
    }
    _setState(_state.copyWith(isSubmitting: true, clearError: true));
    try {
      final draft = AiComputeCostEstimator.createDraft(
        toolName: toolName,
        gpuProfile: gpuProfile,
        modelId: modelId,
        inputTokens: inputTokens,
        outputTokens: outputTokens,
        apiRequestCount: apiRequestCount,
        latencyMs: latencyMs,
        costThresholdUsd: _state.thresholdSettings.dailyThresholdUsd,
      );
      final saved = await _repository.recordTelemetry(draft);
      final updated = <AiComputeTelemetryEntry>[saved, ..._state.entries];
      _setState(
        _state.copyWith(
          entries: List<AiComputeTelemetryEntry>.unmodifiable(updated),
          isSubmitting: false,
          clearError: true,
        ),
      );
      return true;
    } catch (error) {
      _setState(
        _state.copyWith(
          isSubmitting: false,
          errorMessage: '計算コストテレメトリの記録に失敗しました: $error',
        ),
      );
      return false;
    }
  }

  Future<bool> updateThresholds({
    required double dailyThresholdUsd,
    required double monthlyThresholdUsd,
  }) async {
    if (!_state.isAdmin) {
      _setState(
        _state.copyWith(
          errorMessage: '計算コスト閾値の更新は管理者のみ実行できます。',
        ),
      );
      return false;
    }
    if (dailyThresholdUsd <= 0 || monthlyThresholdUsd < dailyThresholdUsd) {
      _setState(
        _state.copyWith(
          errorMessage: '日別閾値は正数、月別閾値は日別閾値以上で入力してください。',
        ),
      );
      return false;
    }

    _setState(_state.copyWith(isUpdatingThreshold: true, clearError: true));
    try {
      final updated = await _repository.updateThresholds(
        dailyThresholdUsd: dailyThresholdUsd,
        monthlyThresholdUsd: monthlyThresholdUsd,
      );
      _setState(
        _state.copyWith(
          thresholdSettings: updated,
          isUpdatingThreshold: false,
          clearError: true,
        ),
      );
      return true;
    } catch (error) {
      _setState(
        _state.copyWith(
          isUpdatingThreshold: false,
          errorMessage: '計算コスト閾値の更新に失敗しました: $error',
        ),
      );
      return false;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
