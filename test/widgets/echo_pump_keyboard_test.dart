import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/echo_pump_game_page.dart';
import 'package:my_web_app/widgets/echo_pump_keyboard.dart';

void main() {
  for (final width in [320.0, 1200.0]) {
    testWidgets('opt-in keys preserve modal and movement turns at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: EchoPumpGamePage()));
      await tester.tap(find.byKey(const Key('echo-start')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('echo-intro-skip')));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
      await tester.pump();
      expect(find.text('ターン 0'), findsOneWidget);
      final toggle = find.byKey(const Key('echo-keyboard-toggle'));
      tester.widget<SwitchListTile>(toggle).onChanged!(true);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
      await tester.pumpAndSettle();
      expect(find.text('ターン 1'), findsOneWidget);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(find.text('ターン 1'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
      await tester.pumpAndSettle();
      expect(find.text('所持品は空'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await tester.pump();
      await tester.tap(find.byKey(const Key('echo-inventory-close')));
      await tester.pumpAndSettle();
      expect(find.text('ターン 1'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await tester.pumpAndSettle();
      expect(find.text('ターン 2'), findsOneWidget);
      final move = tester
          .widget<OutlinedButton>(find.byKey(const Key('echo-move-hall')))
          .onPressed!;
      move();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(const Key('echo-door-transition')), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
      await tester.pump();
      expect(find.byKey(const Key('echo-door-transition')), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
      await tester.pump();
      expect(find.byKey(const Key('echo-door-transition')), findsOneWidget);
      await tester.tap(find.byKey(const Key('echo-door-skip')));
      await tester.pumpAndSettle();
      expect(find.text('ターン 3'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.pump();
      expect(find.text('ターン 3'), findsOneWidget);
      tester.widget<SwitchListTile>(toggle).onChanged!(false);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
      await tester.pump();
      expect(find.text('ターン 3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('typing in an input does not dispatch game commands', (
    tester,
  ) async {
    final input = FocusNode();
    addTearDown(input.dispose);
    final commands = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EchoPumpKeyboardScope(
            enabled: true,
            onCommand: (_, command) {
              commands.add(command);
              return true;
            },
            child: TextField(focusNode: input),
          ),
        ),
      ),
    );
    input.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
    expect(commands, isEmpty);
  });
}
