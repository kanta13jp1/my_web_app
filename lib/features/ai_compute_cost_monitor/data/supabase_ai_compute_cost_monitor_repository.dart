import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/ai_compute_cost_monitor_models.dart';

/// Supabase `ai_compute_cost_telemetry` 向け遅延 DI リポジトリ (#2658).
class SupabaseAiComputeCostMonitorRepository
    implements AiComputeCostMonitorRepository {
  SupabaseAiComputeCostMonitorRepository({SupabaseClient? client})
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

  Map<String, Object?> _normalizeRow(Map<Object?, Object?> raw) {
    final normalized = <String, Object?>{};
    for (final entry in raw.entries) {
      if (entry.key != null) {
        normalized[entry.key.toString()] = entry.value;
      }
    }
    return normalized;
  }

  Future<bool> _fetchIsAdmin(SupabaseClient client, String userId) async {
    final Object response = await client
        .from('user_profiles')
        .select('is_admin')
        .eq('user_id', userId)
        .limit(1);

    if (response is List<Object?> && response.isNotEmpty) {
      final Object? first = response.first;
      if (first is Map<String, Object?>) {
        return first['is_admin'] as bool? ?? false;
      }
      if (first is Map<Object?, Object?>) {
        return _normalizeRow(first)['is_admin'] as bool? ?? false;
      }
    }
    return false;
  }

  @override
  Future<AiComputeDashboardSnapshot> fetchDashboard() async {
    final client = _resolvedClient;
    final userId = _requireUserId(client);
    final isAdmin = await _fetchIsAdmin(client, userId);

    final Object telemetryResponse = await client
        .from('ai_compute_cost_telemetry')
        .select()
        .order('recorded_at', ascending: false)
        .limit(100);

    final entries = <AiComputeTelemetryEntry>[];
    if (telemetryResponse is List<Object?>) {
      for (final row in telemetryResponse) {
        if (row is Map<String, Object?>) {
          entries.add(AiComputeTelemetryEntry.fromSupabaseRow(row));
        } else if (row is Map<Object?, Object?>) {
          entries.add(
            AiComputeTelemetryEntry.fromSupabaseRow(_normalizeRow(row)),
          );
        }
      }
    }

    final Object settingsResponse = await client
        .from('ai_compute_cost_alert_settings')
        .select()
        .eq('id', 'global')
        .limit(1);

    var settings = AiComputeThresholdSettings.defaults();
    if (settingsResponse is List<Object?> && settingsResponse.isNotEmpty) {
      final Object? first = settingsResponse.first;
      if (first is Map<String, Object?>) {
        settings = AiComputeThresholdSettings.fromSupabaseRow(first);
      } else if (first is Map<Object?, Object?>) {
        settings = AiComputeThresholdSettings.fromSupabaseRow(
          _normalizeRow(first),
        );
      }
    }

    return AiComputeDashboardSnapshot(
      entries: List<AiComputeTelemetryEntry>.unmodifiable(entries),
      thresholdSettings: settings,
      isAdmin: isAdmin,
    );
  }

  @override
  Future<AiComputeTelemetryEntry> recordTelemetry(
    AiComputeTelemetryEntry draft,
  ) async {
    final client = _resolvedClient;
    final userId = _requireUserId(client);
    final Object inserted = await client
        .from('ai_compute_cost_telemetry')
        .insert(draft.toInsertPayload(userId: userId))
        .select()
        .single();

    if (inserted is Map<String, Object?>) {
      return AiComputeTelemetryEntry.fromSupabaseRow(inserted);
    }
    if (inserted is Map<Object?, Object?>) {
      return AiComputeTelemetryEntry.fromSupabaseRow(_normalizeRow(inserted));
    }
    throw StateError('AI計算コストテレメトリの保存応答が不正です。');
  }

  @override
  Future<AiComputeThresholdSettings> updateThresholds({
    required double dailyThresholdUsd,
    required double monthlyThresholdUsd,
  }) async {
    final client = _resolvedClient;
    _requireUserId(client);
    final Object rawRpc = await client.rpc(
          'update_ai_compute_cost_threshold',
          params: <String, Object?>{
            'p_daily_threshold_usd': dailyThresholdUsd,
            'p_monthly_threshold_usd': monthlyThresholdUsd,
          },
        ) ??
        const <String, Object?>{};

    if (rawRpc is Map<String, Object?>) {
      return AiComputeThresholdSettings.fromSupabaseRow(rawRpc);
    }
    if (rawRpc is Map<Object?, Object?>) {
      return AiComputeThresholdSettings.fromSupabaseRow(_normalizeRow(rawRpc));
    }
    throw StateError('計算コスト閾値の更新応答が不正です。');
  }
}
