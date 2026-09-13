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

class AiFeatureRoiParameters {
  const AiFeatureRoiParameters({
    required this.featureKey,
    required this.minutesSavedPerSuccess,
    required this.hourlyValueUsd,
    required this.directCostSavingUsdPerSuccess,
    required this.avoidedLossUsdPerSuccess,
    required this.valueCreatedUsdPerSuccess,
    this.updatedAt,
  });

  final String featureKey;
  final double minutesSavedPerSuccess;
  final double hourlyValueUsd;
  final double directCostSavingUsdPerSuccess;
  final double avoidedLossUsdPerSuccess;
  final double valueCreatedUsdPerSuccess;
  final String? updatedAt;

  factory AiFeatureRoiParameters.fromMap(Map<String, dynamic> map) {
    return AiFeatureRoiParameters(
      featureKey: _asString(map['feature_key']),
      minutesSavedPerSuccess: _asDouble(map['minutes_saved_per_success']),
      hourlyValueUsd: _asDouble(map['hourly_value_usd']),
      directCostSavingUsdPerSuccess: _asDouble(
        map['direct_cost_saving_usd_per_success'],
      ),
      avoidedLossUsdPerSuccess: _asDouble(
        map['avoided_loss_usd_per_success'],
      ),
      valueCreatedUsdPerSuccess: _asDouble(
        map['value_created_usd_per_success'],
      ),
      updatedAt: _emptyToNull(_asString(map['updated_at'])),
    );
  }
}

class AiFeatureRoiMetric {
  const AiFeatureRoiMetric({
    required this.requestCount,
    required this.successCount,
    required this.apiCostUsd,
    required this.directCostReductionUsd,
    required this.avoidedLossUsd,
    required this.valueCreatedUsd,
    required this.totalBenefitUsd,
    required this.netBenefitUsd,
    required this.roiPct,
  });

  final int requestCount;
  final int successCount;
  final double apiCostUsd;
  final double directCostReductionUsd;
  final double avoidedLossUsd;
  final double valueCreatedUsd;
  final double totalBenefitUsd;
  final double netBenefitUsd;
  final double? roiPct;

  factory AiFeatureRoiMetric.fromMap(Map<String, dynamic> map) {
    return AiFeatureRoiMetric(
      requestCount: _asInt(map['request_count']),
      successCount: _asInt(map['success_count']),
      apiCostUsd: _asDouble(map['api_cost_usd']),
      directCostReductionUsd: _asDouble(map['direct_cost_reduction_usd']),
      avoidedLossUsd: _asDouble(map['avoided_loss_usd']),
      valueCreatedUsd: _asDouble(map['value_created_usd']),
      totalBenefitUsd: _asDouble(map['total_benefit_usd']),
      netBenefitUsd: _asDouble(map['net_benefit_usd']),
      roiPct: _asNullableDouble(map['roi_pct']),
    );
  }
}

class AiFeatureRoiSummary extends AiFeatureRoiMetric {
  const AiFeatureRoiSummary({
    required this.featureKey,
    required this.parameters,
    required super.requestCount,
    required super.successCount,
    required super.apiCostUsd,
    required super.directCostReductionUsd,
    required super.avoidedLossUsd,
    required super.valueCreatedUsd,
    required super.totalBenefitUsd,
    required super.netBenefitUsd,
    required super.roiPct,
  });

  final String featureKey;
  final AiFeatureRoiParameters parameters;

  factory AiFeatureRoiSummary.fromMap(Map<String, dynamic> map) {
    final metric = AiFeatureRoiMetric.fromMap(map);
    final parameters =
        _mapValue(map['parameters']) ?? const <String, dynamic>{};
    return AiFeatureRoiSummary(
      featureKey: _asString(map['feature_key']),
      parameters: AiFeatureRoiParameters.fromMap(parameters),
      requestCount: metric.requestCount,
      successCount: metric.successCount,
      apiCostUsd: metric.apiCostUsd,
      directCostReductionUsd: metric.directCostReductionUsd,
      avoidedLossUsd: metric.avoidedLossUsd,
      valueCreatedUsd: metric.valueCreatedUsd,
      totalBenefitUsd: metric.totalBenefitUsd,
      netBenefitUsd: metric.netBenefitUsd,
      roiPct: metric.roiPct,
    );
  }
}

