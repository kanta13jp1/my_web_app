import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source = File('supabase/functions/ai-hub/index.ts')
        .readAsStringSync()
        .replaceAll('\r\n', '\n');
  });

  test('issues only a short-lived TTS grant from the trusted backend', () {
    expect(source, contains('"voice.cartesia_session.start"'));
    expect(source, contains('"https://api.cartesia.ai/access-token"'));
    expect(source, contains('grants: { tts: true }'));
    expect(source, contains('expires_in: maxSessionSeconds + 30'));
    expect(source, contains('"Cartesia-Version": apiVersion'));
    expect(source, isNot(contains('grants: { tts: true, stt: true }')));
  });

  test('pins Sonic 3 controls and never returns the account API key', () {
    expect(source, contains('"sonic-3-2026-01-12"'));
    expect(source, contains('max_session_seconds: maxSessionSeconds'));
    expect(source, contains('access_token: accessToken'));
    expect(source, isNot(contains('api_key: cartesiaKey')));
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
