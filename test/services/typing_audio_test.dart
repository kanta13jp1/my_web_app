import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/typing_audio.dart';

class FakeAudio implements TypingAudioBackend {
  int unlocks = 0;
  int disposals = 0;
  int suspends = 0;
  bool supported = true;
  bool active = false;
  double music = 0;
  double effects = 0;
  final sounds = <TypingSound>[];
  Completer<bool>? pending;
  @override
  Future<bool> unlock() async {
    unlocks++;
    return pending == null ? supported : pending!.future;
  }

  @override
  void levels(double music, double effects) {
    this.music = music;
    this.effects = effects;
  }

  @override
  void playing(bool value) => active = value;
  @override
  void effect(TypingSound sound) => sounds.add(sound);
  @override
  void suspend() {
    suspends++;
    active = false;
  }

  @override
  void dispose() {
    disposals++;
    active = false;
  }
}

void main() {
  test('no sound before opt-in; mute, end and retry preserve separate levels',
      () async {
    final backend = FakeAudio();
    final audio = TypingAudio(backend: backend);
    audio.setPlaying(true);
    audio.effect(TypingSound.letter);
    expect(backend.unlocks, 0);
    expect(backend.active, isFalse);
    expect(backend.sounds, isEmpty);
    audio.setVolumes(music: 0, effects: 0.7);
    await audio.enable();
    expect(backend.active, isTrue);
    expect(backend.music, 0);
    expect(backend.effects, 0.7);
    audio.effect(TypingSound.word);
    expect(backend.sounds, [TypingSound.word]);
    audio.setMuted(true);
    audio.effect(TypingSound.mistake);
    expect(backend.active, isFalse);
    expect(backend.sounds.length, 1);
    audio.setMuted(false);
    for (var i = 0; i < 20; i++) {
      audio.setPlaying(false);
      expect(backend.active, isFalse);
      audio.setPlaying(true);
    }
    expect(backend.unlocks, 1);
    expect(backend.effects, 0.7);
    audio.dispose();
    audio.dispose();
    expect(backend.disposals, 1);
  });

  test('hidden pages and late unlocks cannot restart sound', () async {
    final backend = FakeAudio()..pending = Completer<bool>();
    final audio = TypingAudio(backend: backend)..setPlaying(true);
    final enable = audio.enable();
    audio.hide();
    backend.pending!.complete(true);
    await enable;
    expect(audio.enabled, isFalse);
    expect(backend.active, isFalse);
    backend.pending = null;
    await audio.enable();
    expect(backend.active, isTrue);
    audio.hide();
    audio.setPlaying(false);
    audio.setPlaying(true);
    expect(backend.active, isFalse);
    await audio.enable();
    expect(backend.active, isTrue);
    audio.dispose();
    await audio.enable();
    expect(backend.unlocks, 3);
  });

  test('unsupported audio remains playable and disposal rejects pending enable',
      () async {
    final backend = FakeAudio()..supported = false;
    final audio = TypingAudio(backend: backend)..setPlaying(true);
    await audio.enable();
    expect(audio.unavailable, isTrue);
    expect(backend.active, isFalse);
    audio.setVolumes(music: double.nan, effects: 2);
    expect(audio.musicVolume, 0.25);
    expect(audio.effectsVolume, 1);
    backend.pending = Completer<bool>();
    final enable = audio.enable();
    audio.dispose();
    backend.pending!.complete(true);
    await enable;
    audio.effect(TypingSound.word);
    expect(backend.sounds, isEmpty);
    expect(backend.disposals, 1);
  });
}
