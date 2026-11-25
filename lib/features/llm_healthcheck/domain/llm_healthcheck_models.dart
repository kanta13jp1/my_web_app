class LlmHealthAuthException implements Exception {
  const LlmHealthAuthException({
    this.message = '認証セッションが確認できません。ログイン後に再度お試しください。',
  });

  final String message;

  @override
  String toString() => message;
}

class LlmEndpointConfig {
  const LlmEndpointConfig({
    required this.id,
    required this.providerName,
    required this.endpointUrl,
    required this.method,
    required this.timeoutMs,
    required this.alertChannel,
    required this.enabled,
    required this.updatedAt,
  });

  final String id;
  final String providerName;
  final String endpointUrl;
  final String method;
  final int timeoutMs;
  final String alertChannel;
  final bool enabled;
  final String updatedAt;

  factory LlmEndpointConfig.fromMap(final Map<String, Object?> map) {
    return LlmEndpointConfig(
      id: (map['id'] ?? '').toString(),
      providerName: (map['provider_name'] ?? 'Custom LLM').toString(),
      endpointUrl: (map['endpoint_url'] ?? '').toString(),
      method: (map['method'] ?? 'GET').toString(),
      timeoutMs: _asInt(map['timeout_ms'], fallback: 5000),
      alertChannel: (map['alert_channel'] ?? 'ops-alerts').toString(),
      enabled: map['enabled'] != false,
      updatedAt: (map['updated_at'] ?? '').toString(),
    );
  }
}

class LlmHealthLog {
  const LlmHealthLog({
    required this.id,
    required this.endpointId,
    required this.providerName,
    required this.endpointUrl,
    required this.status,
    required this.httpStatus,
    required this.latencyMs,
    required this.errorType,
    required this.errorMessage,
    required this.checkedAt,
  });

  final String id;
  final String endpointId;
  final String providerName;
  final String endpointUrl;
  final String status;
  final int? httpStatus;
  final int latencyMs;
  final String? errorType;
  final String? errorMessage;
  final String checkedAt;

  factory LlmHealthLog.fromMap(final Map<String, Object?> map) {
    return LlmHealthLog(
      id: (map['id'] ?? '').toString(),
      endpointId: (map['endpoint_id'] ?? '').toString(),
      providerName: (map['provider_name'] ?? 'Unknown').toString(),
      endpointUrl: (map['endpoint_url'] ?? '').toString(),
      status: (map['status'] ?? 'down').toString(),
      httpStatus: _asNullableInt(map['http_status']),
      latencyMs: _asInt(map['latency_ms'], fallback: 0),
      errorType: map['error_type']?.toString(),
      errorMessage: map['error_message']?.toString(),
      checkedAt: (map['checked_at'] ?? '').toString(),
    );
  }
}

class LlmHealthAlert {
  const LlmHealthAlert({
    required this.id,
    required this.endpointId,
    required this.providerName,
    required this.status,
    required this.errorType,
    required this.errorMessage,
    required this.alertChannel,
    required this.deliveryStatus,
    required this.recordedAt,
  });

  final String id;
  final String endpointId;
  final String providerName;
  final String status;
  final String errorType;
  final String errorMessage;
  final String alertChannel;
  final String deliveryStatus;
  final String recordedAt;

  factory LlmHealthAlert.fromMap(final Map<String, Object?> map) {
    return LlmHealthAlert(
      id: (map['id'] ?? '').toString(),
      endpointId: (map['endpoint_id'] ?? '').toString(),
      providerName: (map['provider_name'] ?? 'Unknown').toString(),
      status: (map['status'] ?? 'down').toString(),
      errorType: (map['error_type'] ?? 'probe_failure').toString(),
      errorMessage: (map['error_message'] ?? '').toString(),
      alertChannel: (map['alert_channel'] ?? 'ops-alerts').toString(),
      deliveryStatus: (map['delivery_status'] ?? 'logged').toString(),
      recordedAt: (map['recorded_at'] ?? '').toString(),
    );
  }
}

class ProviderUptimeSummary {
  const ProviderUptimeSummary({
    required this.providerName,
    required this.endpointId,
    required this.totalChecks,
    required this.healthyChecks,
    required this.uptimePct,
    required this.avgLatencyMs,
    required this.latestStatus,
    required this.latestLatencyMs,
  });

  final String providerName;
  final String endpointId;
  final int totalChecks;
  final int healthyChecks;
  final double uptimePct;
  final int avgLatencyMs;
  final String? latestStatus;
  final int? latestLatencyMs;

  factory ProviderUptimeSummary.fromMap(final Map<String, Object?> map) {
    return ProviderUptimeSummary(
      providerName: (map['provider_name'] ?? 'Unknown').toString(),
      endpointId: (map['endpoint_id'] ?? '').toString(),
      totalChecks: _asInt(map['total_checks'], fallback: 0),
      healthyChecks: _asInt(map['healthy_checks'], fallback: 0),
      uptimePct: _asDouble(map['uptime_pct'], fallback: 100.0),
      avgLatencyMs: _asInt(map['avg_latency_ms'], fallback: 0),
      latestStatus: map['latest_status']?.toString(),
      latestLatencyMs: _asNullableInt(map['latest_latency_ms']),
    );
  }
}

class LlmHealthDashboardSnapshot {
  const LlmHealthDashboardSnapshot({
    required this.overallUptimePct,
    required this.avgLatencyMs,
    required this.providers,
    required this.endpoints,
    required this.logs,
    required this.alerts,
  });

  final double overallUptimePct;
  final int avgLatencyMs;
  final List<ProviderUptimeSummary> providers;
  final List<LlmEndpointConfig> endpoints;
  final List<LlmHealthLog> logs;
  final List<LlmHealthAlert> alerts;

  static const LlmHealthDashboardSnapshot empty = LlmHealthDashboardSnapshot(
    overallUptimePct: 100.0,
    avgLatencyMs: 0,
    providers: <ProviderUptimeSummary>[],
    endpoints: <LlmEndpointConfig>[],
    logs: <LlmHealthLog>[],
    alerts: <LlmHealthAlert>[],
  );
}

abstract class LlmHealthcheckRepository {
  Future<LlmHealthDashboardSnapshot> fetchSummary();

  Future<void> seedDefaults();

  Future<LlmEndpointConfig> upsertEndpoint({
    String? id,
    required String providerName,
    required String endpointUrl,
    String method = 'GET',
    int timeoutMs = 5000,
    String alertChannel = 'ops-alerts',
  });

  Future<void> deleteEndpoint(String id);

  Future<void> runProbe({String? endpointId});
}

int _asInt(final Object? value, {required final int fallback}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

int? _asNullableInt(final Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double _asDouble(final Object? value, {required final double fallback}) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}
