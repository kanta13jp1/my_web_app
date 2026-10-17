import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

enum EchoPumpCue {
  start,
  step,
  power,
  collect,
  repair,
  seal,
  drain,
  damage,
  escape,
  fail
}

/// Keeps platform playback separate from game rules and testable state.
abstract interface class EchoPumpAudioOutput {
  Future<void> music(bool playing, double volume);
  Future<void> effect(EchoPumpCue cue, double volume);
  Future<void> silenceEffects();
  Future<void> close();
}

class EchoPumpPlayerOutput implements EchoPumpAudioOutput {
  AudioPlayer? _music;
  AudioPlayer? _effect;
  bool _closed = false;
  bool _musicReady = false;
  int _effectRequest = 0;

  @override
  Future<void> music(bool playing, double volume) async {
    if (_closed) return;
    if (!playing) {
      await _music?.pause();
      return;
    }
    final player = _music ??= AudioPlayer();
    if (!_musicReady) {
      await player.setReleaseMode(ReleaseMode.loop);
      if (_closed) return;
      await player.play(AssetSource('echo_pump/bgm.wav'), volume: volume);
      _musicReady = true;
    } else {
      await player.setVolume(volume);
      if (_closed) return;
      if (player.state != PlayerState.playing) {
        await player.resume();
      }
    }
    if (_closed) await player.stop();
  }

  @override
  Future<void> effect(EchoPumpCue cue, double volume) async {
    if (_closed) return;
    final request = ++_effectRequest;
    final player = _effect ??= AudioPlayer();
    try {
      await player.stop();
      if (_closed || request != _effectRequest) return;
      await player.play(
        AssetSource('echo_pump/${cue.name}.wav'),
        volume: volume,
      );
    } catch (_) {
      // A stopped platform play may reject; cancellation is not a BGM failure.
      if (!_closed && request == _effectRequest) rethrow;
    }
    if (_closed || request != _effectRequest) await player.stop();
  }

  @override
  Future<void> silenceEffects() async {
    _effectRequest++;
    await _effect?.stop();
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await Future.wait([
      if (_music != null) _music!.dispose(),
      if (_effect != null) _effect!.dispose(),
    ]);
  }
}

/// Silent until the player explicitly opts in. Failed playback never blocks play.
class EchoPumpAudio extends ChangeNotifier {
  EchoPumpAudio({EchoPumpAudioOutput? output})
      : _output = output ?? EchoPumpPlayerOutput();

  final EchoPumpAudioOutput _output;
  Future<void> _pending = Future.value();
  bool _enabled = false;
  bool _foreground = true;
  bool _musicActive = true;
  bool _effectsSuspended = false;
  bool _closed = false;
  double _volume = 0.35;
  String? _error;
  int _effectGeneration = 0;

  bool get enabled => _enabled;
  double get volume => _volume;
  String? get error => _error;
  Future<void> get settled => _pending;
  bool get _audible => !_closed && _enabled && _foreground && _volume > 0;

  void _enqueue(Future<void> Function() action) {
    if (_closed) return;
    _pending = _pending.then((_) async {
      if (_closed) return;
      try {
        await action().timeout(const Duration(seconds: 5));
      } catch (_) {
        if (_closed) return;
        _enabled = false;
        _effectGeneration++;
        _error = '再生できませんでした。音をONにして再試行できます。';
        notifyListeners();
        try {
          await Future.wait([
            _output.music(false, 0),
            _output.silenceEffects(),
          ]).timeout(const Duration(seconds: 2));
        } catch (_) {
          // The game remains usable even when the platform cannot stop audio.
        }
      }
    });
  }

  void _sync() {
    _enqueue(() async {
      await _output.music(_audible && _musicActive, _volume * 0.55);
      if (!_audible) await _output.silenceEffects();
    });
  }

  void setEnabled(bool value) {
    if (_closed || value == _enabled) return;
    _enabled = value;
    _error = null;
    _effectGeneration++;
    notifyListeners();
    _sync();
  }

  void setVolume(double value) {
    if (_closed || !value.isFinite) return;
    final clamped = value.clamp(0.0, 1.0).toDouble();
    if (clamped == _volume) return;
    _volume = clamped;
    _effectGeneration++;
    notifyListeners();
    _sync();
  }

  void setForeground(bool value) {
    if (_closed || value == _foreground) return;
    _foreground = value;
    _effectGeneration++;
    _sync();
  }

  void setMusicActive(bool value) {
    if (_closed || value == _musicActive) return;
    _musicActive = value;
    _sync();
  }

  /// Invalidates queued effects and waits for an in-flight platform play to stop.
  /// Music and the user's sound preference stay active.
  Future<void> suspendEffects() {
    if (_closed) return Future<void>.value();
    _effectsSuspended = true;
    _effectGeneration++;
    unawaited(_output.silenceEffects().catchError((Object _) {}));
    _enqueue(() async {
      if (_effectsSuspended) await _output.silenceEffects();
    });
    return _pending;
  }

  void resumeEffects() {
    if (_closed || !_effectsSuspended) return;
    _effectsSuspended = false;
    _effectGeneration++;
  }

  void cue(EchoPumpCue cue) {
    if (!_audible || _effectsSuspended) return;
    final generation = ++_effectGeneration;
    _enqueue(() async {
      if (!_audible || _effectsSuspended || generation != _effectGeneration) {
        return;
      }
      await _output.effect(cue, _volume);
    });
  }

  @override
  void dispose() {
    if (_closed) return;
    _closed = true;
    _effectGeneration++;
    unawaited(_output.close().catchError((Object _) {}));
    super.dispose();
  }
}
