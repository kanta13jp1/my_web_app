import 'live_speech_recognizer_base.dart';

LiveSpeechRecognizer createLiveSpeechRecognizer() =>
    _UnsupportedLiveSpeechRecognizer();

class _UnsupportedLiveSpeechRecognizer implements LiveSpeechRecognizer {
  @override
  bool get isSupported => false;

  @override
  Future<void> start({
    required String languageTag,
    required LiveSpeechResultCallback onResult,
    required LiveSpeechErrorCallback onError,
  }) {
    throw const LiveSpeechRecognitionException('この端末ではブラウザー音声認識を利用できません。');
  }

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}
}
