import 'package:flutter/foundation.dart';

/// 推論バックエンド / GPU プロファイル種別 (#2658).
enum GpuComputeProfile {
  cpuFallback(
    wireValue: 'cpu-fallback',
    displayLabel: 'CPU フォールバック',
    perSecondUsd: 0.00005,
    per1kInputUsd: 0.0002,
    per1kOutputUsd: 0.0006,
  ),
  t4Inference(
    wireValue: 't4-inference',
    displayLabel: 'T4 GPU 推論',
    perSecondUsd: 0.00018,
    per1kInputUsd: 0.0003,
    per1kOutputUsd: 0.0009,
  ),
  l4Inference(
    wireValue: 'l4-inference',
    displayLabel: 'L4 GPU 推論',
    perSecondUsd: 0.00035,
    per1kInputUsd: 0.0005,
    per1kOutputUsd: 0.0015,
  ),
  a100Cluster(
    wireValue: 'a100-cluster',
    displayLabel: 'A100 クラスタ',
    perSecondUsd: 0.0012,
    per1kInputUsd: 0.001,
    per1kOutputUsd: 0.003,
  ),
  h100Cluster(
    wireValue: 'h100-cluster',
    displayLabel: 'H100 クラスタ',
    perSecondUsd: 0.0024,
    per1kInputUsd: 0.0015,
    per1kOutputUsd: 0.0045,
  ),
  managedApi(
    wireValue: 'managed-api',
    displayLabel: 'Managed LLM API',
    perSecondUsd: 0.0001,
    per1kInputUsd: 0.0004,
    per1kOutputUsd: 0.0012,
  );

  const GpuComputeProfile({
    required this.wireValue,
    required this.displayLabel,
    required this.perSecondUsd,
    required this.per1kInputUsd,
    required this.per1kOutputUsd,
  });

  final String wireValue;
  final String displayLabel;
  final double perSecondUsd;
  final double per1kInputUsd;
  final double per1kOutputUsd;

  static GpuComputeProfile fromWireValue(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    for (final profile in GpuComputeProfile.values) {
      if (profile.wireValue == normalized) {
        return profile;
      }
    }
    return GpuComputeProfile.managedApi;
  }
}

/// 集計表示期間切替 (#2658).
enum ComputeCostPeriod {
  daily(label: '日別コスト'),
  monthly(label: '月別コスト');

  const ComputeCostPeriod({required this.label});

  final String label;
}

/// `ai_compute_cost_telemetry` テレメトリ行モデル (#2658).
@immutable
class AiComputeTelemetryEntry {
  const AiComputeTelemetryEntry({
    required this.id,
    required this.userId,
    required this.toolName,
    required this.gpuProfile,
    required this.modelId,
    required this.inputTokens,
    required this.outputTokens,
    required this.apiRequestCount,
    required this.latencyMs,
    required this.estimatedComputeCostUsd,
    required this.costThresholdUsd,
    required this.thresholdAlertTriggered,
    required this.recordedAt,
  });

  factory AiComputeTelemetryEntry.fromSupabaseRow(Map<String, Object?> row) {
    final rawRecorded = row['recorded_at'] as String?;
    final parsedRecorded = rawRecorded != null
        ? DateTime.tryParse(rawRecorded)?.toUtc() ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)
        : DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

