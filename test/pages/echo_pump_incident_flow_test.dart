import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/echo_pump_game_page.dart';
import 'package:my_web_app/services/echo_pump_audio.dart';

class _Output implements EchoPumpAudioOutput {
  final cues = <EchoPumpCue>[];
  bool musicPlaying = false;
  int stops = 0;
  @override
  Future<void> music(bool playing, double volume) async {
    musicPlaying = playing;
  }

  @override
  Future<void> effect(EchoPumpCue cue, double volume) async {
    cues.add(cue);
  }

  @override
  Future<void> silenceEffects() async {
    stops++;
  }

  @override
  Future<void> close() async {}
}

void main() {
  for (final skip in [false, true]) {
    testWidgets(
      'incident ${skip ? 'skip' : 'end'} stops walking and returns without a turn',
      (tester) async {
        final output = _Output();
        final audio = EchoPumpAudio(output: output);
        audio.setEnabled(true);
        await audio.settled;
        await tester.pumpWidget(
          MaterialApp(home: EchoPumpGamePage(audio: audio)),
        );
        await tester.tap(find.byKey(const Key('echo-start')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('echo-intro-skip')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('保守メモを調べる'));
        await tester.tap(find.text('保守メモを調べる'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('歩行中…'), findsOneWidget);
        await tester.ensureVisible(
          find.byKey(const Key('echo-incident-inspect')),
        );
        await tester.tap(find.byKey(const Key('echo-incident-inspect')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        await audio.settled;
        await tester.pump();
        expect(find.text('設備異常 1 / 3'), findsOneWidget);
        final steps = output.cues.where((c) => c == EchoPumpCue.step).length;
        await tester.pump(const Duration(seconds: 2));
        await audio.settled;
        expect(output.cues.where((c) => c == EchoPumpCue.step).length, steps);
        expect(output.stops, greaterThan(0));
        expect(output.musicPlaying, isTrue);
        expect(find.text('夜間保守メモ 1 / 2'), findsNothing);
        if (skip) {
          await tester.tap(find.text('スキップして探索へ'));
        } else {
          await tester.pump(const Duration(seconds: 8));
        }
        await tester.pumpAndSettle();
        expect(find.text('ターン 0'), findsOneWidget);
        expect(find.text('異常灯：確認済み'), findsOneWidget);
        await tester.tap(find.byKey(const Key('echo-incident-inspect')));
        await tester.pumpAndSettle();
        expect(find.text('設備異常 1 / 3'), findsNothing);
        await tester.tap(find.text('探索へ戻る'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('保守メモを調べる'));
        await tester.tap(find.text('保守メモを調べる'));
        await tester.pumpAndSettle();
        await audio.settled;
        expect(find.text('夜間保守メモ 1 / 2'), findsOneWidget);
        expect(
          output.cues.where((c) => c == EchoPumpCue.step).length,
          greaterThan(steps),
        );
        await tester.tap(find.text('メモを閉じる'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('最初からやり直す'));
        await tester.pumpAndSettle();
        expect(find.text('異常灯を調べる'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        audio.dispose();
      },
    );
  }
}
