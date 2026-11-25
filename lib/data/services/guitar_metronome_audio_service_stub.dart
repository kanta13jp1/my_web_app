import 'guitar_metronome_audio_service.dart';

GuitarMetronomeAudioService createGuitarMetronomeAudioService() =>
    const NoopGuitarMetronomeAudioService();

/// 非Web/VMテスト環境向けの安全なサイレント実装。
class NoopGuitarMetronomeAudioService implements GuitarMetronomeAudioService {
  const NoopGuitarMetronomeAudioService();

  @override
  bool get isAudioSupported => false;

  @override
  void playClick({required bool accent}) {}

  @override
  void dispose() {}
}
