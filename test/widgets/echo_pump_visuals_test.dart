import 'package:my_web_app/widgets/echo_pump_door_transition.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/echo_pump_game.dart';
import 'package:my_web_app/widgets/echo_pump_visuals.dart';
import 'package:my_web_app/widgets/echo_pump_machinery.dart';

void main() {
  for (final skip in [false, true]) {
    testWidgets('door audio phase callbacks finish once, skip=$skip',
        (tester) async {
      var opened = 0, closed = 0, finished = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: EchoPumpDoorTransition(
            from: PumpRoom.control,
            to: PumpRoom.hall,
            onOpen: () => opened++,
            onClose: () => closed++,
            onFinished: () => finished++,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(opened, 1);
      expect(closed, 0);
      if (skip) await tester.tap(find.text('演出をスキップ'));
      await tester.pump(const Duration(seconds: 2));
      expect(finished, 1);
      expect(closed, skip ? 0 : 1);
      await tester.pump(const Duration(seconds: 2));
      expect(finished, 1);
      expect(closed, skip ? 0 : 1);
    });
  }

  for (final room in PumpRoom.values) {
    testWidgets('room backdrop describes ${room.name} without image assets',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 390,
            height: 240,
            child: EchoPumpRoomBackdrop(room: room),
          ),
        ),
      );
      expect(
        find.bySemanticsLabel('部屋の背景：${EchoPumpRoomBackdrop.features[room]}'),
        findsOneWidget,
      );
      expect(find.byType(Image), findsNothing);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }

  for (final width in [320.0, 1120.0]) {
    testWidgets(
        'machinery transitions settle at $width, including reduced motion',
        (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      try {
        Future<void> show(bool complete, {bool reduced = false}) async {
          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  disableAnimations: reduced,
                  textScaler: const TextScaler.linear(2),
                ),
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: EchoPumpMachinery(
                      repaired: complete,
                      sealed: complete,
                      drained: complete,
                      powered: complete,
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        await show(false);
        expect(
          find.bySemanticsLabel('設備断面：ヒューズ未装着、隔壁開放、水位高・冠水中、C系統停止'),
          findsOneWidget,
        );
        await show(true);
        await tester.pump(const Duration(milliseconds: 450));
        expect(tester.hasRunningAnimations, isTrue);
        expect(
          find.bySemanticsLabel('設備断面：ヒューズ装着済み、隔壁閉鎖、水位低下・排水完了、C系統通電'),
          findsOneWidget,
        );
        await tester.pumpAndSettle();
        expect(tester.hasRunningAnimations, isFalse);
        expect(tester.takeException(), isNull);
        await show(false, reduced: true);
        // Reduced motion shows the final committed state immediately.
        expect(find.text('冠水中'), findsOneWidget);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    });
  }

  for (final width in [320.0, 1120.0]) {
    testWidgets('visual state at $width with enlarged text', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      try {
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
        await tester.ensureVisible(find.byKey(const Key('echo-map-control')));
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel('管理室 ● 現在地'), findsOneWidget);
        expect(game.turn, 1);
        expect(tester.takeException(), isNull);
        game.togglePower(PumpCircuit.a);
        game.move(PumpRoom.hall);
        game.move(PumpRoom.pump);
        await show();
        await tester.ensureVisible(find.byKey(const Key('echo-map-pump')));
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel('ポンプ室 ● 現在地'), findsOneWidget);
        expect(find.text('中央廊下 ● 現在地'), findsNothing);
        await tester.ensureVisible(find.text('区画の接続一覧'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('区画の接続一覧'));
        await tester.pumpAndSettle();
        expect(find.text('管理室：中央廊下・出口'), findsOneWidget);
        expect(find.text('ポンプ室：中央廊下・点検槽'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    });
  }
}