    return AiComputeTelemetryEntry(
      id: (row['id'] as String? ?? '').trim(),
      userId: (row['user_id'] as String? ?? '').trim(),
      toolName: (row['tool_name'] as String? ?? 'ai-hub').trim(),
      gpuProfile: GpuComputeProfile.fromWireValue(
        row['gpu_profile'] as String?,
      ),
      modelId: (row['model_id'] as String? ?? 'gemini-2.5-flash').trim(),
      inputTokens: (row['input_tokens'] as num?)?.toInt() ?? 0,
      outputTokens: (row['output_tokens'] as num?)?.toInt() ?? 0,
      apiRequestCount: (row['api_request_count'] as num?)?.toInt() ?? 1,
      latencyMs: (row['latency_ms'] as num?)?.toInt() ?? 0,
      estimatedComputeCostUsd:
          (row['estimated_compute_cost_usd'] as num?)?.toDouble() ?? 0.0,
      costThresholdUsd: (row['cost_threshold_usd'] as num?)?.toDouble() ?? 50.0,
      thresholdAlertTriggered:
          row['threshold_alert_triggered'] as bool? ?? false,
      recordedAt: parsedRecorded,
    );
  }

  final String id;
  final String userId;
  final String toolName;
  final GpuComputeProfile gpuProfile;
  final String modelId;
  final int inputTokens;
  final int outputTokens;
  final int apiRequestCount;
  final int latencyMs;
  final double estimatedComputeCostUsd;
  final double costThresholdUsd;
  final bool thresholdAlertTriggered;
  final DateTime recordedAt;

  int get totalTokens => inputTokens + outputTokens;

  AiComputeTelemetryEntry copyWith({
    String? id,
    String? userId,
    String? toolName,
    GpuComputeProfile? gpuProfile,
    String? modelId,
    int? inputTokens,
    int? outputTokens,
    int? apiRequestCount,
    int? latencyMs,
    double? estimatedComputeCostUsd,
    double? costThresholdUsd,
    bool? thresholdAlertTriggered,
    DateTime? recordedAt,
  }) {
    return AiComputeTelemetryEntry(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      toolName: toolName ?? this.toolName,
      gpuProfile: gpuProfile ?? this.gpuProfile,
      modelId: modelId ?? this.modelId,
      inputTokens: inputTokens ?? this.inputTokens,
      outputTokens: outputTokens ?? this.outputTokens,
      apiRequestCount: apiRequestCount ?? this.apiRequestCount,
      latencyMs: latencyMs ?? this.latencyMs,
      estimatedComputeCostUsd:
          estimatedComputeCostUsd ?? this.estimatedComputeCostUsd,
      costThresholdUsd: costThresholdUsd ?? this.costThresholdUsd,
      thresholdAlertTriggered:
          thresholdAlertTriggered ?? this.thresholdAlertTriggered,
      recordedAt: recordedAt ?? this.recordedAt,
    );
  }

  Map<String, Object?> toInsertPayload({required String userId}) {
    return <String, Object?>{
      'user_id': userId,
      'tool_name': toolName,
      'gpu_profile': gpuProfile.wireValue,
      'model_id': modelId,
      'input_tokens': inputTokens,
      'output_tokens': outputTokens,
      'api_request_count': apiRequestCount,
      'latency_ms': latencyMs,
      'estimated_compute_cost_usd': estimatedComputeCostUsd,
      'cost_threshold_usd': costThresholdUsd,
      'threshold_alert_triggered': estimatedComputeCostUsd >= costThresholdUsd,
    };
  }
}

/// システム全体コスト閾値設定 (`ai_compute_cost_alert_settings`) (#2658).
@immutable
class AiComputeThresholdSettings {
  const AiComputeThresholdSettings({
    required this.dailyThresholdUsd,
    required this.monthlyThresholdUsd,
    required this.updatedAt,
  });

  factory AiComputeThresholdSettings.defaults() {
    return AiComputeThresholdSettings(
      dailyThresholdUsd: 50.0,
      monthlyThresholdUsd: 500.0,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  factory AiComputeThresholdSettings.fromSupabaseRow(
    Map<String, Object?> row,
  ) {
    final rawUpdated = row['updated_at'] as String?;
    final parsedUpdated = rawUpdated != null
        ? DateTime.tryParse(rawUpdated)?.toUtc() ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)
        : DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    return AiComputeThresholdSettings(
      dailyThresholdUsd:
          (row['daily_cost_threshold_usd'] as num?)?.toDouble() ?? 50.0,
      monthlyThresholdUsd:
          (row['monthly_cost_threshold_usd'] as num?)?.toDouble() ?? 500.0,
      updatedAt: parsedUpdated,
    );
  }

  final double dailyThresholdUsd;
  final double monthlyThresholdUsd;
  final DateTime updatedAt;
}

/// 日別・月別集計バケット (#2658).
@immutable
class ComputeCostPeriodBucket {
  const ComputeCostPeriodBucket({
    required this.bucketKey,
    required this.requestCount,
    required this.totalTokens,
    required this.avgLatencyMs,
    required this.totalEstimatedCostUsd,
  });

