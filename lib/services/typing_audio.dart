import 'typing_audio_stub.dart'
    if (dart.library.js_interop) 'typing_audio_web.dart' as platform;

enum TypingSound { letter, word, mistake }

abstract class TypingAudioBackend {
  Future<bool> unlock();
  void levels(double music, double effects);
  void playing(bool value);
  void effect(TypingSound sound);
  void suspend();
  void dispose();
}

/// Volatile, opt-in sound settings. No assets, network or persistent storage.
class TypingAudio {
  TypingAudio({TypingAudioBackend? backend})
      : _backend = backend ?? platform.createTypingAudioBackend();

  final TypingAudioBackend _backend;
  bool enabled = false;
  bool muted = false;
  bool unavailable = false;
  bool _playing = false;
  bool _disposed = false;
  int _generation = 0;
  double musicVolume = 0.25;
  double effectsVolume = 0.35;

  Future<void> enable() async {
    if (_disposed) return;
    final generation = ++_generation;
    final unlocked = await _backend.unlock();
    if (_disposed || generation != _generation) return;
    enabled = unlocked;
    unavailable = !unlocked;
    muted = false;
    _apply();
  }

  void setPlaying(bool value) {
    if (_disposed || value == _playing) return;
    _playing = value;
    _apply();
  }

  void setMuted(bool value) {
    if (_disposed) return;
    muted = value;
    _apply();
  }

  void setVolumes({double? music, double? effects}) {
    if (_disposed) return;
    if (music != null && music.isFinite) musicVolume = music.clamp(0, 1);
    if (effects != null && effects.isFinite) effectsVolume = effects.clamp(0, 1);
    _apply();
  }

  void effect(TypingSound sound) {
    if (!_disposed && enabled && !muted && _playing) _backend.effect(sound);
  }

  void _apply() {
    if (_disposed) return;
    final audible = enabled && !muted && _playing;
    _backend.levels(musicVolume, effectsVolume);
    _backend.playing(audible);
    if (!audible) _backend.suspend();
  }

  /// Hidden/covered pages require another explicit gesture to resume sound.
  void hide() {
    if (_disposed) return;
    _generation++;
    enabled = false;
    _backend.playing(false);
    _backend.suspend();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _backend.dispose();
  }
}
