import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/ui/features/live_captions/services/live_speech_recognizer_base.dart';

void main() {
  group('Live speech error policy', () {
    test('silence keeps an active session eligible for onend recovery', () {
      expect(
        shouldReportLiveSpeechError('no-speech', isListening: true),
        isFalse,
      );
    });

    test('late errors after stop or disposal do not change the UI', () {
      for (final code in ['no-speech', 'aborted', 'network', 'not-allowed']) {
        expect(shouldReportLiveSpeechError(code, isListening: false), isFalse);
      }
    });

    test('permission, capture and unexpected errors remain fatal', () {
      for (final code in [
        'not-allowed',
        'service-not-allowed',
        'audio-capture',
        'network',
        'aborted',
        'language-not-supported',
        'unknown',
      ]) {
        expect(shouldReportLiveSpeechError(code, isListening: true), isTrue);
      }
    });
  });
}
