import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('viral ad UI sends explicit audio input to the Edge Function', () {
    final source =
        File('lib/pages/viral_ad_generator_page.dart').readAsStringSync();

    expect(source, contains("'audioInput': hedraAudioInput"));
    expect(source, contains('HedraAudioInputPanel('));
    expect(source, contains('FilePicker.pickFiles('));
  });

  test('backend builds mutually exclusive Hedra audio payloads', () {
    final source = File(
      'supabase/functions/viral-video-ad-generator/index.ts',
    ).readAsStringSync();

    expect(source, contains('parseHedraAudioInput(body.audioInput)'));
    expect(source, contains('audioProvider: "hedra_custom_tts"'));
    expect(source, contains('audioProvider: "user_audio_file"'));
    expect(
      RegExp(r'withExclusiveHedraAudio\(').allMatches(source).length,
      greaterThanOrEqualTo(4),
    );
  });
}
