import '../domain/voice_clone_consent_models.dart';
import 'voice_audio_recorder_stub.dart'
    if (dart.library.js_interop) 'voice_audio_recorder_web.dart' as platform;

VoiceConsentAudioRecorder createVoiceConsentAudioRecorder() =>
    platform.createVoiceConsentAudioRecorder();