  final String bucketKey;
  final int requestCount;
  final int totalTokens;
  final double avgLatencyMs;
  final double totalEstimatedCostUsd;
}

/// ユーザー別利用頻度サマリー (#2658).
@immutable
class UserUtilizationSummary {
  const UserUtilizationSummary({
    required this.userId,
    required this.requestCount,
    required this.totalTokens,
    required this.avgLatencyMs,
    required this.totalEstimatedCostUsd,
  });

  final String userId;
  final int requestCount;
  final int totalTokens;
  final double avgLatencyMs;
  final double totalEstimatedCostUsd;
}

/// 初期ダッシュボード読込ペイロード (#2658).
@immutable
class AiComputeDashboardSnapshot {
  const AiComputeDashboardSnapshot({
    required this.entries,
    required this.thresholdSettings,
    required this.isAdmin,
  });

  final List<AiComputeTelemetryEntry> entries;
  final AiComputeThresholdSettings thresholdSettings;
  final bool isAdmin;
}

/// 設定可能なレートカードに基づく概算計算コスト算出器 (#2658).
class AiComputeCostEstimator {
  const AiComputeCostEstimator._();

  static const String estimateDisclaimer =
      'USD 表示の計算コストはレートカードに基づく運用監視用の概算値であり、正式なクラウド請求金額ではありません。';

  static double estimateUsd({
    required GpuComputeProfile gpuProfile,
    required int inputTokens,
    required int outputTokens,
    required int apiRequestCount,
    required int latencyMs,
  }) {
    final safeLatency = latencyMs < 0 ? 0 : latencyMs;
    final safeReqs = apiRequestCount < 1 ? 1 : apiRequestCount;
    final safeInput = inputTokens < 0 ? 0 : inputTokens;
    final safeOutput = outputTokens < 0 ? 0 : outputTokens;

    final gpuSeconds = (safeLatency / 1000.0) * safeReqs;
    final computeCost = gpuSeconds * gpuProfile.perSecondUsd;
    final tokenCost = (safeInput / 1000.0) * gpuProfile.per1kInputUsd +
        (safeOutput / 1000.0) * gpuProfile.per1kOutputUsd;

    return ((computeCost + tokenCost) * 1000000).roundToDouble() / 1000000;
  }

  static AiComputeTelemetryEntry createDraft({
    required String toolName,
    required GpuComputeProfile gpuProfile,
    required String modelId,
    required int inputTokens,
    required int outputTokens,
    required int apiRequestCount,
    required int latencyMs,
    required double costThresholdUsd,
    DateTime? now,
  }) {
    final estimated = estimateUsd(
      gpuProfile: gpuProfile,
      inputTokens: inputTokens,
      outputTokens: outputTokens,
      apiRequestCount: apiRequestCount,
      latencyMs: latencyMs,
    );
    return AiComputeTelemetryEntry(
      id: 'pending-local',
      userId: '',
      toolName: toolName.trim().isEmpty ? 'ai-hub' : toolName.trim(),
      gpuProfile: gpuProfile,
      modelId: modelId.trim().isEmpty ? 'gemini-2.5-flash' : modelId.trim(),
      inputTokens: inputTokens < 0 ? 0 : inputTokens,
      outputTokens: outputTokens < 0 ? 0 : outputTokens,
      apiRequestCount: apiRequestCount < 1 ? 1 : apiRequestCount,
      latencyMs: latencyMs < 0 ? 0 : latencyMs,
      estimatedComputeCostUsd: estimated,
      costThresholdUsd: costThresholdUsd <= 0 ? 50.0 : costThresholdUsd,
      thresholdAlertTriggered:
          estimated >= (costThresholdUsd <= 0 ? 50.0 : costThresholdUsd),
      recordedAt: (now ?? DateTime.now()).toUtc(),
    );
  }
}

/// テレメトリ・閾値設定リポジトリ契約 (#2658).
abstract interface class AiComputeCostMonitorRepository {
  Future<AiComputeDashboardSnapshot> fetchDashboard();

  Future<AiComputeTelemetryEntry> recordTelemetry(
    AiComputeTelemetryEntry draft,
  );

  Future<AiComputeThresholdSettings> updateThresholds({
    required double dailyThresholdUsd,
    required double monthlyThresholdUsd,
  });
}
