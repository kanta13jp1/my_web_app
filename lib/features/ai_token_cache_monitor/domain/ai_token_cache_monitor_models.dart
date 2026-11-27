import 'package:flutter/foundation.dart';

Map<String, Object?> normalizeJsonObject(Object? raw, String context) {
  if (raw is! Map<Object?, Object?>) {
    throw FormatException('Expected JSON object for $context.');
  }
  final normalized = <String, Object?>{};
  for (final entry in raw.entries) {
    final Object? key = entry.key;
    if (key is! String) {
      throw FormatException('Expected String keys in $context.');
    }
    normalized[key] = entry.value;
  }
  return normalized;
}

String _requireNonEmptyString(Map<String, Object?> json, String key) {
  final Object? raw = json[key];
  if (raw is! String || raw.trim().isEmpty) {
    throw FormatException('Missing or invalid non-empty String "$key".');
  }
  return raw;
}

String _requireString(Map<String, Object?> json, String key) {
  final Object? raw = json[key];
  if (raw is! String) {
    throw FormatException('Missing or invalid String "$key".');
  }
  return raw;
}

int _requireInt(Map<String, Object?> json, String key) {
  final Object? raw = json[key];
  if (raw is! int) {
    throw FormatException('Missing or invalid int "$key".');
  }
  return raw;
}

double _requireDouble(Map<String, Object?> json, String key) {
  final Object? raw = json[key];
  if (raw is! num) {
    throw FormatException('Missing or invalid num "$key".');
  }
  return raw.toDouble();
}

List<String> _requireStringList(Map<String, Object?> json, String key) {
  final Object? raw = json[key];
  if (raw is! List<Object?>) {
    throw FormatException('Missing or invalid List "$key".');
  }
  final result = <String>[];
  for (final item in raw) {
    if (item is! String) {
      throw FormatException('List "$key" contains non-String element.');
    }
    result.add(item);
  }
  return List<String>.unmodifiable(result);
}

enum ModelSpecializationTier {
  searchToolDiscovery('search_tool_discovery'),
  boundedExecution('bounded_execution'),
  complexReasoning('complex_reasoning');

  const ModelSpecializationTier(this.wireValue);

  final String wireValue;

  static ModelSpecializationTier fromValue(Object? raw) {
    if (raw is! String) {
      throw FormatException(
        'Expected String for specializationTier, got ${raw.runtimeType}.',
      );
    }
    for (final value in ModelSpecializationTier.values) {
      if (value.wireValue == raw) {
        return value;
      }
    }
    throw FormatException('Unknown ModelSpecializationTier: "$raw".');
  }
}

@immutable
class ToolUsageBreakdownEntry {
  const ToolUsageBreakdownEntry({
    required this.toolName,
    required this.modelId,
    required this.specializationTier,
    required this.requestCount,
    required this.inputUnits,
    required this.outputUnits,
    required this.totalUnits,
    required this.avgLatencyMs,
  });

  final String toolName;
  final String modelId;
  final ModelSpecializationTier specializationTier;
  final int requestCount;
  final int inputUnits;
  final int outputUnits;
  final int totalUnits;
  final int avgLatencyMs;

  factory ToolUsageBreakdownEntry.fromJson(Map<String, Object?> json) {
    return ToolUsageBreakdownEntry(
      toolName: _requireNonEmptyString(json, 'toolName'),
      modelId: _requireNonEmptyString(json, 'modelId'),
      specializationTier: ModelSpecializationTier.fromValue(
        json['specializationTier'],
      ),
      requestCount: _requireInt(json, 'requestCount'),
      inputUnits: _requireInt(json, 'inputUnits'),
      outputUnits: _requireInt(json, 'outputUnits'),
      totalUnits: _requireInt(json, 'totalUnits'),
      avgLatencyMs: _requireInt(json, 'avgLatencyMs'),
    );
  }
}

