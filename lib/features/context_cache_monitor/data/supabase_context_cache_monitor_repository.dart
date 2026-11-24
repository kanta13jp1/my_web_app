import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/context_cache_monitor_models.dart';

/// Supabase `context_cache_usage_metrics` テーブル向け遅延 DI リポジトリ (#2656).
class SupabaseContextCacheMonitorRepository
    implements ContextCacheMonitorRepository {
  SupabaseContextCacheMonitorRepository({SupabaseClient? client})
      : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _resolvedClient => _client ?? Supabase.instance.client;

  String _requireUserId(SupabaseClient client) {
    final userId = client.auth.currentUser?.id;
    if (userId == null || userId.trim().isEmpty) {
      throw StateError('認証済みセッションが必要です。サインイン後に再試行してください。');
    }
    return userId;
  }

  Map<String, Object?>? _asStringMap(Object? raw) {
    if (raw is Map<String, Object?>) {
      return raw;
    }
    if (raw is Map<Object?, Object?>) {
      final normalized = <String, Object?>{};
      for (final entry in raw.entries) {
        if (entry.key != null) {
          normalized[entry.key.toString()] = entry.value;
        }
      }
      return normalized;
    }
    return null;
  }

  @override
  Future<List<ContextCacheUsageMetric>> fetchUsageMetrics() async {
    final client = _resolvedClient;
    _requireUserId(client);
    final Object response = await client
        .from('context_cache_usage_metrics')
        .select()
        .order('created_at', ascending: false)
        .limit(50);
    if (response is! List<Object?>) {
      return const <ContextCacheUsageMetric>[];
    }
    final items = <ContextCacheUsageMetric>[];
    for (final row in response) {
      final mapped = _asStringMap(row);
      if (mapped != null) {
        items.add(ContextCacheUsageMetric.fromSupabaseRow(mapped));
      }
    }
    return List<ContextCacheUsageMetric>.unmodifiable(items);
  }

  @override
  Future<ContextCacheUsageMetric> recordUsageMetric(
    ContextCacheUsageMetric draft,
  ) async {
    final client = _resolvedClient;
    final userId = _requireUserId(client);
    final payload = draft.toInsertPayload(userId: userId);
    final Object inserted = await client
        .from('context_cache_usage_metrics')
        .insert(payload)
        .select()
        .single();
    final mapped = _asStringMap(inserted);
    if (mapped != null) {
      return ContextCacheUsageMetric.fromSupabaseRow(mapped);
    }
    throw StateError('コンテキストキャッシュ利用ログの保存応答が不正です。');
  }
}
