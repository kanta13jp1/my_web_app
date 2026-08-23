import 'cartesia_voice_client.dart';
import 'cartesia_voice_session_service.dart';

CartesiaVoiceClient createCartesiaVoiceClient() =>
    const UnsupportedCartesiaVoiceClient();

class UnsupportedCartesiaVoiceClient implements CartesiaVoiceClient {
  const UnsupportedCartesiaVoiceClient();

  @override
  bool get isSupported => false;

  @override
  Future<void> start({
    required CartesiaVoiceSessionConfig config,
    required CartesiaTranscriptCallback onTranscript,
    required CartesiaStatusCallback onStatus,
    required CartesiaErrorCallback onError,
  }) {
    throw UnsupportedError('Cartesia voice calls require a web browser');
  }

  @override
  Future<void> speak(String text, CartesiaVoiceStyle style) async {}

  @override
  Future<void> stop() async {}
}
