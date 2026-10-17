import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/echo_pump_game_page.dart';
import 'package:my_web_app/services/echo_pump_audio.dart';

import '../services/echo_pump_audio_test.dart' show FakeOutput;

void main() {
  for (final width in [320.0, 1200.0]) {
    testWidgets('audio controls and gameplay remain usable at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final output = FakeOutput();
      final audio = EchoPumpAudio(output: output);
      addTearDown(audio.dispose);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(width == 320 ? 2 : 1),
            ),
            child: child!,
          ),
          home: EchoPumpGamePage(audio: audio),
        ),
      );
      expect(find.text('音をON'), findsOneWidget);
      await tester.tap(find.byKey(const Key('echo-audio-toggle')));
      await tester.pumpAndSettle();
      expect(output.playing, isTrue);
      await tester.tap(find.byKey(const Key('echo-start')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('echo-intro-skip')));
      await tester.pumpAndSettle();
      output.effects.clear();
      await tester.ensureVisible(find.byKey(const Key('echo-power-b')));
      await tester.tap(find.byKey(const Key('echo-power-b')));
      await tester.pumpAndSettle();
      expect(output.effects, contains(EchoPumpCue.power));
      await tester.tap(find.byKey(const Key('echo-audio-toggle')));
      await tester.pumpAndSettle();
      expect(output.playing, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await audio.settled;
    });
  }

  testWidgets('audio failure still allows starting and operating the game',
      (tester) async {
    final output = FakeOutput()..failMusic = true;
    final audio = EchoPumpAudio(output: output);
    addTearDown(audio.dispose);
    await tester.pumpWidget(
      MaterialApp(home: EchoPumpGamePage(audio: audio)),
    );
    await tester.tap(find.byKey(const Key('echo-audio-toggle')));
    await tester.pumpAndSettle();
    expect(find.textContaining('再生できませんでした'), findsOneWidget);
    await tester.tap(find.byKey(const Key('echo-start')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('echo-intro-skip')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('echo-wait')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await audio.settled;
  });
}