@immutable
class ModelSpecializationSpec {
  const ModelSpecializationSpec({
    required this.tier,
    required this.labelJa,
    required this.recommendedModels,
    required this.primaryUseCases,
    required this.cachingStrategy,
    required this.measurementScope,
  });

  final ModelSpecializationTier tier;
  final String labelJa;
  final List<String> recommendedModels;
  final List<String> primaryUseCases;
  final String cachingStrategy;
  final String measurementScope;

  factory ModelSpecializationSpec.fromJson(Map<String, Object?> json) {
    return ModelSpecializationSpec(
      tier: ModelSpecializationTier.fromValue(json['tier']),
      labelJa: _requireNonEmptyString(json, 'labelJa'),
      recommendedModels: _requireStringList(json, 'recommendedModels'),
      primaryUseCases: _requireStringList(json, 'primaryUseCases'),
      cachingStrategy: _requireNonEmptyString(json, 'cachingStrategy'),
      measurementScope: _requireNonEmptyString(json, 'measurementScope'),
    );
  }
}

@immutable
class PrefixStabilityDiagnostic {
  const PrefixStabilityDiagnostic({
    required this.stabilityScore,
    required this.status,
    required this.warnings,
    required this.recommendations,
  });

  final int stabilityScore;
  final String status;
  final List<String> warnings;
  final List<String> recommendations;

  factory PrefixStabilityDiagnostic.fromJson(Map<String, Object?> json) {
    return PrefixStabilityDiagnostic(
      stabilityScore: _requireInt(json, 'stabilityScore'),
      status: _requireNonEmptyString(json, 'status'),
      warnings: _requireStringList(json, 'warnings'),
      recommendations: _requireStringList(json, 'recommendations'),
    );
  }
}

@immutable
class TokenCacheSummarySnapshot {
  const TokenCacheSummarySnapshot({
    required this.totalRequests,
    required this.totalInputUnits,
    required this.totalOutputUnits,
    required this.totalUsageUnits,
    required this.cachedReadUnits,
    required this.cacheWriteUnits,
    required this.uncachedInputUnits,
    required this.cacheHitCount,
    required this.cacheRequestCount,
    required this.cacheReuseRatio,
    required this.cacheHitRate,
    required this.totalNetSavingsUsd,
    required this.perToolBreakdown,
    required this.specializationMatrix,
  });

  final int totalRequests;
  final int totalInputUnits;
  final int totalOutputUnits;
  final int totalUsageUnits;
  final int cachedReadUnits;
  final int cacheWriteUnits;
  final int uncachedInputUnits;
  final int cacheHitCount;
  final int cacheRequestCount;
  final double cacheReuseRatio;
  final double cacheHitRate;
  final double totalNetSavingsUsd;
  final List<ToolUsageBreakdownEntry> perToolBreakdown;
  final List<ModelSpecializationSpec> specializationMatrix;

