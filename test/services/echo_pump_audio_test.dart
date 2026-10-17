import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/echo_pump_audio.dart';

class FakeOutput implements EchoPumpAudioOutput {
  bool playing = false;
  bool closed = false;
  bool failMusic = false;
  double volume = 0;
  int stops = 0;
  final effects = <EchoPumpCue>[];
  Completer<void>? gate;

  @override
  Future<void> music(bool value, double level) async {
    if (value && failMusic) throw StateError('blocked');
    if (value && gate != null) await gate!.future;
    if (closed) return;
    playing = value;
    volume = level;
  }

  @override
  Future<void> effect(EchoPumpCue cue, double volume) async {
    if (!closed) effects.add(cue);
  }

  @override
  Future<void> silenceEffects() async {
    stops++;
  }

  @override
  Future<void> close() async {
    closed = true;
    playing = false;
  }
}

void main() {
  late FakeOutput output;
  late EchoPumpAudio audio;
  setUp(() {
    output = FakeOutput();
    audio = EchoPumpAudio(output: output);
  });
  tearDown(() => audio.dispose());

  test('opt in is required and effects do not replace BGM', () async {
    audio.cue(EchoPumpCue.start);
    await audio.settled;
    expect(output.effects, isEmpty);
    expect(output.playing, isFalse);
    audio.setEnabled(true);
    await audio.settled;
    expect(output.playing, isTrue);
    expect(output.volume, closeTo(0.35 * 0.55, 0.001));
    audio.cue(EchoPumpCue.power);
    await audio.settled;
    expect(output.effects, [EchoPumpCue.power]);
    expect(output.playing, isTrue);
    audio.setEnabled(false);
    await audio.settled;
    audio.cue(EchoPumpCue.step);
    await audio.settled;
    expect(output.playing, isFalse);
    expect(output.stops, greaterThan(0));
    expect(output.effects, [EchoPumpCue.power]);
  });

  test('background stops sound and resume does not replay old effects', () async {
    audio.setEnabled(true);
    await audio.settled;
    audio.cue(EchoPumpCue.step);
    audio.setForeground(false);
    await audio.settled;
    expect(output.effects, isEmpty);
    expect(output.playing, isFalse);
    audio.setForeground(true);
    await audio.settled;
    expect(output.playing, isTrue);
    expect(output.effects, isEmpty);
  });

  test('ending pauses BGM but allows the ending cue, retry resumes BGM', () async {
    audio.setEnabled(true);
    await audio.settled;
    audio.setMusicActive(false);
    audio.cue(EchoPumpCue.escape);
    await audio.settled;
    expect(output.playing, isFalse);
    expect(output.effects, [EchoPumpCue.escape]);
    audio.setMusicActive(true);
    await audio.settled;
    expect(output.playing, isTrue);
  });

  test('volume clamps, zero mutes, and NaN is ignored', () async {
    audio.setEnabled(true);
    audio.setVolume(3);
    await audio.settled;
    expect(audio.volume, 1);
    audio.setVolume(0);
    await audio.settled;
    expect(output.playing, isFalse);
    audio.setVolume(double.nan);
    expect(audio.volume, 0);
    audio.setVolume(-1);
    expect(audio.volume, 0);
  });

  test('blocked playback turns sound off and supports an explicit retry', () async {
    output.failMusic = true;
    audio.setEnabled(true);
    await audio.settled;
    expect(audio.enabled, isFalse);
    expect(audio.error, isNotNull);
    output.failMusic = false;
    audio.setEnabled(true);
    await audio.settled;
    expect(audio.error, isNull);
    expect(output.playing, isTrue);
  });

  test('muting during initialization cancels pending effects and late music', () async {
    output.gate = Completer<void>();
    audio.setEnabled(true);
    await Future<void>.delayed(Duration.zero);
    audio.cue(EchoPumpCue.start);
    audio.setEnabled(false);
    output.gate!.complete();
    await audio.settled;
    expect(output.playing, isFalse);
    expect(output.effects, isEmpty);
  });

  test('dispose closes output and prevents subsequent playback', () async {
    audio.setEnabled(true);
    await audio.settled;
    audio.dispose();
    audio.cue(EchoPumpCue.start);
    audio.setEnabled(true);
    await audio.settled;
    expect(output.closed, isTrue);
    expect(output.playing, isFalse);
    expect(output.effects, isEmpty);
  });
}
