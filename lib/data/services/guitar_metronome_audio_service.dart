import 'guitar_metronome_audio_service_stub.dart'
    if (dart.library.js_interop) 'guitar_metronome_audio_service_web.dart'
    as platform;

/// ギター練習用メトロノームのクリック音声を再生する抽象サービス。
abstract interface class GuitarMetronomeAudioService {
  bool get isAudioSupported;

  void playClick({required bool accent});

  void dispose();
}

GuitarMetronomeAudioService createGuitarMetronomeAudioService() =>
    platform.createGuitarMetronomeAudioService();
