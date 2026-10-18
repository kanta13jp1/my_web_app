import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/echo_pump_game_page.dart';
import 'package:my_web_app/widgets/echo_pump_door_transition.dart';
import 'package:my_web_app/models/echo_pump_game.dart';

void main() {
  for (final width in [320.0, 1200.0]) {
    for (final mode in ['complete', 'skip', 'reduce']) {
      testWidgets('door $mode at $width with enlarged text finishes once',
          (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var completions = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                disableAnimations: mode == 'reduce',
                textScaler: const TextScaler.linear(2),
              ),
              child: EchoPumpDoorTransition(
                from: PumpRoom.control,
                to: PumpRoom.hall,
                onFinished: () => completions++,
              ),
            ),
          ),
        );
        if (mode == 'complete') {
          await tester.pump(const Duration(milliseconds: 400));
          expect(completions, 0);
          expect(tester.hasRunningAnimations, isTrue);
        } else if (mode == 'skip') {
          await tester.tap(find.byKey(const Key('echo-door-skip')));
        } else {
          expect(completions, 1);
          expect(tester.hasRunningAnimations, isFalse);
        }
        await tester.pumpAndSettle();
        expect(completions, 1);
        await tester.tap(find.byKey(const Key('echo-door-skip')));
        await tester.pump(const Duration(seconds: 2));
        expect(completions, 1);
        expect(tester.takeException(), isNull);
      });
    }
    testWidgets('rapid move and skip consume one turn at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: EchoPumpGamePage()));
      await tester.tap(find.byKey(const Key('echo-start')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('echo-intro-skip')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('echo-move-exit')))
            .onPressed,
        isNull,
      );
      final move = tester
          .widget<OutlinedButton>(find.byKey(const Key('echo-move-hall')))
          .onPressed!;
      move();
      move();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(const Key('echo-door-transition')), findsOneWidget);
      await tester.tap(find.byKey(const Key('echo-door-skip')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('echo-door-transition')), findsNothing);
      expect(find.text('ターン 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in [360.0, 1200.0]) {
    testWidgets('play and retry at width $width without overflow',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: EchoPumpGamePage()));

      Future<void> tap(String key) async {
        final button = find.byKey(Key(key));
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      expect(find.byKey(const Key('echo-title-screen')), findsOneWidget);
      expect(find.byKey(const Key('echo-power-b')), findsNothing);
      await tester.tap(find.byKey(const Key('echo-start')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('echo-intro-skip')));
      await tester.pumpAndSettle();
      await tap('echo-inventory-toolbar');
      expect(find.text('所持品は空'), findsOneWidget);
      await tap('echo-inventory-close');
      expect(find.text('ターン 0'), findsOneWidget);
      final gameTheme = Theme.of(tester.element(find.byType(AppBar)));
      expect(gameTheme.textTheme.bodyMedium?.fontFamily, 'NotoSansJP');
      expect(gameTheme.brightness, Brightness.dark);
      await tap('echo-power-b');
      await tap('echo-power-a');
      await tap('echo-move-hall');
      await tap('echo-move-workshop');
      await tap('echo-collect');
      await tap('echo-inventory-toolbar');
      expect(find.text('所持数 1'), findsOneWidget);
      await tap('echo-inventory-close');
      expect(find.text('ターン 5'), findsOneWidget);
      await tap('echo-move-hall');
      await tap('echo-move-pump');
      await tap('echo-inventory-toolbar');
      await tap('echo-inventory-use');
      expect(find.text('ターン 8'), findsOneWidget);
      expect(find.text('所持品：装着済み'), findsOneWidget);
      await tap('echo-move-hall');
      await tap('echo-move-control');
      await tap('echo-power-b');
      await tap('echo-power-c');
      await tap('echo-wait');
      await tap('echo-wait');
      await tap('echo-move-hall');
      await tap('echo-move-pump');
      await tap('echo-seal');
      await tap('echo-drain');
      await tap('echo-move-hall');
      await tap('echo-move-control');
      await tap('echo-move-exit');
      expect(find.text('脱出成功'), findsOneWidget);
      await tap('echo-retry');
      expect(find.text('ターン 0'), findsOneWidget);
      expect(find.text('体力 3 / 3'), findsOneWidget);
    });
  }
}
