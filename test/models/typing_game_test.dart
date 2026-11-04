import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/typing_game.dart';

void main() {
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
