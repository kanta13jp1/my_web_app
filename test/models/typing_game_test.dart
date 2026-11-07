import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/typing_game.dart';

void main() {
  TypingGame focused(TypingPrompt prompt) => TypingGame(random: Random(7))
    ..start(mode: TypingMode.practice, practicePrompts: [prompt]);

  test('every curated prefix accepts exactly its valid next letters', () {
    var cases = 0;
    for (final prompt in TypingGame.prompts) {
      final prefixes = <String>{
        for (final spelling in prompt.spellings)
          for (var i = 0; i < spelling.length; i++) spelling.substring(0, i),
      };
      for (final prefix in prefixes) {
        for (var key = 0; key < 26; key++) {
          final letter = String.fromCharCode(97 + key);
          final next = prefix + letter;
          final accepted = prompt.spellings.any((s) => s.startsWith(next));
          final game = focused(prompt);
          for (final character in prefix.split('')) {
            expect(game.type(character), isTrue);
          }
          expect(game.guide.startsWith(prefix), isTrue);
          expect(
            game.type(letter.toUpperCase()),
            accepted,
            reason: '${prompt.japanese}: $next',
          );
          cases++;
          if (accepted) {
            final complete = prompt.spellings.contains(next);
            expect(game.words, complete ? 1 : 0);
            expect(game.score, next.length * 10 + (complete ? 50 : 0));
            expect(game.prefix, complete ? '' : next);
            expect(game.guide.startsWith(game.prefix), isTrue);
          } else {
            expect(game.prefix, prefix);
            expect(game.mistakes, 1);
            expect(game.score, prefix.length * 10);
            // A wrong key never traps a valid prefix or changes the guide.
            final remaining = game.guide.substring(prefix.length);
            for (final character in remaining.split('')) {
              expect(game.type(character), isTrue);
            }
            expect(game.words, 1);
            expect(game.prefix, isEmpty);
            expect(game.mistakes, 1);
          }
        }
      }
    }
    expect(cases, greaterThan(7000));
  });

  test('all four bicycle combinations score 130 and update the guide', () {
    final bicycle = TypingGame.prompts.singleWhere((p) => p.japanese == '自転車');
    expect(bicycle.spellings, ['jitensha', 'zitensya', 'jitensya', 'zitensha']);
    for (final spelling in bicycle.spellings) {
      final game = focused(bicycle);
      for (var i = 0; i < spelling.length; i++) {
        expect(game.type(spelling[i]), isTrue);
        if (i < spelling.length - 1) {
          expect(game.guide.startsWith(spelling.substring(0, i + 1)), isTrue);
        }
      }
      expect(game.correct, 8);
      expect(game.words, 1);
      expect(game.score, 130);
      expect(game.mistakes, 0);
    }
  });

  test('nonletter edits and existing nasal/double-consonant rules stay intact',
      () {
    final bicycle = TypingGame.prompts.singleWhere((p) => p.japanese == '自転車');
    final game = focused(bicycle);
    for (final invalid in ['', 'ji', '1', ' ', '-', 'じ', '🍣']) {
      expect(game.type(invalid), isFalse);
      expect(game.prefix, isEmpty);
      expect(game.mistakes, 0);
      expect(game.score, 0);
    }
    expect(
      TypingGame.prompts.singleWhere((p) => p.japanese == 'こんにちは').spellings,
      ['konnichiwa', 'konnitiwa'],
    );
    expect(
      TypingGame.prompts.singleWhere((p) => p.japanese == '一緒に').spellings,
      ['isshoni', 'issyoni'],
    );
    for (final example in {'こんにちは': 'koni', '一緒に': 'isho'}.entries) {
      final target = TypingGame.prompts.singleWhere(
        (p) => p.japanese == example.key,
      );
      final run = focused(target);
      for (var i = 0; i < example.value.length - 1; i++) {
        expect(run.type(example.value[i]), isTrue);
      }
      expect(run.type(example.value[example.value.length - 1]), isFalse);
      expect(run.mistakes, 1);
    }
  });

  void completeWord(TypingGame game) {
    for (final letter in game.guide.split('')) {
      expect(game.type(letter), isTrue);
    }
  }

  test('36 consecutive restarts expose each prompt before repeating', () {
    final game = TypingGame(random: Random(12));
    final seen = <TypingPrompt>{};
    for (var i = 0; i < TypingGame.prompts.length; i++) {
      game.start();
      expect(seen.add(game.prompt), isTrue);
    }
    final previous = game.prompt;
    game.start();
    expect(game.prompt, isNot(previous));
  });

  test('three ten-word practices do not repeat across retries', () {
    final game = TypingGame(random: Random(15));
    final seen = <TypingPrompt>{};
    for (var run = 0; run < 3; run++) {
      game.start(mode: TypingMode.practice);
      for (var i = 0; i < TypingGame.practiceTarget; i++) {
        expect(seen.add(game.prompt), isTrue);
        completeWord(game);
      }
      expect(game.finished, isTrue);
    }
    expect(seen.length, 30);
  });

  test('focused exposure is remembered on return to the full corpus', () {
    final game = TypingGame(random: Random(19));
    final focused = TypingGame.prompts.first;
    game.start(mode: TypingMode.practice, practicePrompts: [focused]);
    for (var i = 0; i < TypingGame.practiceTarget; i++) {
      expect(game.prompt, focused);
      completeWord(game);
    }
    final seen = <TypingPrompt>{};
    for (var i = 0; i < TypingGame.prompts.length - 1; i++) {
      game.start(mode: i.isEven ? TypingMode.practice : TypingMode.challenge);
      expect(game.prompt, isNot(focused));
      expect(seen.add(game.prompt), isTrue);
    }
    game.start();
    expect(game.prompt, focused);
  });

  test('all curated spellings complete their Japanese prompt', () {
    for (final target in TypingGame.prompts) {
      for (final spelling in target.spellings) {
        final game = TypingGame(random: Random(3))..start();
        while (game.prompt != target) {
          for (final letter in game.guide.split('')) {
            game.type(letter);
          }
        }
        final before = game.words;
        for (final letter in spelling.split('')) {
          expect(game.type(letter.toUpperCase()), isTrue);
        }
        expect(game.words, before + 1);
        expect(game.prefix, isEmpty);
      }
    }
  });

  test('mistakes preserve progress and reset combo, with accurate scoring', () {
    final game = TypingGame(random: Random(1))..start();
    final first = game.guide[0];
    expect(game.type(first), isTrue);
    expect(game.type('z'), isFalse);
    expect(game.prefix, first);
    expect(game.combo, 0);
    expect(game.correct, 1);
    expect(game.mistakes, 1);
    expect(game.accuracy, 50);
    expect(game.score, 10);
    expect(game.type('日本語'), isFalse);
    expect(game.mistakes, 1);
  });

  test('deadline rejects input and retry resets the entire run', () {
    final game = TypingGame()..start();
    for (final letter in game.guide.split('')) {
      game.type(letter);
    }
    expect(game.score, game.correct * 10 + 50);
    game.updateElapsed(const Duration(seconds: 61));
    expect(game.finished, isTrue);
    expect(game.remaining, Duration.zero);
    final score = game.score;
    expect(game.type('a'), isFalse);
    expect(game.score, score);
    game.start();
    expect(game.running, isTrue);
    expect(game.finished, isFalse);
    expect(game.score, 0);
    expect(game.words, 0);
    expect(game.correct, 0);
    expect(game.mistakes, 0);
    expect(game.remaining, TypingGame.duration);
    expect(game.accuracy, 100);
  });

  test('practice has no deadline and finishes on exactly ten words', () {
    final game = TypingGame(random: Random(9))
      ..start(mode: TypingMode.practice);
    game.updateElapsed(const Duration(minutes: 4));
    expect(game.running, isTrue);
    expect(game.elapsed, const Duration(minutes: 4));
    for (var word = 0; word < TypingGame.practiceTarget; word++) {
      for (final letter in game.guide.split('')) {
        expect(game.type(letter), isTrue);
      }
    }
    expect(game.words, 10);
    expect(game.finished, isTrue);
    expect(game.running, isFalse);
    expect(game.type('a'), isFalse);
    expect(game.correctPerMinute, closeTo(game.correct / 4, 0.001));
  });

  test('review includes unfinished words and can become focused practice', () {
    final game = TypingGame(random: Random(4))..start();
    final missed = game.prompt;
    game.type('q');
    game.type('q');
    game.updateElapsed(TypingGame.duration);
    expect(game.words, 0);
    expect(game.review.single.prompt, missed);
    expect(game.review.single.count, 2);
    final targets = game.review.map((item) => item.prompt).toList();
    game.start(mode: TypingMode.practice, practicePrompts: targets);
    expect(game.review, isEmpty);
    expect(game.mistakes, 0);
    for (var i = 0; i < 10; i++) {
      expect(game.prompt, missed);
      for (final letter in game.guide.split('')) {
        game.type(letter);
      }
    }
    expect(game.finished, isTrue);
    expect(game.words, 10);
  });

  test('practice can end early and pace uses only actual elapsed time', () {
    final game = TypingGame()
      ..start(
        mode: TypingMode.practice,
        practicePrompts: [TypingGame.prompts[0]],
      );
    game.type('s');
    game.updateElapsed(const Duration(seconds: 2));
    game.updateElapsed(const Duration(seconds: 1));
    game.finishPractice();
    expect(game.words, 0);
    expect(game.elapsed, const Duration(seconds: 2));
    expect(game.correctPerMinute, 30);
    expect(game.finished, isTrue);
    game.updateElapsed(const Duration(minutes: 10));
    expect(game.correctPerMinute, 30);
    game.start();
    expect(game.correctPerMinute, 0);
    expect(game.review, isEmpty);
    game.finishPractice();
    expect(game.running, isTrue);
    game.updateElapsed(const Duration(seconds: 80));
    expect(game.elapsed, TypingGame.duration);
  });

  test('deck has no repeated word within a round or at its boundary', () {
    final game = TypingGame(random: Random(2))..start();
    final seen = <TypingPrompt>{};
    TypingPrompt? previous;
    for (var i = 0; i < TypingGame.prompts.length; i++) {
      expect(seen.add(game.prompt), isTrue);
      previous = game.prompt;
      for (final letter in game.guide.split('')) {
        game.type(letter);
      }
    }
    expect(game.prompt, isNot(previous));
  });

  test('focused prompts cannot alter the challenge or start an empty run', () {
    final game = TypingGame()..start();
    expect(
      () => game.start(practicePrompts: [TypingGame.prompts[0]]),
      throwsArgumentError,
    );
    expect(
      () => game.start(mode: TypingMode.practice, practicePrompts: []),
      throwsArgumentError,
    );
    expect(game.mode, TypingMode.challenge);
    expect(game.running, isTrue);
  });
}
