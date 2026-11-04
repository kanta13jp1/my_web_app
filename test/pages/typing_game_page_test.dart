import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/typing_game.dart';
import 'package:my_web_app/pages/typing_game_page.dart';

void main() {
  testWidgets('Enter starts; text input rejects paste and IME, accepts letters', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TypingGamePage()));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    final field = find.byKey(const Key('typing-input'));
    expect(field, findsOneWidget);
    final prompt = TypingGame.prompts.firstWhere((p) => find.text(p.japanese).evaluate().isNotEmpty);
    await tester.enterText(field, prompt.spellings.first);
    await tester.pump();
    expect(find.text('スコア 0'), findsOneWidget);
    await tester.enterText(field, 'あ');
    await tester.pump();
    expect(find.text('スコア 0'), findsOneWidget);
    await tester.enterText(field, prompt.spellings.first[0]);
    await tester.pump();
    expect(find.text('スコア 10'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow screen and enlarged text remain scrollable', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.5)),
        child: child!,
      ),
      home: const TypingGamePage(),
    ));
    await tester.tap(find.byKey(const Key('typing-start')));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byKey(const Key('typing-input')));
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
