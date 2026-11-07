import 'typing_audio.dart';

TypingAudioBackend createTypingAudioBackend() => _UnavailableAudio();

class _UnavailableAudio implements TypingAudioBackend {
  @override
  Future<bool> unlock() async => false;
  @override
  void levels(double music, double effects) {}
  @override
  void playing(bool value) {}
  @override
  void effect(TypingSound sound) {}
  @override
  void suspend() {}
  @override
  void dispose() {}
}
