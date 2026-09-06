import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/voice_ai_settings_service.dart';

void main() {
  test('voice training consent defaults to opt-out', () {
    final settings = VoiceAiSettings.fromJson(const <String, dynamic>{});

    expect(settings.trainingConsent, isFalse);
    expect(settings.consentUpdatedAt, isNull);
  });

  test('voice training consent parses from the private preference row', () {
    final settings = VoiceAiSettings.fromJson(const <String, dynamic>{
      'training_consent': true,
      'consent_updated_at': '2026-09-03T00:00:00Z',
    });

    expect(settings.trainingConsent, isTrue);
    expect(settings.consentUpdatedAt, DateTime.utc(2026, 9, 3));
  });

  test('usage summary parses provider cost and latency metrics', () {
    final summary = VoiceAiUsageSummary.fromJson(<String, dynamic>{
      'provider': 'cartesia',
      'usage_date': '2026-09-03',
      'tts_chars': 120,
      'stt_seconds': 4.5,
      'audio_bytes': 4096,
      'avg_ttfa_ms': 82,
      'avg_chunk_latency_ms': 31,
      'estimated_cost_usd': 0.0012,
      'event_count': 7,
      'blocked_event_count': 1,
    });

    expect(summary.provider, 'cartesia');
    expect(summary.ttsChars, 120);
    expect(summary.avgTtfaMs, 82);
    expect(summary.avgChunkLatencyMs, 31);
    expect(summary.estimatedCostUsd, 0.0012);
    expect(summary.blockedEventCount, 1);
  });
}
