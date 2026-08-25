typedef LiveSpeechResultCallback = void Function(String transcript, bool isFinal);
typedef LiveSpeechErrorCallback = void Function(String message);

abstract class LiveSpeechRecognizer {
  bool get isSupported;

  Future<void> start({
    required String languageTag,
    required LiveSpeechResultCallback onResult,
    required LiveSpeechErrorCallback onError,
  });

  Future<void> stop();

  void dispose();
}

class LiveSpeechRecognitionException implements Exception {
  const LiveSpeechRecognitionException(this.message);

  final String message;

  @override
  String toString() => message;
}
