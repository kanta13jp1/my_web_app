import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/echo_pump_game.dart';
import 'package:my_web_app/services/echo_pump_audio.dart';
import 'package:my_web_app/widgets/echo_pump_guidance.dart';

void main() {
  testWidgets('progress changes only after a successful recovery and repair',
      (tester) async {
    final game = EchoPumpGame();
    Future<void> show() => tester.pumpWidget(
        MaterialApp(home: Scaffold(body: EchoPumpProgress(game: game)),),);
    await show();
    expect(find.text('NEXT'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNothing);
    game.collectFuse(); // Invalid location must not advance the displayed goals.
    await show();
    expect(find.byIcon(Icons.check_circle), findsNothing);
    game.togglePower(PumpCircuit.b);
    game.togglePower(PumpCircuit.a);
    game.move(PumpRoom.hall);
    game.move(PumpRoom.workshop);
    game.collectFuse();
    await show();
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    game.move(PumpRoom.hall);
    game.move(PumpRoom.pump);
    game.repair();
    await show();
    expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
  });

  for (final reducedMotion in [false, true]) {
    testWidgets(
        'action feedback is usable at 320px and large text, reduced motion $reducedMotion',
        (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
        data: MediaQueryData(
            disableAnimations: reducedMotion,
            textScaler: const TextScaler.linear(2),),
        child: Scaffold(
            body: SingleChildScrollView(
                child: Column(children: [
          EchoPumpProgress(game: EchoPumpGame()),
          const EchoPumpActionVisual(
              revision: 1,
              cue: EchoPumpCue.step,
              from: PumpRoom.control,
              to: PumpRoom.hall,
              message: '中央廊下へ移動した。',
              blocked: false,),
        ],),),),
      ),),);
      await tester.pumpAndSettle();
      expect(find.text('管理室 → 中央廊下'), findsOneWidget);
      expect(find.byIcon(Icons.directions_walk), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
