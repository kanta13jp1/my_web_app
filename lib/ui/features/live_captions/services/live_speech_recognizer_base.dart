typedef LiveSpeechResultCallback = void Function({
  required String transcript,
  required bool isFinal,
});
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

/// Silence is recoverable through the recognition session's normal end event.
/// Errors arriving after an explicit stop must not change the stopped UI.
bool shouldReportLiveSpeechError(String code, {required bool isListening}) {
  return isListening && code != 'no-speech';
}
