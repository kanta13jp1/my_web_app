import 'package:supabase_flutter/supabase_flutter.dart';

typedef AdminHubInvoker = Future<Map<String, dynamic>> Function(
  Map<String, dynamic> body,
);

class AiRouterCandidate {
  const AiRouterCandidate({
    required this.task,
    required this.provider,
    required this.requestCount,
    required this.successRatePct,
    required this.totalCostUsd,
    required this.avgCostUsd,
    required this.score,
    required this.quotaAlert,
    this.model,
    this.tier,
    this.costPer1kChars,
    this.avgLatencyMs,
    this.lastSeenAt,
  });

  final String task;
  final String provider;
  final String? model;
  final String? tier;
  final int requestCount;
  final double successRatePct;
  final double totalCostUsd;
  final double avgCostUsd;
  final double? costPer1kChars;
  final int? avgLatencyMs;
  final double score;
  final bool quotaAlert;
  final String? lastSeenAt;

  factory AiRouterCandidate.fromMap(Map<String, dynamic> map) {
    return AiRouterCandidate(
      task: _asString(map['task']),
      provider: _asString(map['provider']),
      model: _emptyToNull(_asString(map['model'])),
      tier: _emptyToNull(_asString(map['tier'])),
      requestCount: _asInt(map['request_count']),
      successRatePct: _asDouble(map['success_rate_pct']),
      totalCostUsd: _asDouble(map['total_cost_usd']),
      avgCostUsd: _asDouble(map['avg_cost_usd']),
      costPer1kChars: _asNullableDouble(map['cost_per_1k_chars']),
      avgLatencyMs: _asNullableInt(map['avg_latency_ms']),
      score: _asDouble(map['score']),
      quotaAlert: map['quota_alert'] == true,
      lastSeenAt: _emptyToNull(_asString(map['last_seen_at'])),
    );
  }

  String get displayModel =>
      model == null || model!.isEmpty ? provider : '$provider / $model';
}

class AiRouterPreference {
  const AiRouterPreference({
    required this.task,
    required this.provider,
    required this.isEnabled,
    this.model,
    this.updatedAt,
  });

  final String task;
  final String provider;
  final String? model;
  final bool isEnabled;
  final String? updatedAt;

  factory AiRouterPreference.fromMap(Map<String, dynamic> map) {
    return AiRouterPreference(
      task: _asString(map['task']),
      provider: _asString(map['provider']),
      model: _emptyToNull(_asString(map['model'])),
      isEnabled: map['is_enabled'] != false,
      updatedAt: _emptyToNull(_asString(map['updated_at'])),
    );
  }

  String get displayModel =>
      model == null || model!.isEmpty ? provider : '$provider / $model';
}

class AiRouterTaskSummary {
  const AiRouterTaskSummary({
    required this.task,
    required this.label,
    required this.totalRequests,
    required this.candidates,
    this.recommendation,
    this.preference,
  });

  final String task;
  final String label;
  final int totalRequests;
  final AiRouterCandidate? recommendation;
  final AiRouterPreference? preference;
  final List<AiRouterCandidate> candidates;

  factory AiRouterTaskSummary.fromMap(Map<String, dynamic> map) {
    final recommendation = _mapValue(map['recommendation']);
    final preference = _mapValue(map['preference']);
    return AiRouterTaskSummary(
      task: _asString(map['task']),
      label: _asString(map['label']),
      totalRequests: _asInt(map['total_requests']),
      recommendation: recommendation == null
          ? null
          : AiRouterCandidate.fromMap(recommendation),
      preference:
          preference == null ? null : AiRouterPreference.fromMap(preference),
      candidates: ((map['candidates'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                AiRouterCandidate.fromMap(Map<String, dynamic>.from(item)),
          )
          .toList(),
    );
  }
}

class AiRouterCostDashboard {
  const AiRouterCostDashboard({
    required this.generatedAt,
    required this.totalRequests,
    required this.totalCostUsd,
    required this.candidateCount,
    required this.tasks,
    required this.alertTools,
  });

  final String generatedAt;
  final int totalRequests;
  final double totalCostUsd;
  final int candidateCount;
  final List<AiRouterTaskSummary> tasks;
  final List<String> alertTools;

  factory AiRouterCostDashboard.fromMap(Map<String, dynamic> map) {
    final overall = _mapValue(map['overall']) ?? const <String, dynamic>{};
    final quota = _mapValue(map['quota']) ?? const <String, dynamic>{};
    return AiRouterCostDashboard(
      generatedAt: _asString(map['generated_at']),
      totalRequests: _asInt(overall['total_requests']),
      totalCostUsd: _asDouble(overall['total_cost_usd']),
      candidateCount: _asInt(overall['candidate_count']),
      alertTools: ((quota['alert_tools'] as List?) ?? const [])
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList(),
      tasks: ((map['tasks'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                AiRouterTaskSummary.fromMap(Map<String, dynamic>.from(item)),
          )
          .toList(),
    );
  }
}

class AiRouterCostDashboardService {
  const AiRouterCostDashboardService({
    SupabaseClient? supabaseClient,
    AdminHubInvoker? invoker,
  })  : _supabaseClient = supabaseClient,
        _invoker = invoker;

  final SupabaseClient? _supabaseClient;
  final AdminHubInvoker? _invoker;

  Future<AiRouterCostDashboard> loadDashboard({int days = 30}) async {
    final data = await _invoke({
      'action': 'ai_router.cost_dashboard',
      'days': days,
    });
    if (data['success'] != true) {
      throw StateError(
        _asString(data['error']).isEmpty
            ? 'AI router dashboard request failed'
            : _asString(data['error']),
      );
    }
    return AiRouterCostDashboard.fromMap(data);
  }

  Future<AiRouterPreference> savePreference({
    required String task,
    required String provider,
    String? model,
  }) async {
    final data = await _invoke({
      'action': 'ai_router.preference.set',
      'task': task,
      'provider': provider,
      if (model != null && model.trim().isNotEmpty) 'model': model.trim(),
      'is_enabled': true,
    });
    if (data['success'] != true) {
      throw StateError(
        _asString(data['error']).isEmpty
            ? 'AI router preference request failed'
            : _asString(data['error']),
      );
    }
    final preference = _mapValue(data['preference']);
    if (preference == null) {
      throw StateError('AI router preference response is empty');
    }
    return AiRouterPreference.fromMap(preference);
  }

  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    final invoker = _invoker;
    if (invoker != null) return invoker(body);
    final client = _supabaseClient ?? Supabase.instance.client;
    final response = await client.functions.invoke('admin-hub', body: body);
    final data = response.data;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw StateError('admin-hub returned an invalid response');
  }
}

Map<String, dynamic>? _mapValue(Object? value) {
  if (value == null) return null;
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

String _asString(Object? value) => value?.toString().trim() ?? '';

String? _emptyToNull(String value) => value.isEmpty ? null : value;

int _asInt(Object? value) => _asNullableInt(value) ?? 0;

int? _asNullableInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '');
}

double _asDouble(Object? value) => _asNullableDouble(value) ?? 0;

double? _asNullableDouble(Object? value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}
