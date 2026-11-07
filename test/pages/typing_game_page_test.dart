import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/typing_game.dart';
import 'package:my_web_app/pages/typing_game_page.dart';

void main() {

  testWidgets('mixed bicycle spellings work with hints off and on', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TypingGamePage()));
    await tester.tap(find.text('10問じっくり練習'));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('typing-start')));
    await tester.tap(find.byKey(const Key('typing-start')));
    await tester.pump();
    final field = find.byKey(const Key('typing-input'));
    // Collect bicycle in the page's focused review, without injected prompt state.
    var found = false;
    for (var i = 0; i < 36; i++) {
      final prompt = TypingGame.prompts.firstWhere(
        (p) => find.text(p.japanese).evaluate().isNotEmpty,
      );
      if (prompt.japanese == '自転車') {
        found = true;
        break;
      }
      await tester.ensureVisible(find.text('練習を終える'));
      await tester.tap(find.text('練習を終える'));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('typing-start')));
      await tester.tap(find.byKey(const Key('typing-start')));
      await tester.pump();
    }
    expect(found, isTrue);
    await tester.enterText(field, 'q');
    await tester.pump();
    await tester.ensureVisible(find.text('練習を終える'));
    await tester.tap(find.text('練習を終える'));
    await tester.pump();
    await tester.ensureVisible(find.text('苦手なことばを練習'));
    await tester.tap(find.text('苦手なことばを練習'));
    await tester.pump();
    final hint = find.byKey(const Key('typing-romaji-hint'));
    for (final showHint in [false, true]) {
      if (tester.widget<FilterChip>(hint).selected != showHint) {
        await tester.ensureVisible(hint);
        await tester.tap(hint);
        await tester.pump();
      }
      for (final spelling in ['jitensha', 'zitensya', 'jitensya', 'zitensha']) {
        final before = tester.widget<TextField>(field).controller!.text;
        expect(before, isEmpty);
        for (var i = 1; i <= spelling.length; i++) {
          await tester.enterText(field, spelling.substring(0, i));
          await tester.pump();
          if (showHint && i < spelling.length) {
            final guide = tester.widget<Text>(find.byKey(const Key('typing-romaji-guide')));
            expect(guide.textSpan!.toPlainText().startsWith(spelling.substring(0, i)), isTrue);
          } else if (!showHint) {
            expect(find.byKey(const Key('typing-romaji-guide')), findsNothing);
          }
        }
      }
    }
    expect(find.text('クリア 8問'), findsOneWidget);
    expect(find.text('スコア 1040'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('hint choices survive play, retry and mode changes',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TypingGamePage()));
    final reading = find.byKey(const Key('typing-reading-hint'));
    final romaji = find.byKey(const Key('typing-romaji-hint'));
    for (final hint in [reading, romaji]) {
      expect(tester.widget<FilterChip>(hint).selected, isTrue);
      await tester.ensureVisible(hint);
      await tester.tap(hint);
      await tester.pump();
    }
    await tester.tap(find.text('10問じっくり練習'));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('typing-start')));
    await tester.tap(find.byKey(const Key('typing-start')));
    await tester.pump();
    expect(find.byKey(const Key('typing-reading')), findsNothing);
    expect(find.byKey(const Key('typing-romaji-guide')), findsNothing);
    expect(find.textContaining('使えるつづり:'), findsNothing);
    final prompt = TypingGame.prompts.firstWhere(
      (p) => find.text(p.japanese).evaluate().isNotEmpty,
    );
    final field = find.byKey(const Key('typing-input'));
    await tester.enterText(field, prompt.spellings.first[0]);
    await tester.pump();
    expect(find.text('スコア 10'), findsOneWidget);
    await tester.ensureVisible(romaji);
    await tester.tap(romaji);
    await tester.pump();
    expect(find.byKey(const Key('typing-romaji-guide')), findsOneWidget);
    expect(find.byKey(const Key('typing-reading')), findsNothing);
    expect(tester.widget<TextField>(field).focusNode!.hasFocus, isTrue);
    expect(
      tester.widget<TextField>(field).controller!.text,
      prompt.spellings.first[0],
    );
    expect(find.text('スコア 10'), findsOneWidget);
    await tester.ensureVisible(find.text('練習を終える'));
    await tester.tap(find.text('練習を終える'));
    await tester.pump();
    await tester.ensureVisible(find.text('60秒チャレンジ'));
    await tester.tap(find.text('60秒チャレンジ'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('typing-language')));
    await tester.pump();
    expect(find.text('Show reading'), findsOneWidget);
    expect(tester.widget<FilterChip>(reading).selected, isFalse);
    expect(tester.widget<FilterChip>(romaji).selected, isTrue);
    await tester.ensureVisible(find.byKey(const Key('typing-start')));
    await tester.tap(find.byKey(const Key('typing-start')));
    await tester.pump();
    expect(find.byKey(const Key('typing-reading')), findsNothing);
    expect(find.byKey(const Key('typing-romaji-guide')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Enter starts; paste and kana are rejected, letters are accepted',
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
    expect(tester.widget<TextField>(field).controller!.text, 'k');
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
      expect(
        tester.widget<Text>(find.byKey(const Key('typing-prompt'))).data,
        prompt.japanese,
      );
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

  testWidgets(
      'composition stays untouched and commits only once, with a separator',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TypingGamePage()));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    final field = find.byKey(const Key('typing-input'));
    expect(
      tester.widget<TextField>(field).focusNode!.hasFocus,
      isTrue,
    );
    final prompt = TypingGame.prompts
        .firstWhere((p) => find.text(p.japanese).evaluate().isNotEmpty);
    final spelling = prompt.spellings.first;
    final candidate = TextEditingValue(
      text: spelling,
      selection: TextSelection.collapsed(offset: spelling.length),
      composing: TextRange(start: 0, end: spelling.length),
    );
    tester.testTextInput.updateEditingValue(candidate);
    await tester.pump();
    expect(
      tester.widget<TextField>(field).controller!.value,
      candidate,
    );
    expect(
      find.text('スコア 0'),
      findsOneWidget,
    );
    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: '$spelling ',
        selection: TextSelection.collapsed(offset: spelling.length + 1),
      ),
    );
    await tester.pump();
    expect(
      find.text('クリア 1問'),
      findsOneWidget,
    );
    expect(
      find.text('スコア ${spelling.length * 10 + 50}'),
      findsOneWidget,
    );
    expect(
      tester.widget<TextField>(field).controller!.text,
      isEmpty,
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(
      tester.widget<TextField>(field).focusNode!.hasFocus,
      isTrue,
    );
    await tester.enterText(field, spelling);
    await tester.pump();
    expect(
      find.text('クリア 1問'),
      findsOneWidget,
    );
    expect(
      tester.takeException(),
      isNull,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'cancelled or kana composition does not score or erase valid progress',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TypingGamePage()));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    final field = find.byKey(const Key('typing-input'));
    final prompt = TypingGame.prompts
        .firstWhere((p) => find.text(p.japanese).evaluate().isNotEmpty);
    final letter = prompt.spellings.first[0];
    await tester.enterText(field, letter);
    await tester.pump();
    final composing = TextEditingValue(
      text: '$letterあ',
      selection: const TextSelection.collapsed(offset: 2),
      composing: const TextRange(start: 1, end: 2),
    );
    tester.testTextInput.updateEditingValue(composing);
    await tester.pump();
    expect(
      tester.widget<TextField>(field).controller!.value,
      composing,
    );
    expect(
      find.text('スコア 10'),
      findsOneWidget,
    );
    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: letter,
        selection: const TextSelection.collapsed(offset: 1),
      ),
    );
    await tester.pump();
    expect(
      tester.widget<TextField>(field).controller!.text,
      letter,
    );
    tester.testTextInput.updateEditingValue(composing);
    await tester.pump();
    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: '$letterあ',
        selection: const TextSelection.collapsed(offset: 2),
      ),
    );
    await tester.pump();
    expect(
      tester.widget<TextField>(field).controller!.text,
      letter,
    );
    expect(
      find.text('スコア 10'),
      findsOneWidget,
    );
    expect(
      find.text('正確さ 100.0%'),
      findsOneWidget,
    );
    expect(
      tester.takeException(),
      isNull,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('one confirmed candidate cannot span prompts', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TypingGamePage()));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    final field = find.byKey(const Key('typing-input'));
    TypingPrompt currentPrompt() => TypingGame.prompts
        .firstWhere((p) => find.text(p.japanese).evaluate().isNotEmpty);
    var prompt = currentPrompt();
    var words = 0;
    var score = 0;
    // Walk one shuffled round to reach an explicit short/long spelling pair.
    while (prompt.spellings.map((s) => s.length).toSet().length == 1) {
      final spelling = prompt.spellings.first;
      for (var length = 1; length <= spelling.length; length++) {
        await tester.enterText(field, spelling.substring(0, length));
        await tester.pump();
      }
      words++;
      score += spelling.length * 10 + 50;
      expect(
        words,
        lessThan(TypingGame.prompts.length),
      );
      prompt = currentPrompt();
    }
    final variants = [...prompt.spellings]
      ..sort((a, b) => a.length.compareTo(b.length));
    final invalid = '${variants.first}q';
    expect(
      invalid.length,
      lessThanOrEqualTo(variants.last.length),
    );
    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: invalid,
        selection: TextSelection.collapsed(offset: invalid.length),
        composing: TextRange(start: 0, end: invalid.length),
      ),
    );
    await tester.pump();
    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: invalid,
        selection: TextSelection.collapsed(offset: invalid.length),
      ),
    );
    await tester.pump();
    expect(
      find.text('クリア $words問'),
      findsOneWidget,
    );
    expect(
      find.text('スコア $score'),
      findsOneWidget,
    );
    expect(
      tester.widget<TextField>(field).controller!.text,
      isEmpty,
    );
    expect(
      tester.takeException(),
      isNull,
    );
    await tester.pumpWidget(const SizedBox());
  });
}