class AiFeatureRoiTrendPoint extends AiFeatureRoiMetric {
  const AiFeatureRoiTrendPoint({
    required this.usageDate,
    required super.requestCount,
    required super.successCount,
    required super.apiCostUsd,
    required super.directCostReductionUsd,
    required super.avoidedLossUsd,
    required super.valueCreatedUsd,
    required super.totalBenefitUsd,
    required super.netBenefitUsd,
    required super.roiPct,
  });

  final String usageDate;

  factory AiFeatureRoiTrendPoint.fromMap(Map<String, dynamic> map) {
    final metric = AiFeatureRoiMetric.fromMap(map);
    return AiFeatureRoiTrendPoint(
      usageDate: _asString(map['usage_date']),
      requestCount: metric.requestCount,
      successCount: metric.successCount,
      apiCostUsd: metric.apiCostUsd,
      directCostReductionUsd: metric.directCostReductionUsd,
      avoidedLossUsd: metric.avoidedLossUsd,
      valueCreatedUsd: metric.valueCreatedUsd,
      totalBenefitUsd: metric.totalBenefitUsd,
      netBenefitUsd: metric.netBenefitUsd,
      roiPct: metric.roiPct,
    );
  }
}

class AiFeatureRoiDashboard {
  const AiFeatureRoiDashboard({
    required this.currency,
    required this.overall,
    required this.features,
    required this.dailyTrend,
  });

  final String currency;
  final AiFeatureRoiMetric overall;
  final List<AiFeatureRoiSummary> features;
  final List<AiFeatureRoiTrendPoint> dailyTrend;

  factory AiFeatureRoiDashboard.fromMap(Map<String, dynamic> map) {
    return AiFeatureRoiDashboard(
      currency: _asString(map['currency']).isEmpty
          ? 'USD'
          : _asString(map['currency']),
      overall: AiFeatureRoiMetric.fromMap(
        _mapValue(map['overall']) ?? const <String, dynamic>{},
      ),
      features: ((map['features'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (item) => AiFeatureRoiSummary.fromMap(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(),
      dailyTrend: ((map['daily_trend'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (item) => AiFeatureRoiTrendPoint.fromMap(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(),
    );
  }

  factory AiFeatureRoiDashboard.empty() {
    return AiFeatureRoiDashboard.fromMap(const <String, dynamic>{});
  }
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
    required this.roi,
  });

  final String generatedAt;
  final int totalRequests;
  final double totalCostUsd;
  final int candidateCount;
  final List<AiRouterTaskSummary> tasks;
  final List<String> alertTools;
  final AiFeatureRoiDashboard roi;

  factory AiRouterCostDashboard.fromMap(Map<String, dynamic> map) {
    final overall = _mapValue(map['overall']) ?? const <String, dynamic>{};
    final quota = _mapValue(map['quota']) ?? const <String, dynamic>{};
    return AiRouterCostDashboard(
      generatedAt: _asString(map['generated_at']),
      totalRequests: _asInt(overall['total_requests']),
      totalCostUsd: _asDouble(overall['total_cost_usd']),
      candidateCount: _asInt(overall['candidate_count']),
      roi: AiFeatureRoiDashboard.fromMap(
        _mapValue(map['roi']) ?? const <String, dynamic>{},
      ),
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

  Future<AiFeatureRoiParameters> saveRoiParameters({
    required String featureKey,
    required double minutesSavedPerSuccess,
    required double hourlyValueUsd,
    required double directCostSavingUsdPerSuccess,
    required double avoidedLossUsdPerSuccess,
    required double valueCreatedUsdPerSuccess,
  }) async {
    final data = await _invoke({
      'action': 'ai_roi.parameter.set',
      'feature_key': featureKey,
      'minutes_saved_per_success': minutesSavedPerSuccess,
      'hourly_value_usd': hourlyValueUsd,
      'direct_cost_saving_usd_per_success': directCostSavingUsdPerSuccess,
      'avoided_loss_usd_per_success': avoidedLossUsdPerSuccess,
      'value_created_usd_per_success': valueCreatedUsdPerSuccess,
    });
    if (data['success'] != true) {
      throw StateError(
        _asString(data['error']).isEmpty
            ? 'AI ROI parameter request failed'
            : _asString(data['error']),
      );
    }
    final parameters = _mapValue(data['parameters']);
    if (parameters == null) {
      throw StateError('AI ROI parameter response is empty');
    }
    return AiFeatureRoiParameters.fromMap(parameters);
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
