import '../domain/voice_clone_consent_models.dart';

VoiceConsentAudioRecorder createVoiceConsentAudioRecorder() =>
    _StubVoiceConsentAudioRecorder();

class _StubVoiceConsentAudioRecorder implements VoiceConsentAudioRecorder {
  @override
  bool get isMicrophoneSupported => false;

  @override
  Future<void> startRecording() {
    return Future<void>.error(
      UnsupportedError(
        'この端末環境ではブラウザ直接マイク録音が無効です。録音済み音声ファイルを選択してください。',
      ),
    );
  }

  @override
  Future<VoiceAudioCaptureResult> stopRecording() {
    return Future<VoiceAudioCaptureResult>.error(
      UnsupportedError('Microphone recording is not active.'),
    );
  }

  @override
  Future<void> dispose() async {}
}
