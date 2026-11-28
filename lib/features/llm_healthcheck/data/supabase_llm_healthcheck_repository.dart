import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/llm_healthcheck_models.dart';

class SupabaseLlmHealthcheckRepository implements LlmHealthcheckRepository {
  SupabaseLlmHealthcheckRepository({final SupabaseClient? client})
      : _providedClient = client;

  final SupabaseClient? _providedClient;

  SupabaseClient get _client {
    if (_providedClient != null) return _providedClient;
    return Supabase.instance.client;
  }

  @override
  Future<LlmHealthDashboardSnapshot> fetchSummary() async {
    final data = await _invokeAppHub(const <String, Object?>{
      'action': 'llm_healthcheck.summary',
    });
    final rawProviders = data['providers'];
    final rawEndpoints = data['endpoints'];
    final rawLogs = data['logs'];
    final rawAlerts = data['alerts'];

    return LlmHealthDashboardSnapshot(
      overallUptimePct: _toDouble(data['overall_uptime_pct'], fallback: 100.0),
      avgLatencyMs: _toInt(data['avg_latency_ms'], fallback: 0),
      providers: rawProviders is List
          ? rawProviders
              .whereType<Map>()
              .map(
                (final item) => ProviderUptimeSummary.fromMap(
                  Map<String, Object?>.from(item),
                ),
              )
              .toList(growable: false)
          : const <ProviderUptimeSummary>[],
      endpoints: rawEndpoints is List
          ? rawEndpoints
              .whereType<Map>()
              .map(
                (final item) => LlmEndpointConfig.fromMap(
                  Map<String, Object?>.from(item),
                ),
              )
              .toList(growable: false)
          : const <LlmEndpointConfig>[],
      logs: rawLogs is List
          ? rawLogs
              .whereType<Map>()
              .map(
                (final item) => LlmHealthLog.fromMap(
                  Map<String, Object?>.from(item),
                ),
              )
              .toList(growable: false)
          : const <LlmHealthLog>[],
      alerts: rawAlerts is List
          ? rawAlerts
              .whereType<Map>()
              .map(
                (final item) => LlmHealthAlert.fromMap(
                  Map<String, Object?>.from(item),
                ),
              )
              .toList(growable: false)
          : const <LlmHealthAlert>[],
    );
  }

  @override
  Future<void> seedDefaults() async {
    await _invokeAppHub(const <String, Object?>{
      'action': 'llm_healthcheck.seed_defaults',
    });
  }

  @override
  Future<LlmEndpointConfig> upsertEndpoint({
    final String? id,
    required final String providerName,
    required final String endpointUrl,
    final String method = 'GET',
    final int timeoutMs = 5000,
    final String alertChannel = 'ops-alerts',
  }) async {
    final data = await _invokeAppHub(<String, Object?>{
      'action': 'llm_healthcheck.upsert_endpoint',
      if (id != null && id.trim().isNotEmpty) 'id': id.trim(),
      'provider_name': providerName.trim(),
      'endpoint_url': endpointUrl.trim(),
      'method': method.trim(),
      'timeout_ms': timeoutMs,
      'alert_channel': alertChannel.trim(),
    });
    final ep = data['endpoint'];
    if (ep is Map) {
      return LlmEndpointConfig.fromMap(Map<String, Object?>.from(ep));
    }
    throw Exception('エンドポイント登録レスポンスが不正です。');
  }

  @override
  Future<void> deleteEndpoint(final String id) async {
    await _invokeAppHub(<String, Object?>{
      'action': 'llm_healthcheck.delete_endpoint',
      'id': id.trim(),
    });
  }

  @override
  Future<void> runProbe({final String? endpointId}) async {
    await _invokeAppHub(<String, Object?>{
      'action': 'llm_healthcheck.run_probe',
      if (endpointId != null && endpointId.trim().isNotEmpty)
        'endpoint_id': endpointId.trim(),
    });
  }

  Future<Map<String, Object?>> _invokeAppHub(
    final Map<String, Object?> body,
  ) async {
    try {
      final response = await _client.functions.invoke('app-hub', body: body);
      if (response.status == 401) {
        throw const LlmHealthAuthException();
      }
      final raw = response.data;
      if (raw is! Map) {
        throw Exception('app-hub からの応答形式が不正です。');
      }
      final map = Map<String, Object?>.from(raw);
      if (response.status >= 400 || map['success'] == false) {
        final msg = (map['error'] ?? 'LLM ヘルスチェック取得に失敗しました。').toString();
        throw Exception(msg);
      }
      return map;
    } on FunctionException catch (err) {
      if (err.status == 401) {
        throw const LlmHealthAuthException();
      }
      throw Exception('LLM ヘルスチェック API エラー (${err.status})');
    }
  }

  int _toInt(final Object? value, {required final int fallback}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  double _toDouble(final Object? value, {required final double fallback}) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
