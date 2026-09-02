import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;
  late String webClientSource;

  setUpAll(() {
    source = File('supabase/functions/ai-hub/index.ts')
            .readAsStringSync()
            .replaceAll('\r\n', '\n') +
        File('supabase/functions/ai-hub/voice_ai.ts')
            .readAsStringSync()
            .replaceAll('\r\n', '\n');
    webClientSource = File('lib/services/cartesia_voice_client_web.dart')
        .readAsStringSync()
        .replaceAll('\r\n', '\n');
  });

  test('uses an authenticated backend proxy with a short-lived upstream grant',
      () {
    expect(source, contains('"voice.cartesia_session.start"'));
    expect(source, contains('authenticateVoiceProxyRequest'));
    expect(source, contains('transport: "backend_proxy"'));
    expect(source, contains('"https://api.cartesia.ai/access-token"'));
    expect(source, contains('grants: { tts: true }'));
    expect(source, contains('"Cartesia-Version": CARTESIA_VERSION'));
    expect(source, isNot(contains('grants: { tts: true, stt: true }')));
  });

  test('returns only the scoped proxy token and never the account API key', () {
    expect(source, contains('"sonic-3-2026-01-12"'));
    expect(source, contains('websocket_access_token: accessToken'));
    expect(
        source, contains('max_session_seconds: CARTESIA_MAX_SESSION_SECONDS'));
    expect(source, contains('model_id: CARTESIA_MODEL_ID'));
    expect(source, contains('id: Deno.env.get("CARTESIA_VOICE_ID")'));
    expect(source, isNot(contains('api_key: apiKey')));
    expect(source, isNot(contains('sendUpstream(upstream, message)')));
  });

  test('enforces privacy before provider access and queues PCM continuously',
      () {
    expect(source, contains('.from("voice_ai_user_preferences")'));
    expect(
      source,
      contains('voice_training_consent_or_cartesia_zdr_required'),
    );
    expect(source, contains('isCartesiaZdrEnabled()'));
    expect(source, contains('assertVoiceProviderPrivacy'));
    expect(webClientSource, contains("'voice_token'"));
    expect(webClientSource, contains("type == 'ready'"));
    expect(webClientSource, contains('source.start(startAt)'));
    expect(webClientSource, contains('_playAt = startAt + buffer.duration'));
  });

  test('saves a deduplicated transcript in the existing support ticket source',
      () {
    expect(source, contains('"voice.cartesia_session.finish"'));
    expect(source, contains('.eq("source", "support_ticket")'));
    expect(source, contains('voice_session_id: sessionId'));
    expect(source, contains('duration_seconds: durationSeconds'));
    expect(source, contains('assistant_character_count:'));
  });
}
