import 'package:supabase_flutter/supabase_flutter.dart';

class VoiceAiSettings {
  final bool trainingConsent;
  final DateTime? consentUpdatedAt;

  const VoiceAiSettings({required this.trainingConsent, this.consentUpdatedAt});

  factory VoiceAiSettings.fromJson(Map<String, dynamic> json) {
    final consentUpdatedAt = json['consent_updated_at'];
    return VoiceAiSettings(
      trainingConsent: json['training_consent'] as bool? ?? false,
      consentUpdatedAt: consentUpdatedAt != null
          ? DateTime.tryParse(consentUpdatedAt.toString())
          : null,
    );
  }

  static const empty = VoiceAiSettings(trainingConsent: false);
}

class VoiceAiUsageSummary {
  final String provider;
  final DateTime usageDate;
  final int ttsChars;
  final double sttSeconds;
  final double audioBytes;
  final double avgTtfaMs;
  final double avgChunkLatencyMs;
  final double estimatedCostUsd;
  final int eventCount;
  final int blockedEventCount;

  const VoiceAiUsageSummary({
    required this.provider,
    required this.usageDate,
    required this.ttsChars,
    required this.sttSeconds,
    required this.audioBytes,
    required this.avgTtfaMs,
    required this.avgChunkLatencyMs,
    required this.estimatedCostUsd,
    required this.eventCount,
    required this.blockedEventCount,
  });

  factory VoiceAiUsageSummary.fromJson(Map<String, dynamic> json) {
    final provider = json['provider'];
    final usageDate = json['usage_date'];
    return VoiceAiUsageSummary(
      provider: provider?.toString() ?? 'unknown',
      usageDate:
          DateTime.tryParse(usageDate?.toString() ?? '') ?? DateTime.now(),
      ttsChars: _asInt(json['tts_chars']),
      sttSeconds: _asDouble(json['stt_seconds']),
      audioBytes: _asDouble(json['audio_bytes']),
      avgTtfaMs: _asDouble(json['avg_ttfa_ms']),
      avgChunkLatencyMs: _asDouble(json['avg_chunk_latency_ms']),
      estimatedCostUsd: _asDouble(json['estimated_cost_usd']),
      eventCount: _asInt(json['event_count']),
      blockedEventCount: _asInt(json['blocked_event_count']),
    );
  }
}

class VoiceAiSettingsService {
  final SupabaseClient _supabase;

  VoiceAiSettingsService([SupabaseClient? supabaseClient])
      : _supabase = supabaseClient ?? Supabase.instance.client;

  Future<VoiceAiSettings> loadSettings() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return VoiceAiSettings.empty;

    final row = await _supabase
        .from('voice_ai_user_preferences')
        .select('training_consent, consent_updated_at')
        .eq('user_id', user.id)
        .maybeSingle();
    if (row == null) return VoiceAiSettings.empty;
    return VoiceAiSettings.fromJson(Map<String, dynamic>.from(row));
  }

  Future<VoiceAiSettings> updateTrainingConsent(bool enabled) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw StateError('Login required');
    }
    final row = await _supabase
        .from('voice_ai_user_preferences')
        .upsert(
          {
            'user_id': user.id,
            'training_consent': enabled,
          },
          onConflict: 'user_id',
        )
        .select('training_consent, consent_updated_at')
        .single();
    return VoiceAiSettings.fromJson(Map<String, dynamic>.from(row));
  }

  Future<List<VoiceAiUsageSummary>> loadUsageSummary() async {
    final rows = await _supabase
        .from('voice_ai_usage_provider_daily_summary')
        .select()
        .order('usage_date', ascending: false)
        .limit(120);
    return (rows as List)
        .whereType<Map>()
        .map(
          (row) => VoiceAiUsageSummary.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList();
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

double _asDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}
