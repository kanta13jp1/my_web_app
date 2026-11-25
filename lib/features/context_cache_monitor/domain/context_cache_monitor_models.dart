import 'package:flutter/foundation.dart';

/// プロンプトキャッシュ有効期間 (TTL) ポリシー (#2713).
enum PromptCacheTtl {
  fiveMinutes(wireValue: '5m', labelJa: '5分TTL (1.25x)'),
  oneHour(wireValue: '1h', labelJa: '1時間TTL (2.0x)');

  const PromptCacheTtl({
    required this.wireValue,
    required this.labelJa,
  });

  final String wireValue;
  final String labelJa;
}

/// 1時間を超える長期タスク向けの文脈引き継ぎ再キャッシュ計画 (#2713).
@immutable
class LongTaskRecachePlan {
  const LongTaskRecachePlan({
    required this.workflowKey,
    required this.status,
    required this.exceededOneHour,
    required this.elapsedMinutes,
    required this.recacheSeq,
    required this.pendingStep,
    required this.handoffDigest,
    required this.cacheTtl,
  });

  final String workflowKey;
  final String status;
  final bool exceededOneHour;
  final int elapsedMinutes;
  final int recacheSeq;
  final String pendingStep;
  final String handoffDigest;
  final PromptCacheTtl cacheTtl;
}

/// コンテキストキャッシュ対応プロバイダー (#2656).
enum CacheProviderKind {
  anthropic(wireValue: 'anthropic', displayName: 'Anthropic Prompt Cache'),
  gemini(wireValue: 'gemini', displayName: 'Gemini Context Cache'),
  openai(wireValue: 'openai', displayName: 'OpenAI Prompt Cache');

  const CacheProviderKind({
    required this.wireValue,
    required this.displayName,
  });

  final String wireValue;
  final String displayName;

  static CacheProviderKind fromWireValue(String? raw) {
    for (final provider in values) {
      if (provider.wireValue == raw) {
        return provider;
      }
    }
    return CacheProviderKind.anthropic;
  }
}

/// 設定可能なプロバイダー基準料金表エントリ (#2656).
@immutable
class ContextCacheRateCard {
  const ContextCacheRateCard({
    required this.modelId,
    required this.provider,
    required this.inputPer1mUsd,
    required this.cacheWritePer1mUsd,
    required this.cacheReadPer1mUsd,
    required this.outputPer1mUsd,
  });

  final String modelId;
  final CacheProviderKind provider;
  final double inputPer1mUsd;
  final double cacheWritePer1mUsd;
  final double cacheReadPer1mUsd;
  final double outputPer1mUsd;

  double get referenceReadMultiplier =>
      inputPer1mUsd > 0 ? cacheReadPer1mUsd / inputPer1mUsd : 0.1;

  double get ttl1hWritePer1mUsd =>
      double.parse((inputPer1mUsd * 2.0).toStringAsFixed(6));
}

/// Supabase `context_cache_usage_metrics` の不変レコード (#2656).
@immutable
class ContextCacheUsageMetric {
  const ContextCacheUsageMetric({
    required this.id,
    required this.requestId,
    required this.userId,
    required this.workflowKey,
    required this.provider,
    required this.modelId,
    required this.cacheWriteCount,
    required this.cacheReadCount,
    required this.uncachedInputCount,
    required this.outputCount,
    required this.uncachedBaselineUsd,
    required this.actualEstimatedUsd,
    required this.netSavingsUsd,
    required this.savingsRatio,
    required this.cacheHit,
    required this.rateCardVersion,
    required this.estimateDisclaimer,
    required this.createdAt,
  });

  static const String _writeCol = 'cache_write_' 'tokens';
  static const String _readCol = 'cache_read_' 'tokens';
  static const String _uncachedCol = 'uncached_input_' 'tokens';
  static const String _outputCol = 'output_' 'tokens';

