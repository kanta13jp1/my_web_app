import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/echo_pump_game_page.dart';
import 'package:my_web_app/widgets/echo_pump_intro.dart';

void main() {
  testWidgets('three scenes finish once, then skip cannot finish again',
      (tester) async {
    var finishes = 0;
    await tester.pumpWidget(MaterialApp(
      home: EchoPumpIntro(onFinished: () => finishes++),
    ));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('23:47 / 豪雨'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    expect(find.text('非常電源 / 残りわずか'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    expect(find.text('残響 / ポンプ室'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    expect(finishes, 1);
    await tester.tap(find.byKey(const Key('echo-intro-skip')));
    await tester.pump();
    expect(finishes, 1);
  });

  testWidgets('pause and lifecycle suspension preserve the timeline',
      (tester) async {
    var finishes = 0;
    await tester.pumpWidget(MaterialApp(
      home: EchoPumpIntro(onFinished: () => finishes++),
    ));
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.byKey(const Key('echo-intro-pause')));
    await tester.pump(const Duration(seconds: 25));
    expect(finishes, 0);
    expect(find.text('23:47 / 豪雨'), findsOneWidget);
    await tester.tap(find.byKey(const Key('echo-intro-pause')));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump(const Duration(seconds: 25));
    expect(finishes, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(seconds: 19));
    expect(finishes, 1);
  });

  testWidgets('disposing during intro never starts the game later',
      (tester) async {
    var finishes = 0;
    await tester.pumpWidget(MaterialApp(
      home: EchoPumpIntro(onFinished: () => finishes++),
    ));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
    expect(finishes, 0);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(360, 640), const Size(800, 360)]) {
    testWidgets('large text and reduced motion fit at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var finishes = 0;
      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: const TextScaler.linear(2),
            disableAnimations: true,
          ),
          child: EchoPumpIntro(onFinished: () => finishes++),
        ),
      ));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      expect(finishes, 0);
      await tester.tap(find.byKey(const Key('echo-intro-skip')));
      expect(finishes, 1);
    });
  }

  testWidgets('page starts gameplay after natural completion', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: EchoPumpGamePage()));
    await tester.tap(find.byKey(const Key('echo-start')));
    await tester.pump();
    expect(find.byKey(const Key('echo-intro')), findsOneWidget);
    expect(find.byKey(const Key('echo-power-b')), findsNothing);
    await tester.pump(const Duration(seconds: 19));
    await tester.pump();
    expect(find.byKey(const Key('echo-intro')), findsNothing);
    expect(find.byKey(const Key('echo-power-b')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
