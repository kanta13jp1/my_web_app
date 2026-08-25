import 'live_speech_recognizer_base.dart';
import 'live_speech_recognizer_stub.dart'
    if (dart.library.js_interop) 'live_speech_recognizer_web.dart' as platform;

export 'live_speech_recognizer_base.dart';

LiveSpeechRecognizer createLiveSpeechRecognizer() =>
    platform.createLiveSpeechRecognizer();