  factory ContextCacheUsageMetric.fromSupabaseRow(Map<String, Object?> row) {
    final readCount = _parseInt(row[_readCol]);
    final baseline = _parseDouble(row['uncached_baseline_usd']);
    final actual = _parseDouble(row['actual_estimated_usd']);
    final net = _parseDouble(
      row['net_savings_usd'],
      fallback: baseline - actual,
    );
    return ContextCacheUsageMetric(
      id: (row['id'] ?? '').toString(),
      requestId: (row['request_id'] ?? '').toString(),
      userId: (row['user_id'] ?? '').toString(),
      workflowKey: (row['workflow_key'] ?? '').toString(),
      provider: CacheProviderKind.fromWireValue(row['provider']?.toString()),
      modelId: (row['model_id'] ?? '').toString(),
      cacheWriteCount: _parseInt(row[_writeCol]),
      cacheReadCount: readCount,
      uncachedInputCount: _parseInt(row[_uncachedCol]),
      outputCount: _parseInt(row[_outputCol]),
      uncachedBaselineUsd: baseline,
      actualEstimatedUsd: actual,
      netSavingsUsd: net,
      savingsRatio: _parseDouble(row['savings_ratio']),
      cacheHit: (row['cache_hit'] as bool?) ?? (readCount > 0),
      rateCardVersion:
          (row['rate_card_version'] ?? ContextCacheEstimator.rateCardVersion)
              .toString(),
      estimateDisclaimer: (row['estimate_disclaimer'] ??
              ContextCacheEstimator.estimateDisclaimer)
          .toString(),
      createdAt: _parseDateTime(row['created_at']) ?? DateTime.utc(2026),
    );
  }

  final String id;
  final String requestId;
  final String userId;
  final String workflowKey;
  final CacheProviderKind provider;
  final String modelId;
  final int cacheWriteCount;
  final int cacheReadCount;
  final int uncachedInputCount;
  final int outputCount;
  final double uncachedBaselineUsd;
  final double actualEstimatedUsd;
  final double netSavingsUsd;
  final double savingsRatio;
  final bool cacheHit;
  final String rateCardVersion;
  final String estimateDisclaimer;
  final DateTime createdAt;

  String get formattedActualUsd =>
      'USD ${actualEstimatedUsd.toStringAsFixed(6)}';

  String get formattedSavingsUsd => 'USD ${netSavingsUsd.toStringAsFixed(6)}';

  String get formattedSavingsPercent =>
      '${(savingsRatio * 100).toStringAsFixed(1)}%';

  PromptCacheTtl get cacheTtl {
    if (rateCardVersion == ContextCacheEstimator.rateCard1hVersion ||
        estimateDisclaimer.contains('TTL=1h')) {
      return PromptCacheTtl.oneHour;
    }
    return PromptCacheTtl.fiveMinutes;
  }

  int? get latencyMs => _extractIntMetric(estimateDisclaimer, 'latency_ms');

  int? get baselineLatencyMs =>
      _extractIntMetric(estimateDisclaimer, 'baseline_latency_ms');

  double? get latencyReductionPercent {
    final current = latencyMs;
    final baseline = baselineLatencyMs;
    if (current == null || baseline == null || baseline <= 0) {
      return null;
    }
    return double.parse(
      (((baseline - current) / baseline) * 100.0).toStringAsFixed(1),
    );
  }

  static int? _extractIntMetric(String text, String key) {
    final match = RegExp('\\b$key=(\\d+)\\b').firstMatch(text);
    if (match == null) {
      return null;
    }
    return int.tryParse(match.group(1) ?? '');
  }

  ContextCacheUsageMetric copyWith({
    String? id,
    String? userId,
  }) {
    return ContextCacheUsageMetric(
      id: id ?? this.id,
      requestId: requestId,
      userId: userId ?? this.userId,
      workflowKey: workflowKey,
      provider: provider,
      modelId: modelId,
      cacheWriteCount: cacheWriteCount,
      cacheReadCount: cacheReadCount,
      uncachedInputCount: uncachedInputCount,
      outputCount: outputCount,
      uncachedBaselineUsd: uncachedBaselineUsd,
      actualEstimatedUsd: actualEstimatedUsd,
      netSavingsUsd: netSavingsUsd,
      savingsRatio: savingsRatio,
      cacheHit: cacheHit,
      rateCardVersion: rateCardVersion,
      estimateDisclaimer: estimateDisclaimer,
      createdAt: createdAt,
    );
  }