  factory TokenCacheSummarySnapshot.fromJson(Map<String, Object?> json) {
    final Object? rawTools = json['perToolBreakdown'];
    if (rawTools is! List<Object?>) {
      throw const FormatException('Missing List "perToolBreakdown".');
    }
    final tools = rawTools
        .map(
          (item) => ToolUsageBreakdownEntry.fromJson(
            normalizeJsonObject(item, 'perToolBreakdown[]'),
          ),
        )
        .toList(growable: false);

    final Object? rawMatrix = json['specializationMatrix'];
    if (rawMatrix is! List<Object?>) {
      throw const FormatException('Missing List "specializationMatrix".');
    }
    final matrix = rawMatrix
        .map(
          (item) => ModelSpecializationSpec.fromJson(
            normalizeJsonObject(item, 'specializationMatrix[]'),
          ),
        )
        .toList(growable: false);

    return TokenCacheSummarySnapshot(
      totalRequests: _requireInt(json, 'totalRequests'),
      totalInputUnits: _requireInt(json, 'totalInputUnits'),
      totalOutputUnits: _requireInt(json, 'totalOutputUnits'),
      totalUsageUnits: _requireInt(json, 'totalUsageUnits'),
      cachedReadUnits: _requireInt(json, 'cachedReadUnits'),
      cacheWriteUnits: _requireInt(json, 'cacheWriteUnits'),
      uncachedInputUnits: _requireInt(json, 'uncachedInputUnits'),
      cacheHitCount: _requireInt(json, 'cacheHitCount'),
      cacheRequestCount: _requireInt(json, 'cacheRequestCount'),
      cacheReuseRatio: _requireDouble(json, 'cacheReuseRatio'),
      cacheHitRate: _requireDouble(json, 'cacheHitRate'),
      totalNetSavingsUsd: _requireDouble(json, 'totalNetSavingsUsd'),
      perToolBreakdown: List<ToolUsageBreakdownEntry>.unmodifiable(tools),
      specializationMatrix: List<ModelSpecializationSpec>.unmodifiable(matrix),
    );
  }
}

class LocalPrefixStabilityAnalyzer {
  const LocalPrefixStabilityAnalyzer();

  static final RegExp _isoTimestampRe = RegExp(
    r'\b20\d{2}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}',
  );
  static final RegExp _uuidRe = RegExp(
    r'\b[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\b',
    caseSensitive: false,
  );

  PrefixStabilityDiagnostic analyze({
    required String systemPrompt,
    required int toolCount,
    required bool useToolSearch,
    required int breakpointCount,
  }) {
    int score = 100;
    final warnings = <String>[];
    final recs = <String>[];

    if (_isoTimestampRe.hasMatch(systemPrompt)) {
      score -= 35;
      warnings.add('静的プレフィックス内にタイムスタンプが含まれています。');
      recs.add('現在時刻はキャッシュブレークポイント後方の末尾メッセージへ移動してください。');
    }
    if (_uuidRe.hasMatch(systemPrompt)) {
      score -= 25;
      warnings.add('静的プレフィックス内に UUID が混入しています。');
      recs.add('セッション ID 等の動的識別子はシステム命令先頭から除外してください。');
    }
    if (toolCount > 15 && !useToolSearch) {
      score -= 20;
      warnings.add('$toolCount 個のツールが遅延ロード無しで展開されています。');
      recs.add('Tool Search Tool を有効化し、必須ツールのみ静的プレフィックスへ配置してください。');
    }
    if (breakpointCount <= 0) {
      score -= 15;
      warnings.add('キャッシュブレークポイントが未設定です。');
      recs.add('システム指示＋ツール定義直後に ephemeral ブレークポイントを配置してください。');
    }

    final int bounded = score.clamp(0, 100);
    final String status =
        bounded >= 85 ? 'optimal' : (bounded >= 60 ? 'warning' : 'unstable');

    return PrefixStabilityDiagnostic(
      stabilityScore: bounded,
      status: status,
      warnings: List<String>.unmodifiable(warnings),
      recommendations: List<String>.unmodifiable(recs),
    );
  }
}

String describeIssueNote(Object? raw) =>
    raw is String ? _requireString(<String, Object?>{'v': raw}, 'v') : '';

abstract interface class AiTokenCacheMonitorRepository {
  Future<TokenCacheSummarySnapshot> fetchSummary({int limit = 50});

  Future<PrefixStabilityDiagnostic> diagnosePrefix({
    required String systemPrompt,
    required int toolCount,
    required bool useToolSearch,
    required int breakpointCount,
  });

  Future<PrefixStabilityDiagnostic> recordToolUsage({
    required String toolName,
    required String modelId,
    required int inputUnits,
    required int outputUnits,
    required int cachedReadUnits,
    required String systemPrompt,
    required int toolCount,
    required bool useToolSearch,
    required int breakpointCount,
  });
}
