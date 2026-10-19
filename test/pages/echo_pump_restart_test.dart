import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/echo_pump_game_page.dart';

void main() {
  for (final width in [360.0, 1200.0]) {
    testWidgets('restart cancellation preserves collected fuse at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: EchoPumpGamePage()));

      Future<void> tap(String key) async {
        final target = find.byKey(Key(key));
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        await tester.tap(target);
        await tester.pumpAndSettle();
      }

      await tester.tap(find.byKey(const Key('echo-start')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('echo-intro-skip')));
      await tester.pumpAndSettle();
      await tap('echo-power-b');
      await tap('echo-power-a');
      await tap('echo-move-hall');
      await tap('echo-move-workshop');
      await tap('echo-collect');
      expect(find.text('ターン 5'), findsOneWidget);
      tester.widget<SwitchListTile>(find.byKey(const Key('echo-keyboard-toggle')))
          .onChanged!(true);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('最初からやり直す'));
      await tester.pumpAndSettle();
      expect(find.text('最初からやり直しますか？'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('echo-inventory-close')), findsNothing);
      await tap('echo-restart-cancel');
      expect(find.text('ターン 5'), findsOneWidget);
      await tap('echo-inventory-toolbar');
      expect(find.text('所持数 1'), findsOneWidget);
      await tap('echo-inventory-close');

      await tester.tap(find.byTooltip('最初からやり直す'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('ターン 5'), findsOneWidget);
      await tester.tap(find.byTooltip('最初からやり直す'));
      await tester.pumpAndSettle();
      await tap('echo-restart-confirm');
      expect(find.text('ターン 0'), findsOneWidget);
      expect(find.text('体力 3 / 3'), findsOneWidget);
      await tap('echo-inventory-toolbar');
      expect(find.text('所持品は空'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('restart dialog allows large text at $width', (tester) async {
      tester.view.physicalSize = Size(width, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: const EchoPumpGamePage(),
        ),
      );
      final start = find.byKey(const Key('echo-start'));
      await tester.ensureVisible(start);
      await tester.pumpAndSettle();
      await tester.tap(start);
      await tester.pump();
      await tester.tap(find.byKey(const Key('echo-intro-skip')));
      await tester.pumpAndSettle();
      tester.widget<OutlinedButton>(find.byKey(const Key('echo-wait')))
          .onPressed!();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('最初からやり直す'));
      await tester.pumpAndSettle();
      expect(find.text('最初からやり直しますか？'), findsOneWidget);
      final cancel = find.byKey(const Key('echo-restart-cancel'));
      await tester.ensureVisible(cancel);
      await tester.pumpAndSettle();
      await tester.tap(cancel);
      await tester.pumpAndSettle();
      expect(find.text('ターン 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
