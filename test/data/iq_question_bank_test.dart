import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/data/iq_question_bank.dart';
import 'package:my_web_app/models/iq_test.dart';

void main() {
  group('standardTest 構成', () {
    test('25問 (5領域 × 5問) を返す', () {
      final questions = IqQuestionBank.standardTest();
      expect(questions.length, 25);
      expect(questions.length, IqQuestionBank.totalQuestions);
    });

    test('各領域が同数・同じ難易度構成を持つ', () {
      final questions = IqQuestionBank.standardTest();

      for (final category in IqCategory.values) {
        final items = questions.where((q) => q.category == category).toList();
        expect(
          items.length,
          IqQuestionBank.questionsPerCategory,
          reason: '${category.key} の出題数が揃っていない',
        );

        // 領域間比較が成立するには重み構成が同一である必要がある
        final difficulties = items.map((q) => q.difficulty).toList()..sort();
        expect(
          difficulties,
          [1, 2, 3, 4, 5],
          reason: '${category.key} の難易度構成が 1..5 になっていない',
        );
      }
    });

    test('問題キーが一意', () {
      final questions = IqQuestionBank.standardTest();
      final keys = questions.map((q) => q.key).toSet();
      expect(keys.length, questions.length);
    });

    test('難易度の低い順に並ぶ (序盤に難問が固まらない)', () {
      final questions = IqQuestionBank.standardTest();
      var previous = 0;
      for (final q in questions) {
        expect(q.difficulty, greaterThanOrEqualTo(previous));
        previous = q.difficulty;
      }
    });
  });

  group('問題そのものの整合性', () {
    test('全問が選択肢を持ち、正解インデックスが範囲内', () {
      for (final q in IqQuestionBank.standardTest()) {
        expect(q.options.length, greaterThanOrEqualTo(2), reason: q.key);
        expect(q.correctIndex, greaterThanOrEqualTo(0), reason: q.key);
        expect(q.correctIndex, lessThan(q.options.length), reason: q.key);
      }
    });

    test('選択肢に重複がない (正解が複数存在しない)', () {
      for (final q in IqQuestionBank.standardTest()) {
        expect(
          q.options.toSet().length,
          q.options.length,
          reason: '${q.key} の選択肢が重複している',
        );
      }
    });

    test('全問に空でない問題文と解説がある', () {
      for (final q in IqQuestionBank.standardTest()) {
        expect(q.prompt.trim(), isNotEmpty, reason: q.key);
        expect(q.explanation.trim(), isNotEmpty, reason: q.key);
      }
    });

    test('記憶課題は刺激と提示時間の両方を持つ', () {
      final memory = IqQuestionBank.standardTest()
          .where((q) => q.category == IqCategory.memory);

      expect(memory, isNotEmpty);
      for (final q in memory) {
        expect(q.hasMemoryPhase, isTrue, reason: q.key);
        expect(q.memoryStimulus!.trim(), isNotEmpty, reason: q.key);
        expect(q.revealSeconds, greaterThan(0), reason: q.key);
      }
    });

    test('記憶課題以外は刺激提示フェーズを持たない', () {
      final others = IqQuestionBank.standardTest()
          .where((q) => q.category != IqCategory.memory);

      for (final q in others) {
        expect(q.hasMemoryPhase, isFalse, reason: q.key);
      }
    });
  });

  group('選択肢シャッフル', () {
    test('シャッフルしても正解の中身は変わらない', () {
      final plain = IqQuestionBank.standardTest();
      final shuffled = IqQuestionBank.standardTest(seed: 42);

      expect(shuffled.length, plain.length);
      for (var i = 0; i < plain.length; i++) {
        final original = plain[i];
        final variant = shuffled[i];

        expect(variant.key, original.key);
        expect(
          variant.options[variant.correctIndex],
          original.options[original.correctIndex],
          reason: '${original.key} の正解がシャッフルで入れ替わっている',
        );
        expect(variant.options.toSet(), original.options.toSet());
      }
    });

    test('同じ seed なら同じ並びになる', () {
      final a = IqQuestionBank.standardTest(seed: 7);
      final b = IqQuestionBank.standardTest(seed: 7);
      for (var i = 0; i < a.length; i++) {
        expect(a[i].options, b[i].options);
        expect(a[i].correctIndex, b[i].correctIndex);
      }
    });

    test('多数の seed を通しても正解が保たれる', () {
      final plain = IqQuestionBank.standardTest();
      for (var seed = 0; seed < 50; seed++) {
        final shuffled = IqQuestionBank.standardTest(seed: seed);
        for (var i = 0; i < plain.length; i++) {
          expect(
            shuffled[i].options[shuffled[i].correctIndex],
            plain[i].options[plain[i].correctIndex],
          );
        }
      }
    });

    test('shuffleOptions は正解位置を正しく張り替える', () {
      const question = IqQuestion(
        key: 'x',
        category: IqCategory.logic,
        difficulty: 1,
        prompt: 'p',
        options: ['a', 'b', 'c', 'd'],
        correctIndex: 2,
        explanation: 'e',
      );

      for (var seed = 0; seed < 30; seed++) {
        final shuffled =
            IqQuestionBank.shuffleOptions(question, math.Random(seed));
        expect(shuffled.options[shuffled.correctIndex], 'c');
      }
    });
  });
}
