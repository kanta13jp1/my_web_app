/// VM (単体/widget テスト) 用の `package:web` 最小スタブ。
/// Web ビルドでは条件付き import により本物の package:web が使われる。
library;

class TextDecoder {
  const TextDecoder(this.encoding);

  final String encoding;

  String decode(Object? input) {
    throw UnsupportedError('TextDecoder は Web ビルド専用です');
  }
}

class Window {
  const Window();

  void open(String url, String target) {}
}

const Window window = Window();

class SpeechRecognitionAlternative {
  const SpeechRecognitionAlternative();

  final String transcript = '';
}

class SpeechRecognitionResult {
  const SpeechRecognitionResult();

  final bool isFinal = true;

  SpeechRecognitionAlternative item(int index) =>
      const SpeechRecognitionAlternative();
}

class SpeechRecognitionResultList {
  const SpeechRecognitionResultList();

  final int length = 0;

  SpeechRecognitionResult item(int index) => const SpeechRecognitionResult();
}

class SpeechRecognitionEvent {
  const SpeechRecognitionEvent();

  final SpeechRecognitionResultList results =
      const SpeechRecognitionResultList();
}

class SpeechRecognitionErrorEvent {
  const SpeechRecognitionErrorEvent();
}

class SpeechRecognition {
  SpeechRecognition() {
    throw UnsupportedError('SpeechRecognition は Web ビルド専用です');
  }

  String lang = 'ja-JP';
  bool continuous = false;
  bool interimResults = false;
  int maxAlternatives = 1;
  Object? onresult;
  Object? onend;
  Object? onerror;

  void start() {}
  void stop() {}
  void abort() {}
}
