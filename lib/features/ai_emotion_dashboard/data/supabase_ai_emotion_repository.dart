import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/ai_emotion_models.dart';

/// Supabase Edge Function (`app-hub`) backed repository for AI functional
/// emotion monitoring (#2764).
class SupabaseAiEmotionRepository implements AiEmotionRepository {
  SupabaseAiEmotionRepository({final SupabaseClient? client})
      : _client = client;

  final SupabaseClient? _client;

  Future<Map<String, Object?>> _invoke(
    final Map<String, Object?> body,
  ) async {
    final client = _client ?? Supabase.instance.client;
    try {
      final response = await client.functions.invoke('app-hub', body: body);
      if (response.status == 401) {
        throw const AiEmotionAuthException();
      }
      final data = response.data;
      if (data is Map<Object?, Object?>) {
        return _toMap(data);
      }
      return const <String, Object?>{};
    } on FunctionException catch (e) {
      if (e.status == 401) {
        throw const AiEmotionAuthException();
      }
      rethrow;
    }
  }

  @override
  Future<AiEmotionDashboardSnapshot> listDashboard({
    final FunctionalEmotionCategory? toneFilter,
    final double? threshold,
  }) async {
    final payload = <String, Object?>{
      'action': 'ai_emotion.list',
      if (toneFilter != null) 'tone': toneFilter.apiValue,
      if (threshold != null) 'alert_threshold': threshold,
    };
    final data = await _invoke(payload);
    return AiEmotionDashboardSnapshot.fromJson(data);
  }

  @override
  Future<AiEmotionDashboardSnapshot> seedDefaults({
    final double? threshold,
  }) async {
    final payload = <String, Object?>{
      'action': 'ai_emotion.seed_defaults',
      if (threshold != null) 'alert_threshold': threshold,
    };
    final data = await _invoke(payload);
    return AiEmotionDashboardSnapshot.fromJson(data);
  }

  @override
  Future<AiEmotionLogEntry> classifyAndLog({
    required final String responseText,
    required final String model,
    final String sourceAction = 'manual_eval',
    final double? alertThreshold,
  }) async {
    final payload = <String, Object?>{
      'action': 'ai_emotion.classify_and_log',
      'response_text': responseText,
      'model': model,
      'source_action': sourceAction,
      if (alertThreshold != null) 'alert_threshold': alertThreshold,
    };
    final data = await _invoke(payload);
    final rawLog = data['log'];
    if (rawLog is Map<Object?, Object?>) {
      return AiEmotionLogEntry.fromJson(_toMap(rawLog));
    }
    throw StateError(
      'Invalid response payload from ai_emotion.classify_and_log',
    );
  }

  Map<String, Object?> _toMap(final Map<Object?, Object?> raw) {
    final out = <String, Object?>{};
    for (final entry in raw.entries) {
      final key = entry.key?.toString();
      if (key != null) {
        out[key] = entry.value;
      }
    }
    return out;
  }
}
