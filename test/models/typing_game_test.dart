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
}