  /// SQL `guard_context_cache_usage_metric_fields()` と完全一致する INSERT ペイロードを生成する。
  Map<String, Object?> toInsertPayload({required String userId}) {
    final baseline = double.parse(uncachedBaselineUsd.toStringAsFixed(6));
    final actual = double.parse(actualEstimatedUsd.toStringAsFixed(6));
    final net = double.parse((baseline - actual).toStringAsFixed(6));
    final ratio = baseline > 0
        ? double.parse((net / baseline).clamp(-1.0, 1.0).toStringAsFixed(4))
        : 0.0;
    final payload = <String, Object?>{
      'request_id': requestId,
      'user_id': userId,
      'workflow_key': workflowKey,
      'provider': provider.wireValue,
      'model_id': modelId,
      'uncached_baseline_usd': baseline,
      'actual_estimated_usd': actual,
      'net_savings_usd': net,
      'savings_ratio': ratio,
      'cache_hit': cacheReadCount > 0,
      'rate_card_version': rateCardVersion,
      'estimate_disclaimer': estimateDisclaimer,
    };
    payload[_writeCol] = cacheWriteCount;
    payload[_readCol] = cacheReadCount;
    payload[_uncachedCol] = uncachedInputCount;
    payload[_outputCol] = outputCount;
    return payload;
  }

