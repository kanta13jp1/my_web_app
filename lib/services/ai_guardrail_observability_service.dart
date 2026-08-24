import 'package:supabase_flutter/supabase_flutter.dart';

typedef AiGuardrailObservabilityInvoker =
    Future<Map<String, dynamic>> Function(Map<String, dynamic> body);

class AiGuardrailCategoryCount {
  final String category;
  final int count;

  const AiGuardrailCategoryCount({required this.category, required this.count});

  factory AiGuardrailCategoryCount.fromMap(Map<String, dynamic> data) {
    return AiGuardrailCategoryCount(
      category: data['category']?.toString().trim() ?? '',
      count: _asInt(data['count']),
    );
  }
}

class AiGuardrailSummary {
  final int windowDays;
  final int sampledEvents;
  final bool sampleLimited;
  final int allowed;
  final int blocked;
  final int redacted;
  final int averageLatencyMs;
  final List<AiGuardrailCategoryCount> categories;

  const AiGuardrailSummary({
    required this.windowDays,
    required this.sampledEvents,
    required this.sampleLimited,
    required this.allowed,
    required this.blocked,
    required this.redacted,
    required this.averageLatencyMs,
    required this.categories,
  });

  factory AiGuardrailSummary.fromMap(Map<String, dynamic> data) {
    return AiGuardrailSummary(
      windowDays: _asInt(data['window_days'], fallback: 7),
      sampledEvents: _asInt(data['sampled_events']),
      sampleLimited: data['sample_limited'] == true,
      allowed: _asInt(data['allowed']),
      blocked: _asInt(data['blocked']),
      redacted: _asInt(data['redacted']),
      averageLatencyMs: _asInt(data['average_latency_ms']),
      categories: _mapList(data['categories'])
          .map(AiGuardrailCategoryCount.fromMap)
          .where((item) => item.category.isNotEmpty)
          .toList(growable: false),
    );
  }
}

class AiGuardrailEvent {
  final String traceId;
  final String provider;
  final String action;
  final String stage;
  final String decision;
  final List<String> categories;
  final int redactionCount;
  final int latencyMs;
  final int contentChars;
  final String policyVersion;
  final DateTime? createdAt;

  const AiGuardrailEvent({
    required this.traceId,
    required this.provider,
    required this.action,
    required this.stage,
    required this.decision,
    required this.categories,
    required this.redactionCount,
    required this.latencyMs,
    required this.contentChars,
    required this.policyVersion,
    required this.createdAt,
  });

  factory AiGuardrailEvent.fromMap(Map<String, dynamic> data) {
    final rawCategories = data['categories'];
    return AiGuardrailEvent(
      traceId: data['trace_id']?.toString().trim() ?? '',
      provider: data['provider']?.toString().trim() ?? '',
      action: data['action']?.toString().trim() ?? '',
      stage: data['stage']?.toString().trim() ?? '',
      decision: data['decision']?.toString().trim() ?? '',
      categories: rawCategories is List
          ? rawCategories
                .map((value) => value.toString().trim())
                .where((value) => value.isNotEmpty)
                .toList(growable: false)
          : const <String>[],
      redactionCount: _asInt(data['redaction_count']),
      latencyMs: _asInt(data['latency_ms']),
      contentChars: _asInt(data['content_chars']),
      policyVersion: data['policy_version']?.toString().trim() ?? '',
      createdAt: DateTime.tryParse(data['created_at']?.toString() ?? ''),
    );
  }

  String get shortTraceId {
    if (traceId.length <= 12) return traceId;
    return traceId.substring(0, 12);
  }
}

class AiGuardrailOverview {
  final AiGuardrailSummary summary;
  final List<AiGuardrailEvent> recentEvents;
  final bool rawContentStored;
  final bool userIdReturned;

  const AiGuardrailOverview({
    required this.summary,
    required this.recentEvents,
    required this.rawContentStored,
    required this.userIdReturned,
  });

  factory AiGuardrailOverview.fromMap(Map<String, dynamic> data) {
    final summary = _asMap(data['summary']);
    final privacy = _asMap(data['privacy']);
    return AiGuardrailOverview(
      summary: AiGuardrailSummary.fromMap(summary),
      recentEvents: _mapList(
        data['recent_events'],
      ).map(AiGuardrailEvent.fromMap).toList(growable: false),
      rawContentStored: privacy['raw_content_stored'] == true,
      userIdReturned: privacy['user_id_returned'] == true,
    );
  }
}

class AiGuardrailObservabilityException implements Exception {
  final String message;
  final bool adminRequired;

  const AiGuardrailObservabilityException(
    this.message, {
    this.adminRequired = false,
  });

  @override
  String toString() => message;
}

class AiGuardrailObservabilityService {
  final SupabaseClient? _supabase;
  final AiGuardrailObservabilityInvoker? _invoker;

  const AiGuardrailObservabilityService({
    SupabaseClient? supabase,
    AiGuardrailObservabilityInvoker? invoker,
  }) : _supabase = supabase,
       _invoker = invoker;

  Future<AiGuardrailOverview> fetchOverview({
    int windowDays = 7,
    int limit = 30,
  }) async {
    final body = <String, dynamic>{
      'action': 'observability.guardrails',
      'window_days': windowDays.clamp(1, 90),
      'limit': limit.clamp(1, 100),
    };
    try {
      final data = await _invoke(body);
      if (data['success'] != true) {
        throw _failureFromMap(data);
      }
      return AiGuardrailOverview.fromMap(data);
    } on FunctionException catch (error) {
      final details = error.details;
      if (details is Map) {
        throw _failureFromMap(Map<String, dynamic>.from(details));
      }
      throw const AiGuardrailObservabilityException('ガードレール監査ログを取得できませんでした。');
    }
  }

  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    final invoker = _invoker;
    if (invoker != null) return invoker(body);
    final client = _supabase ?? Supabase.instance.client;
    final response = await client.functions.invoke('ai-hub', body: body);
    final data = response.data;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw const AiGuardrailObservabilityException('ガードレール監査ログの応答形式が不正です。');
  }

  AiGuardrailObservabilityException _failureFromMap(Map<String, dynamic> data) {
    final adminRequired = data['error'] == 'admin_required';
    return AiGuardrailObservabilityException(
      adminRequired
          ? '管理者アカウントでログインしてください。'
          : (data['message']?.toString().trim().isNotEmpty == true
                ? data['message'].toString().trim()
                : 'ガードレール監査ログを取得できませんでした。'),
      adminRequired: adminRequired,
    );
  }
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

List<Map<String, dynamic>> _mapList(Object? value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

int _asInt(Object? value, {int fallback = 0}) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}
