import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'live_speech_recognizer_base.dart';

LiveSpeechRecognizer createLiveSpeechRecognizer() => _WebLiveSpeechRecognizer();

class _WebLiveSpeechRecognizer implements LiveSpeechRecognizer {
  _WebLiveSpeechRecognizer() {
    try {
      _recognition = web.SpeechRecognition();
    } catch (_) {
      _recognition = null;
    }
  }

  web.SpeechRecognition? _recognition;
  Timer? _restartTimer;
  bool _shouldListen = false;
  LiveSpeechResultCallback? _onResult;
  LiveSpeechErrorCallback? _onError;

  @override
  bool get isSupported => _recognition != null;

  @override
  Future<void> start({
    required String languageTag,
    required LiveSpeechResultCallback onResult,
    required LiveSpeechErrorCallback onError,
  }) async {
    final recognition = _recognition;
    if (recognition == null) {
      throw const LiveSpeechRecognitionException(
        'このブラウザーはWeb Speech APIに対応していません。',
      );
    }

    _restartTimer?.cancel();
    _shouldListen = true;
    _onResult = onResult;
    _onError = onError;
    recognition
      ..lang = languageTag
      ..continuous = true
      ..interimResults = true
      ..maxAlternatives = 1;

    recognition.onresult = ((web.SpeechRecognitionEvent event) {
      final results = event.results;
      for (var index = event.resultIndex; index < results.length; index++) {
        final result = results.item(index);
        if (result.length == 0) continue;
        final transcript = result.item(0).transcript.trim();
        if (transcript.isNotEmpty) {
          _onResult?.call(
            transcript: transcript,
            isFinal: result.isFinal,
          );
        }
      }
    }).toJS;

    recognition.onerror = ((web.SpeechRecognitionErrorEvent event) {
      final code = event.error;
      if (code == 'not-allowed' || code == 'service-not-allowed') {
        _shouldListen = false;
      }
      _onError?.call(_friendlySpeechError(code));
    }).toJS;

    recognition.onend = (() {
      if (!_shouldListen) return;
      _restartTimer?.cancel();
      _restartTimer = Timer(const Duration(milliseconds: 250), () {
        if (!_shouldListen) return;
        try {
          _recognition?.start();
        } catch (_) {
          _onError?.call('音声認識の再開に失敗しました。もう一度開始してください。');
        }
      });
    }).toJS;

    try {
      recognition.start();
    } catch (_) {
      _shouldListen = false;
      throw const LiveSpeechRecognitionException(
        '音声認識を開始できませんでした。マイク権限を確認してください。',
      );
    }
  }

  @override
  Future<void> stop() async {
    _shouldListen = false;
    _restartTimer?.cancel();
    _restartTimer = null;
    try {
      _recognition?.stop();
    } catch (_) {
      // The browser may already have ended the recognition session.
    }
  }

  @override
  void dispose() {
    _shouldListen = false;
    _restartTimer?.cancel();
    try {
      _recognition?.abort();
    } catch (_) {
      // Nothing remains to release when the browser already ended the session.
    }
    _recognition = null;
  }
}

String _friendlySpeechError(String code) {
  switch (code) {
    case 'not-allowed':
    case 'service-not-allowed':
      return 'マイク権限がありません。ブラウザー設定から許可してください。';
    case 'no-speech':
      return '音声を検出できませんでした。マイクへ近づいて話してください。';
    case 'audio-capture':
      return '利用できるマイクが見つかりません。';
    case 'network':
      return '音声認識サービスへ接続できませんでした。';
    default:
      return '音声認識でエラーが発生しました（$code）。';
  }
}
