import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/typing_game.dart';
import 'package:my_web_app/pages/typing_game_page.dart';

void main() {
  testWidgets('Enter starts; text input rejects paste and IME, accepts letters',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TypingGamePage()));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    final field = find.byKey(const Key('typing-input'));
    expect(field, findsOneWidget);
    final prompt = TypingGame.prompts
        .firstWhere((p) => find.text(p.japanese).evaluate().isNotEmpty);
    await tester.enterText(field, prompt.spellings.first);
    await tester.pump();
    expect(find.text('スコア 0'), findsOneWidget);
    await tester.enterText(field, 'あ');
    await tester.pump();
    expect(find.text('スコア 0'), findsOneWidget);
    // Exercise an uncommitted IME composition through Flutter's editing pipeline.
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'k',
        selection: TextSelection.collapsed(offset: 1),
        composing: TextRange(start: 0, end: 1),
      ),
    );
    await tester.pump();
    expect(find.text('スコア 0'), findsOneWidget);
    expect(tester.widget<TextField>(field).controller!.text, isEmpty);
    await tester.enterText(field, prompt.spellings.first[0]);
    await tester.pump();
    expect(find.text('スコア 10'), findsOneWidget);
    await tester.enterText(field, '');
    await tester.pump();
    expect(find.text('スコア 10'), findsOneWidget);
    final spelling = prompt.spellings.first;
    for (var i = 2; i <= spelling.length; i++) {
      await tester.enterText(field, spelling.substring(0, i));
      await tester.pump();
    }
    expect(find.text('クリア 1問'), findsOneWidget);
    expect(find.text('スコア ${spelling.length * 10 + 50}'), findsOneWidget);
    expect(tester.widget<TextField>(field).controller!.text, isEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow screen and enlarged text remain scrollable',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final english in [false, true]) {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: const TypingGamePage(),
        ),
      );
      if (english) {
        await tester.tap(find.byKey(const Key('typing-language')));
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(find.byKey(const Key('typing-start')));
      await tester.tap(find.byKey(const Key('typing-start')));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byKey(const Key('typing-input')));
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('practice results offer focused review without a challenge best',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TypingGamePage()));
    await tester.tap(find.text('10問じっくり練習'));
    await tester.pump();
    final start = find.byKey(const Key('typing-start'));
    await tester.ensureVisible(start);
    await tester.tap(start);
    await tester.pump();
    expect(find.text('進み具合 0 / 10問'), findsOneWidget);
    final field = find.byKey(const Key('typing-input'));
    final prompt = TypingGame.prompts
        .firstWhere((p) => find.text(p.japanese).evaluate().isNotEmpty);
    await tester.enterText(field, 'q');
    await tester.pump();
    final end = find.text('練習を終える');
    await tester.ensureVisible(end);
    await tester.tap(end);
    await tester.pump();
    expect(find.text('間違えたことばを振り返ろう'), findsOneWidget);
    expect(find.textContaining('ミス 1回'), findsWidgets);
    expect(find.textContaining('入力ペース'), findsOneWidget);
    expect(find.textContaining('この画面でのチャレンジベスト'), findsNothing);
    final review = find.text('苦手なことばを練習');
    await tester.ensureVisible(review);
    await tester.tap(review);
    await tester.pump();
    expect(find.text('苦手なことばを10問練習中'), findsOneWidget);
    for (var word = 0; word < 10; word++) {
      expect(find.text(prompt.japanese), findsOneWidget);
      final spelling = prompt.spellings.first;
      for (var length = 1; length <= spelling.length; length++) {
        await tester.enterText(field, spelling.substring(0, length));
        await tester.pump();
      }
    }
    expect(find.textContaining('10問完走！'), findsOneWidget);
    expect(find.text('進み具合 10 / 10問'), findsOneWidget);
    expect(find.text('苦手なことばを練習'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'English instructions preserve results and localize native controls',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('ja'),
        supportedLocales: [Locale('ja'), Locale('en')],
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: TypingGamePage(),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      MaterialLocalizations.of(tester.element(find.byType(Scaffold)))
          .backButtonTooltip,
      '戻る',
    );
    final language = find.byKey(const Key('typing-language'));
    await tester.tap(language);
    await tester.pumpAndSettle();
    expect(find.text('Kotoba Typing'), findsOneWidget);
    expect(
      MaterialLocalizations.of(tester.element(find.byType(Scaffold)))
          .backButtonTooltip,
      'Back',
    );
    await tester.tap(find.text('10-word practice'));
    await tester.pump();
    final start = find.byKey(const Key('typing-start'));
    await tester.ensureVisible(start);
    await tester.tap(start);
    await tester.pump();
    expect(tester.widget<TextButton>(language).onPressed, isNull);
    final field = find.byKey(const Key('typing-input'));
    await tester.enterText(field, 'q');
    await tester.pump();
    final end = find.text('End practice');
    await tester.ensureVisible(end);
    await tester.tap(end);
    await tester.pump();
    expect(find.text('Words to practise'), findsOneWidget);
    expect(find.text('Score 0'), findsOneWidget);
    expect(tester.widget<TextButton>(language).onPressed, isNotNull);
    await tester.tap(language);
    await tester.pumpAndSettle();
    expect(find.text('ことばのタイピング'), findsOneWidget);
    expect(
      MaterialLocalizations.of(tester.element(find.byType(Scaffold)))
          .backButtonTooltip,
      '戻る',
    );
    expect(find.text('間違えたことばを振り返ろう'), findsOneWidget);
    expect(find.text('スコア 0'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
