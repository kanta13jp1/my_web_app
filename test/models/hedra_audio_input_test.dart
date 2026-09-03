import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/hedra_audio_input.dart';

void main() {
  test('builds a trimmed TTS request with voice settings', () {
    final payload = buildHedraAudioInputPayload(
      mode: HedraAudioInputMode.textToSpeech,
      text: ' こんにちは ',
      voice: 'male_narrator',
      stability: 0.7,
      speed: 1.1,
    );

    expect(payload, {
      'mode': 'tts',
      'text': 'こんにちは',
      'voice': 'male_narrator',
      'stability': 0.7,
      'speed': 1.1,
    });
    expect(payload, isNot(contains('audio_id')));
  });

  test('builds a file request and rejects oversized files', () {
    final file = HedraAudioFile(
      name: 'voice.mp3',
      mimeType: 'audio/mpeg',
      bytes: Uint8List.fromList([0x49, 0x44, 0x33]),
    );

    expect(
      buildHedraAudioInputPayload(
        mode: HedraAudioInputMode.file,
        file: file,
      ),
      containsPair('dataBase64', 'SUQz'),
    );
    expect(
      validateHedraAudioFile(
        HedraAudioFile(
          name: 'too-large.mp3',
          mimeType: 'audio/mpeg',
          bytes: Uint8List(hedraAudioFileMaxBytes + 1),
        ),
      ),
      contains('4MB'),
    );
  });

  test('validates required text and Hedra speed bounds', () {
    expect(validateHedraTtsText(' '), isNotNull);
    expect(
      () => buildHedraAudioInputPayload(
        mode: HedraAudioInputMode.textToSpeech,
        text: 'hello',
        speed: 1.3,
      ),
      throwsArgumentError,
    );
  });
}
