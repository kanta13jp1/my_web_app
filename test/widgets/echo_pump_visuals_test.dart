import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/echo_pump_game.dart';
import 'package:my_web_app/widgets/echo_pump_visuals.dart';

void main() {
  for (final width in [320.0, 1120.0]) {
    testWidgets('visual state at $width with enlarged text', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      addTearDown(semantics.dispose);
      final game = EchoPumpGame()..togglePower(PumpCircuit.b);

      Future<void> show() async {
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2),
              ),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    EchoPumpScene(game: game),
                    EchoPumpFacilityMap(game: game),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await show();
      expect(find.text('● B 整備 ON'), findsOneWidget);
      expect(find.bySemanticsLabel('管理室 ● 現在地'), findsOneWidget);
      expect(game.turn, 1);
      expect(tester.takeException(), isNull);
      game.move(PumpRoom.hall);
      game.move(PumpRoom.pump);
      await show();
      expect(find.bySemanticsLabel('ポンプ室 ● 現在地'), findsOneWidget);
      expect(find.text('中央廊下 ● 現在地'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