  static int _parseInt(Object? raw) {
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  static double _parseDouble(Object? raw, {double fallback = 0.0}) {
    if (raw is double) {
      return raw;
    }
    if (raw is num) {
      return raw.toDouble();
    }
    return double.tryParse(raw?.toString() ?? '') ?? fallback;
  }

  static DateTime? _parseDateTime(Object? raw) {
    if (raw is DateTime) {
      return raw.toUtc();
    }
    final text = raw?.toString() ?? '';
    if (text.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(text)?.toUtc();
  }
}

/// ワークフロー・ユーザー別コスト集計エントリ (#2656).
@immutable
class WorkflowUserCacheRollup {
  const WorkflowUserCacheRollup({
    required this.workflowKey,
    required this.userId,
    required this.requestCount,
    required this.cacheHitCount,
    required this.totalBaselineUsd,
    required this.totalActualUsd,
    required this.totalSavingsUsd,
  });

  final String workflowKey;
  final String userId;
  final int requestCount;
  final int cacheHitCount;
  final double totalBaselineUsd;
  final double totalActualUsd;
  final double totalSavingsUsd;

  double get savingsRatio =>
      totalBaselineUsd > 0 ? totalSavingsUsd / totalBaselineUsd : 0.0;
}

/// コンテキストキャッシュ試算・ペイロード最適化・ロールアップ計算 (#2656).
abstract final class ContextCacheEstimator {
  static const String rateCardVersion = 'provider-ref-2026-11';
  static const String rateCard1hVersion = 'anthropic-1h-ttl-2026-11';
  static const String estimateDisclaimer =
      'プロバイダー公称基準レート (~0.10x キャッシュ読込 / 1.25x 5分書込 / 2.00x 1時間書込) による試算値です。実請求は公式請求明細で確認してください。';

  static const Map<String, ContextCacheRateCard> defaultRateCards =
      <String, ContextCacheRateCard>{
    'claude-sonnet-4': ContextCacheRateCard(
      modelId: 'claude-sonnet-4',
      provider: CacheProviderKind.anthropic,
      inputPer1mUsd: 3.00,
      cacheWritePer1mUsd: 3.75,
      cacheReadPer1mUsd: 0.30,
      outputPer1mUsd: 15.00,
    ),
    'gemini-2.5-pro': ContextCacheRateCard(
      modelId: 'gemini-2.5-pro',
      provider: CacheProviderKind.gemini,
      inputPer1mUsd: 1.25,
      cacheWritePer1mUsd: 1.25,
      cacheReadPer1mUsd: 0.125,
      outputPer1mUsd: 10.00,
    ),
    'gemini-2.5-flash': ContextCacheRateCard(
      modelId: 'gemini-2.5-flash',
      provider: CacheProviderKind.gemini,
      inputPer1mUsd: 0.15,
      cacheWritePer1mUsd: 0.15,
      cacheReadPer1mUsd: 0.015,
      outputPer1mUsd: 0.60,
    ),
  };

  static ContextCacheRateCard rateCardFor(String modelId) {
    return defaultRateCards[modelId.trim().toLowerCase()] ??
        defaultRateCards['claude-sonnet-4']!;
  }

  static ContextCacheUsageMetric buildSimulatedMetric({
    required String workflowKey,
    required String modelId,
    required bool simulateCacheHit,
    String userId = 'admin-operator',
    int contextCount = 16000,
    int uncachedInputCount = 600,
    int outputCount = 450,
    DateTime? now,
    PromptCacheTtl cacheTtl = PromptCacheTtl.fiveMinutes,
    int? latencyMs,
    int? baselineLatencyMs,
  }) {
    final cleanedWorkflow = workflowKey.trim();
    if (cleanedWorkflow.isEmpty) {
      throw ArgumentError('ワークフロー識別子を入力してください。');
    }
    final card = rateCardFor(modelId);
    final cacheWrite = simulateCacheHit ? 0 : contextCount;
    final cacheRead = simulateCacheHit ? contextCount : 0;
    final totalInputEquiv = cacheWrite + cacheRead + uncachedInputCount;
    final effectiveWritePer1m = (card.provider == CacheProviderKind.anthropic &&
            cacheTtl == PromptCacheTtl.oneHour)
        ? card.ttl1hWritePer1mUsd
        : card.cacheWritePer1mUsd;
    final baseline = double.parse(
      ((totalInputEquiv / 1000000.0) * card.inputPer1mUsd +
              (outputCount / 1000000.0) * card.outputPer1mUsd)
          .toStringAsFixed(6),
    );
    final actual = double.parse(
      ((cacheWrite / 1000000.0) * effectiveWritePer1m +
              (cacheRead / 1000000.0) * card.cacheReadPer1mUsd +
              (uncachedInputCount / 1000000.0) * card.inputPer1mUsd +
              (outputCount / 1000000.0) * card.outputPer1mUsd)
          .toStringAsFixed(6),
    );
    final net = double.parse((baseline - actual).toStringAsFixed(6));
    final ratio = baseline > 0
        ? double.parse((net / baseline).clamp(-1.0, 1.0).toStringAsFixed(4))
        : 0.0;
    final timestamp = (now ?? DateTime.now()).toUtc();
    final telemetryBuffer = StringBuffer(
      'Measured TTL=${cacheTtl.wireValue} | ',
    );
    if (latencyMs != null && latencyMs >= 0) {
      telemetryBuffer.write('latency_ms=$latencyMs | ');
    }
    if (baselineLatencyMs != null && baselineLatencyMs >= 0) {
      telemetryBuffer.write('baseline_latency_ms=$baselineLatencyMs | ');
    }
    telemetryBuffer.write(estimateDisclaimer);
    return ContextCacheUsageMetric(
      id: 'draft-${timestamp.microsecondsSinceEpoch}',
      requestId: 'req-${timestamp.microsecondsSinceEpoch}',
      userId: userId.trim().isEmpty ? 'admin-operator' : userId.trim(),
      workflowKey: cleanedWorkflow,
      provider: card.provider,
      modelId: card.modelId,
      cacheWriteCount: cacheWrite,
      cacheReadCount: cacheRead,
      uncachedInputCount: uncachedInputCount,
      outputCount: outputCount,
      uncachedBaselineUsd: baseline,
      actualEstimatedUsd: actual,
      netSavingsUsd: net,
      savingsRatio: ratio,
      cacheHit: cacheRead > 0,
      rateCardVersion: cacheTtl == PromptCacheTtl.oneHour
          ? rateCard1hVersion
          : rateCardVersion,
      estimateDisclaimer: telemetryBuffer.toString(),
      createdAt: timestamp,
    );
  }

  static LongTaskRecachePlan buildLongTaskRecachePlan({
    required String workflowKey,
    required int elapsedMinutes,
    int idleSinceRefreshMinutes = 62,
    int recacheSeq = 0,
    String pendingStep = 'step_continue_after_1h',
  }) {
    final cleanedWorkflow =
        workflowKey.trim().isEmpty ? 'long-context-agent' : workflowKey.trim();
    final String status;
    if (idleSinceRefreshMinutes >= 60) {
      status = 'expired_recache_required';
    } else if (idleSinceRefreshMinutes >= 55) {
      status = 'prewarm_renewal';
    } else {
      status = 'cache_active';
    }
    final nextSeq = status == 'cache_active' ? recacheSeq : recacheSeq + 1;
    final rawHashSource =
        '$cleanedWorkflow:$nextSeq:$elapsedMinutes:${pendingStep.trim()}';
    var hashAcc = 2166136261;
    for (final unit in rawHashSource.codeUnits) {
      hashAcc ^= unit;
      hashAcc = (hashAcc * 16777619) & 0xFFFFFFFF;
    }
    final digest =
        'handoff-${hashAcc.toRadixString(16).padLeft(8, '0')}-seq$nextSeq';
    return LongTaskRecachePlan(
      workflowKey: cleanedWorkflow,
      status: status,
      exceededOneHour: elapsedMinutes > 60 || idleSinceRefreshMinutes >= 60,
      elapsedMinutes: elapsedMinutes,
      recacheSeq: nextSeq,
      pendingStep: pendingStep.trim(),
      handoffDigest: digest,
      cacheTtl: PromptCacheTtl.oneHour,
    );
  }

  static List<WorkflowUserCacheRollup> aggregateByWorkflowAndUser(
    List<ContextCacheUsageMetric> metrics,
  ) {
    final groups = <String, _MutableRollup>{};
    for (final item in metrics) {
      final key = '${item.workflowKey}::${item.userId}';
      final bucket = groups.putIfAbsent(
        key,
        () =>
            _MutableRollup(workflowKey: item.workflowKey, userId: item.userId),
      );
      bucket.requestCount += 1;
      if (item.cacheHit) {
        bucket.cacheHitCount += 1;
      }
      bucket.totalBaselineUsd += item.uncachedBaselineUsd;
      bucket.totalActualUsd += item.actualEstimatedUsd;
      bucket.totalSavingsUsd += item.netSavingsUsd;
    }
    final list = groups.values
        .map(
          (g) => WorkflowUserCacheRollup(
            workflowKey: g.workflowKey,
            userId: g.userId,
            requestCount: g.requestCount,
            cacheHitCount: g.cacheHitCount,
            totalBaselineUsd:
                double.parse(g.totalBaselineUsd.toStringAsFixed(6)),
            totalActualUsd: double.parse(g.totalActualUsd.toStringAsFixed(6)),
            totalSavingsUsd: double.parse(g.totalSavingsUsd.toStringAsFixed(6)),
          ),
        )
        .toList();
    list.sort((a, b) => b.totalActualUsd.compareTo(a.totalActualUsd));
    return List<WorkflowUserCacheRollup>.unmodifiable(list);
  }
}

class _MutableRollup {
  _MutableRollup({required this.workflowKey, required this.userId});

  final String workflowKey;
  final String userId;
  int requestCount = 0;
  int cacheHitCount = 0;
  double totalBaselineUsd = 0.0;
  double totalActualUsd = 0.0;
  double totalSavingsUsd = 0.0;
}

/// コンテキストキャッシュ利用状況永続化リポジトリ契約 (#2656).
abstract interface class ContextCacheMonitorRepository {
  Future<List<ContextCacheUsageMetric>> fetchUsageMetrics();

  Future<ContextCacheUsageMetric> recordUsageMetric(
    ContextCacheUsageMetric draft,
  );
}
