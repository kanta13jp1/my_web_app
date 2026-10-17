import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/echo_pump_game.dart';
import 'package:my_web_app/widgets/echo_pump_inventory.dart';

EchoPumpGame stockedGame() => EchoPumpGame()
  ..togglePower(PumpCircuit.b)
  ..togglePower(PumpCircuit.a)
  ..move(PumpRoom.hall)
  ..move(PumpRoom.workshop)
  ..collectFuse();

void main() {
  Future<void> showInventory(WidgetTester tester, EchoPumpGame game,
      {ValueChanged<EchoPumpInventoryAction?>? onResult,
      double scale = 1}) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Builder(
          builder: (context) => Scaffold(
                  body: TextButton(
                key: const Key('open'),
                onPressed: () async {
                  final result = await showDialog<EchoPumpInventoryAction>(
                    context: context,
                    builder: (_) => EchoPumpInventoryDialog(game: game),
                  );
                  onResult?.call(result);
                },
                child: const Text('開く'),
              ))),
    ));
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
  }

  testWidgets('empty and carried inventory are read-only away from the pump',
      (tester) async {
    for (final game in [EchoPumpGame(), stockedGame()]) {
      final turn = game.turn;
      final enemy = game.enemy;
      final health = game.health;
      await showInventory(tester, game);
      expect(find.text(game.hasFuse ? '交換ヒューズ' : '所持品は空'), findsOneWidget);
      expect(find.text('所持数 ${game.hasFuse ? 1 : 0}'), findsOneWidget);
      expect(find.byKey(const Key('echo-inventory-use')), findsNothing);
      await tester.tap(find.byKey(const Key('echo-inventory-close')));
      await tester.pumpAndSettle();
      expect(game.turn, turn);
      expect(game.enemy, enemy);
      expect(game.health, health);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
      'double use returns one action and does not pop the underlying route',
      (tester) async {
    final game = stockedGame()
      ..move(PumpRoom.hall)
      ..move(PumpRoom.pump);
    final results = <EchoPumpInventoryAction?>[];
    await showInventory(tester, game, onResult: results.add);
    final use = tester
        .widget<FilledButton>(find.byKey(const Key('echo-inventory-use')))
        .onPressed!;
    use();
    use();
    await tester.pumpAndSettle();
    expect(results, [EchoPumpInventoryAction.repair]);
    expect(find.byKey(const Key('open')), findsOneWidget);
    expect(
        game.hasFuse, isTrue); // The page, not the dialog, executes the rule.
    expect(tester.takeException(), isNull);
  });

  testWidgets('installed state cannot use a second fuse', (tester) async {
    final game = stockedGame()
      ..move(PumpRoom.hall)
      ..move(PumpRoom.pump)
      ..repair();
    await showInventory(tester, game);
    expect(find.text('ポンプへ装着済み'), findsOneWidget);
    expect(find.text('所持数 0'), findsOneWidget);
    expect(find.byKey(const Key('echo-inventory-use')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 1120.0]) {
    testWidgets('inventory is scrollable with 2x text at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final game = stockedGame()
        ..move(PumpRoom.hall)
        ..move(PumpRoom.pump);
      await showInventory(tester, game, scale: 2);
      await tester.ensureVisible(find.byKey(const Key('echo-inventory-use')));
      expect(find.byKey(const Key('echo-inventory-use')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
