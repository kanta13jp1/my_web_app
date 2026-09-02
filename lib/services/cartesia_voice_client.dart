import 'cartesia_voice_client_stub.dart'
    if (dart.library.js_interop) 'cartesia_voice_client_web.dart' as platform;
import 'cartesia_voice_session_service.dart';

typedef CartesiaTranscriptCallback = void Function(String transcript);
typedef CartesiaStatusCallback = void Function(String status);
typedef CartesiaErrorCallback = void Function(String message);

abstract interface class CartesiaVoiceClient {
  bool get isSupported;

  Future<void> start({
    required CartesiaVoiceSessionConfig config,
    required CartesiaTranscriptCallback onTranscript,
    required CartesiaStatusCallback onStatus,
    required CartesiaErrorCallback onError,
  });

  Future<void> speak(String text, CartesiaVoiceStyle style);

  Future<void> stop();
}

CartesiaVoiceClient createCartesiaVoiceClient() =>
    platform.createCartesiaVoiceClient();
