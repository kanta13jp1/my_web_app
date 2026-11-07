import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'typing_audio.dart';

TypingAudioBackend createTypingAudioBackend() => _SynthAudio();

class _SynthAudio implements TypingAudioBackend {
  web.AudioContext? _context;
  final _voices = <web.OscillatorNode>{};
  Timer? _music;
  bool _disposed = false;
  bool _wanted = false;
  bool _authorized = false;
  double _musicLevel = 0.25;
  double _effectsLevel = 0.35;
  double _lastEffect = -1;
  int _note = 0;
  late final JSFunction _visibility = ((web.Event event) {
    if (web.document.hidden) {
      _authorized = false;
      suspend();
    }
  }).toJS;

  _SynthAudio() {
    web.document.addEventListener('visibilitychange', _visibility);
  }

  @override
  Future<bool> unlock() async {
    if (_disposed || web.document.hidden) return false;
    try {
      final context = _context ??= web.AudioContext();
      // Called synchronously from the opt-in button before the first await.
      await context.resume().toDart;
      if (_disposed || web.document.hidden) return false;
      _authorized = context.state == 'running';
      return _authorized;
    } catch (_) {
      _authorized = false;
      return false;
    }
  }

  @override
  void levels(double music, double effects) {
    _musicLevel = music;
    _effectsLevel = effects;
    // Clear already scheduled tones when a volume is reduced or muted.
    _stopVoices();
  }

  @override
  void playing(bool value) {
    _wanted = value;
    if (!value || !_authorized || web.document.hidden || _disposed) {
      suspend();
      return;
    }
    final context = _context;
    if (context == null) return;
    if (context.state != 'running') {
      // Resume is still subject to browser gesture policy; never assume success.
      context.resume().toDart.then((_) {
        if (!_disposed && _wanted && _authorized && !web.document.hidden) {
          _startMusic();
        }
      }).catchError((Object _) {});
    } else {
      _startMusic();
    }
  }

  void _startMusic() {
    if (_music != null || _disposed) return;
    // Original, simple synthesized arpeggio; no downloaded/recorded music.
    const notes = [
      261.63,
      329.63,
      392.0,
      329.63,
      293.66,
      349.23,
      440.0,
      349.23,
    ];
    _music = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (!_wanted || !_authorized || web.document.hidden) return;
      _tone(notes[_note++ % notes.length], 0.24, _musicLevel * 0.12);
    });
  }

  void _tone(double frequency, double duration, double volume) {
    final context = _context;
    if (context == null ||
        context.state != 'running' ||
        volume <= 0 ||
        _voices.length >= 2 ||
        _disposed ||
        !_authorized ||
        web.document.hidden) {
      return;
    }
    try {
      final oscillator = context.createOscillator();
      final gain = context.createGain();
      final now = context.currentTime;
      oscillator.type = 'sine';
      oscillator.frequency.value = frequency;
      gain.gain.setValueAtTime(0, now);
      gain.gain.linearRampToValueAtTime(volume, now + 0.008);
      gain.gain.linearRampToValueAtTime(0, now + duration);
      oscillator.connect(gain);
      gain.connect(context.destination);
      _voices.add(oscillator);
      oscillator.addEventListener(
        'ended',
        ((web.Event event) {
          _voices.remove(oscillator);
          oscillator.disconnect();
          gain.disconnect();
        }).toJS,
      );
      oscillator.start(now);
      oscillator.stop(now + duration);
    } catch (_) {
      suspend();
    }
  }

  @override
  void effect(TypingSound sound) {
    final context = _context;
    if (context == null || !_wanted || !_authorized || _disposed) return;
    if (context.currentTime - _lastEffect < 0.09) return;
    _lastEffect = context.currentTime;
    final frequency = switch (sound) {
      TypingSound.letter => 660.0,
      TypingSound.word => 880.0,
      TypingSound.mistake => 220.0,
    };
    _tone(frequency, 0.07, _effectsLevel * 0.12);
  }

  void _stopVoices() {
    for (final voice in _voices.toList()) {
      try {
        voice.stop();
      } catch (_) {/* Already ended. */}
      voice.disconnect();
    }
    _voices.clear();
  }

  @override
  void suspend() {
    _music?.cancel();
    _music = null;
    _stopVoices();
    final context = _context;
    if (context != null && context.state == 'running') {
      context.suspend().toDart.then<void>(
            (_) {},
            onError: (Object _, StackTrace __) {},
          );
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _authorized = false;
    suspend();
    web.document.removeEventListener('visibilitychange', _visibility);
    _context?.close().toDart.then<void>(
          (_) {},
          onError: (Object _, StackTrace __) {},
        );
    _context = null;
  }
}
