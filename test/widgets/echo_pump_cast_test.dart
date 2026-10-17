import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/echo_pump_game.dart';
import 'package:my_web_app/widgets/echo_pump_cast.dart';

void main() {
  Future<void> show(
    WidgetTester tester,
    EchoPumpGame game, {
    bool reduced = false,
    double scale = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            disableAnimations: reduced,
            textScaler: TextScaler.linear(scale),
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              child: EchoPumpCast(game: game),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('separate locations, safe base, noise and nearby threat',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      final game = EchoPumpGame();
      await show(tester, game);
      expect(find.bySemanticsLabel('あなた / 保守員：管理室、安全な拠点'), findsOneWidget);
      expect(find.bySemanticsLabel('敵 / 音を追う影：ポンプ室、別区画'), findsOneWidget);
      game.togglePower(PumpCircuit.b);
      await show(tester, game);
      expect(find.bySemanticsLabel('敵の誘導先：工具庫の機械音'), findsOneWidget);
      game.togglePower(PumpCircuit.a);
      game.move(PumpRoom.hall);
      await show(tester, game);
      expect(find.text('接近注意'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('sealed enemy bars, escape, and retry follow actual rules',
      (tester) async {
    final game = EchoPumpGame()
      ..togglePower(PumpCircuit.b)
      ..togglePower(PumpCircuit.a)
      ..move(PumpRoom.hall)
      ..move(PumpRoom.workshop)
      ..collectFuse()
      ..move(PumpRoom.hall)
      ..move(PumpRoom.pump)
      ..repair()
      ..move(PumpRoom.hall)
      ..move(PumpRoom.control)
      ..togglePower(PumpCircuit.b)
      ..togglePower(PumpCircuit.c)
      ..wait()
      ..wait()
      ..move(PumpRoom.hall)
      ..move(PumpRoom.pump)
      ..seal();
    expect(game.sealed, isTrue);
    await show(tester, game);
    expect(find.text('封鎖済み'), findsOneWidget);
    expect(find.text('音で誘導'), findsNothing);
    game.drain();
    game.move(PumpRoom.hall);
    game.move(PumpRoom.control);
    game.move(PumpRoom.exit);
    await show(tester, game);
    expect(find.text('生還'), findsOneWidget);
    await show(tester, EchoPumpGame());
    expect(find.text('封鎖済み'), findsNothing);
    expect(find.text('安全な拠点'), findsOneWidget);
  });

  testWidgets('missing artwork retains state and fallback icons',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DefaultAssetBundle(
          bundle: _MissingArtBundle(),
          child: Scaffold(body: EchoPumpCast(game: EchoPumpGame())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.engineering), findsOneWidget);
    expect(find.byIcon(Icons.visibility), findsOneWidget);
    expect(find.text('安全な拠点'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('location change animates and settles without a loop',
      (tester) async {
    final game = EchoPumpGame();
    await show(tester, game);
    game.move(PumpRoom.hall);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(),
          child: Scaffold(
            body: SingleChildScrollView(
              child: EchoPumpCast(game: game),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 160));
    final transitions =
        tester.widgetList<SlideTransition>(find.byType(SlideTransition));
    expect(
      transitions
          .any((w) => w.position.value.dx > 0 && w.position.value.dx < 0.12),
      isTrue,
    );
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('contact failure is visible', (tester) async {
    final game = EchoPumpGame();
    for (var i = 0; i < 3; i++) {
      game.move(PumpRoom.hall);
      game.move(PumpRoom.pump);
    }
    expect(game.health, 0);
    await show(tester, game);
    expect(find.text('行動不能'), findsOneWidget);
  });

  for (final width in [320.0, 1120.0]) {
    testWidgets('2x text and reduced motion at $width', (tester) async {
      tester.view.physicalSize = Size(width, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final game = EchoPumpGame()..togglePower(PumpCircuit.b);
      await show(tester, game, reduced: true, scale: 2);
      for (final widget in tester
          .widgetList<AnimatedSwitcher>(find.byType(AnimatedSwitcher))) {
        expect(widget.duration, Duration.zero);
      }
      expect(find.text('音で誘導'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

class _MissingArtBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      throw StateError('Synthetic missing asset');
}
