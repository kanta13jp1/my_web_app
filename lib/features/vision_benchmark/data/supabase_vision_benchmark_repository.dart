import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/vision_benchmark_models.dart';

/// Supabase `app-hub` repository for Vision benchmark monitoring (#2758).
class SupabaseVisionBenchmarkRepository implements VisionBenchmarkRepository {
  SupabaseVisionBenchmarkRepository({final SupabaseClient? client})
      : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _resolvedClient => _client ?? Supabase.instance.client;

  String _requireUserId(final SupabaseClient client) {
    final userId = client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw StateError('Vision ベンチマーク監視を利用するにはログインが必要です。');
    }
    return userId;
  }

  Map<String, Object?> _decodePayload(final Object? raw) {
    final normalized = raw is String ? jsonDecode(raw) : raw;
    if (normalized is Map<Object?, Object?>) {
      return normalized.map<String, Object?>(
        (final Object? k, final Object? v) => MapEntry(k.toString(), v),
      );
    }
    return const <String, Object?>{};
  }

  VisionBenchmarkLevel _mapLevel(
    final Map<String, Object?> raw,
    final int index,
  ) {
    final score = (raw['score'] as num?)?.round() ?? 0;
    return VisionBenchmarkLevel(
      level: (raw['level'] ?? 'level${index + 1}').toString(),
      description: (raw['description'] ?? '').toString(),
      passed: raw['passed'] as bool? ?? score > 0,
      score: score.clamp(0, 100),
      maxPoints: (raw['maxPoints'] as num?)?.round() ?? 100,
      latencyMs:
          (raw['latency'] as num? ?? raw['latency_ms'] as num?)?.round() ?? 0,
      response: (raw['response'] ?? '').toString(),
    );
  }

  VisionBenchmarkRun _mapRun(
    final Map<String, Object?> raw,
    final int fallbackThreshold,
  ) {
    final rawLevels = raw['levels'];
    final levels = <VisionBenchmarkLevel>[];
    if (rawLevels is List<Object?>) {
      for (var i = 0; i < rawLevels.length; i++) {
        final item = rawLevels[i];
        if (item is Map<Object?, Object?>) {
          levels.add(
            _mapLevel(
              item.map<String, Object?>(
                (final Object? k, final Object? v) => MapEntry(k.toString(), v),
              ),
              i,
            ),
          );
        }
      }
    }
    final score = ((raw['score'] as num?)?.round() ?? 0).clamp(0, 100);
    final threshold = ((raw['threshold'] as num?)?.round() ?? fallbackThreshold)
        .clamp(1, 100);
    return VisionBenchmarkRun(
      id: (raw['id'] ?? '').toString(),
      model: (raw['model'] ?? 'unknown').toString(),
      provider: (raw['provider'] ?? 'unknown').toString(),
      score: score,
      latencyMs: (raw['latency_ms'] as num?)?.round() ?? 0,
      threshold: threshold,
      passed: raw['passed'] as bool? ?? score >= threshold,
      detail: (raw['detail'] ?? '').toString(),
      levels: List<VisionBenchmarkLevel>.unmodifiable(levels),
      recordedAt: DateTime.tryParse((raw['recorded_at'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  String _formatFunctionError(final FunctionException error) {
    if (error.status == 401) {
      return '認証の有効期限が切れています。再ログイン後に再試行してください。';
    }
    final details = error.details;
    if (details is Map<Object?, Object?> && details['error'] != null) {
      return details['error'].toString();
    }
    if (details != null && details.toString().trim().isNotEmpty) {
      return details.toString();
    }
    return error.reasonPhrase ??
        'Vision ベンチマーク API でエラーが発生しました (${error.status})';
  }

  @override
  Future<VisionBenchmarkSnapshot> fetchDashboard({
    required final int threshold,
    final String? modelFilter,
    final int limit = 40,
  }) async {
    final client = _resolvedClient;
    _requireUserId(client);
    final safeThreshold = threshold.clamp(1, 100);
    try {
      final response = await client.functions.invoke(
        'app-hub',
        body: <String, Object?>{
          'action': 'vision_benchmark.list',
          'threshold': safeThreshold,
          'limit': limit.clamp(1, 100),
          if (modelFilter != null && modelFilter.trim().isNotEmpty)
            'model': modelFilter.trim(),
        },
      );
      if (response.status >= 400) {
        throw StateError('Vision ベンチマーク取得に失敗しました (${response.status})');
      }
      final data = _decodePayload(response.data);
      final rawRuns = data['runs'];
      final runs = <VisionBenchmarkRun>[];
      if (rawRuns is List<Object?>) {
        for (final item in rawRuns) {
          if (item is Map<Object?, Object?>) {
            runs.add(
              _mapRun(
                item.map<String, Object?>(
                  (final Object? k, final Object? v) =>
                      MapEntry(k.toString(), v),
                ),
                safeThreshold,
              ),
            );
          }
        }
      }
      return VisionBenchmarkSnapshot.build(
        runs: runs,
        threshold: safeThreshold,
      );
    } on FunctionException catch (error) {
      throw StateError(_formatFunctionError(error));
    }
  }

  @override
  Future<VisionBenchmarkRun> recordRun({
    required final String model,
    required final String provider,
    required final int score,
    required final int latencyMs,
    required final int threshold,
    required final bool passed,
    required final String detail,
    final List<VisionBenchmarkLevel> levels = const <VisionBenchmarkLevel>[],
  }) async {
    final client = _resolvedClient;
    _requireUserId(client);
    final safeThreshold = threshold.clamp(1, 100);
    try {
      final response = await client.functions.invoke(
        'app-hub',
        body: <String, Object?>{
          'action': 'vision_benchmark.record',
          'model': model.trim(),
          'provider': provider.trim().isEmpty ? 'unknown' : provider.trim(),
          'score': score.clamp(0, 100),
          'latency_ms': latencyMs < 0 ? 0 : latencyMs,
          'threshold': safeThreshold,
          'passed': passed,
          'detail': detail.trim(),
          'levels': levels
              .take(6)
              .map((final VisionBenchmarkLevel level) => level.toJson())
              .toList(growable: false),
        },
      );
      if (response.status >= 400) {
        throw StateError('Vision ベンチマーク記録に失敗しました (${response.status})');
      }
      final data = _decodePayload(response.data);
      final rawRun = data['run'];
      if (rawRun is Map<Object?, Object?>) {
        return _mapRun(
          rawRun.map<String, Object?>(
            (final Object? k, final Object? v) => MapEntry(k.toString(), v),
          ),
          safeThreshold,
        );
      }
      throw StateError('Vision ベンチマーク記録の応答形式が不正です。');
    } on FunctionException catch (error) {
      throw StateError(_formatFunctionError(error));
    }
  }
}
