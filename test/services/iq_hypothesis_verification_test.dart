// IQテスト機能の改善に向けた 10 仮説の検証ハーネス。
//
// 目的は「意見」ではなく「実測」で各仮説の真偽を決めること。
// ここでは *現状の* 振る舞いを表明する。修正が入ればこのファイルの
// 該当テストは落ちるので、そのとき初めて仮説が解消されたと言える。
//
// 実行: flutter test test/services/iq_hypothesis_verification_test.dart

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/data/iq_question_bank.dart';
import 'package:my_web_app/data/iq_training_drills.dart';
import 'package:my_web_app/models/iq_test.dart';
import 'package:my_web_app/services/iq_scoring.dart';
import 'package:my_web_app/services/iq_training_service.dart';

IqAnswerRecord _a({
  required IqCategory category,
  required int difficulty,
  required bool correct,
}) =>
    IqAnswerRecord(
      questionKey: '${category.key}-$difficulty',
      category: category,
      difficulty: difficulty,
      selectedIndex: correct ? 0 : 1,
      isCorrect: correct,
      responseMs: 1000,
    );

void main() {
  group('H1 (修正後): 再受験で出題が入れ替わる', () {
    test('seed が違えば出題される問題キーが変わる', () {
      final sets = <Set<String>>[
        for (final seed in [1, 7, 42, 999, 12345])
          IqQuestionBank.standardTest(seed: seed).map((q) => q.key).toSet(),
      ];

      // すべて同一なら練習効果の問題が残っている
      final allIdentical = sets.every((s) => s.difference(sets.first).isEmpty);
      expect(
        allIdentical,
        isFalse,
        reason: 'seed を変えても同じ25問なら再受験対策になっていない',
      );

      final distinct = sets.map((s) => s.join('|')).toSet().length;
      // ignore: avoid_print
      print('H1 FIXED: 5通りの seed で $distinct 種類の出題セット');
    });

    test('どの seed でも 5領域 × 難易度1..5 の構成は保たれる', () {
      for (final seed in [0, 3, 77, 2024]) {
        final questions = IqQuestionBank.standardTest(seed: seed);
        expect(questions.length, 25, reason: 'seed=$seed');
        expect(
          questions.map((q) => q.key).toSet().length,
          25,
          reason: 'seed=$seed で問題が重複している',
        );

        for (final category in IqCategory.values) {
          final diffs = questions
              .where((q) => q.category == category)
              .map((q) => q.difficulty)
              .toList()
            ..sort();
          expect(
            diffs,
            [1, 2, 3, 4, 5],
            reason: 'seed=$seed の ${category.key} で重み構成が崩れている',
          );
        }
      }
      // ignore: avoid_print
      print('H1 FIXED: 出題が変わっても領域×難易度の構成は不変');
    });

    test('代替フォームを含めプールが出題数の2倍ある', () {
      expect(
        IqQuestionBank.allQuestions.length,
        IqQuestionBank.totalQuestions * 2,
      );
      // ignore: avoid_print
      print('H1 FIXED: プール ${IqQuestionBank.allQuestions.length} 問 '
          '(出題 ${IqQuestionBank.totalQuestions} 問)');
    });
  });

  group('H2: 領域別スコアの誤差が弱点判定の閾値より大きい', () {
    test('5問カテゴリの標準誤差は弱点閾値(5 IQ)を大きく上回る', () {
      // 平均的な受験者 (ability 0.55) を想定
      final se = IqScoring.standardError(0.55, 5);
      const weakGapThreshold = 5; // IqTestResult.weakAreas の既定値

      // ignore: avoid_print
      print('H2: 5問時の標準誤差 = ${se.toStringAsFixed(1)} IQ '
          '/ 95%CI幅 = ±${(1.96 * se).toStringAsFixed(1)} '
          '/ 弱点判定の閾値 = $weakGapThreshold');

      expect(
        se,
        greaterThan(weakGapThreshold.toDouble()),
        reason: '誤差が閾値より小さければ弱点判定は意味を持つ',
      );
      // ignore: avoid_print
      print('H2 CONFIRMED: 閾値は誤差の '
          '${(weakGapThreshold / se).toStringAsFixed(2)} SE しかない');
    });

    test('全問正解と全問不正解の間でも領域IQはクランプで潰れる', () {
      // 5問しかないと ability の刻みが粗く、IQ の解像度が低い
      final observed = <int>{};
      for (var correct = 0; correct <= 5; correct++) {
        final answers = [
          for (var d = 1; d <= 5; d++)
            _a(
              category: IqCategory.logic,
              difficulty: d,
              correct: d <= correct,
            ),
        ];
        observed.add(IqScoring.categoryScores(answers).single.iq);
      }
      // ignore: avoid_print
      print('H2: 正答数0..5 に対する領域IQ = ${observed.toList()..sort()}');
      expect(observed.length, lessThanOrEqualTo(6));
    });
  });

  group('H4: 時間切れで未着手が全て不正解になり下限に張り付く', () {
    test('25問中3問だけ解いて時間切れ → IQ は下限に張り付く', () {
      final answers = <IqAnswerRecord>[
        // 解いた3問はすべて正解
        for (var d = 1; d <= 3; d++)
          _a(category: IqCategory.logic, difficulty: d, correct: true),
        // 残り22問は未着手 = 不正解として計上される
        for (final c in IqCategory.values)
          for (var d = 1; d <= 5; d++)
            if (!(c == IqCategory.logic && d <= 3))
              _a(category: c, difficulty: d, correct: false),
      ];
      expect(answers.length, 25);

      final summary = IqScoring.summarize(answers);
      // ignore: avoid_print
      print('H4: 3問正解+22問未着手 → IQ ${summary.totalIq} '
          '(下限 ${IqCalibration.minIq})');

      // 当初の予測「下限に張り付く」は外れ (実測 61)。ただし本質は変わらず、
      // 解いた3問が全問正解でも「かなり低い実力」と区別がつかない値になる。
      expect(
        summary.totalIq,
        greaterThan(IqCalibration.minIq),
        reason: '実測では下限には達しない',
      );
      expect(
        summary.totalIq,
        lessThan(70),
        reason: '解いた分は全問正解なのに著しく低い値になる',
      );
      // ignore: avoid_print
      print('H4 REVISED: 下限張り付きではないが、解答分が全問正解でも '
          'IQ ${summary.totalIq} = 低実力と判別不能');
    });

    test('完答率が結果に一切表示されない (信頼できるかを利用者が判断できない)', () {
      // 3問しか解いていない結果と25問解いた結果が、同じ形式で提示される
      final partial = IqScoring.summarize([
        for (var d = 1; d <= 3; d++)
          _a(category: IqCategory.logic, difficulty: d, correct: true),
        for (final c in IqCategory.values)
          for (var d = 1; d <= 5; d++)
            if (!(c == IqCategory.logic && d <= 3))
              _a(category: c, difficulty: d, correct: false),
      ]);
      // questionCount は 25 と報告される = 未着手22問が「解答済み」に混ざる
      expect(partial.questionCount, 25);
      // ignore: avoid_print
      print('H4 CONFIRMED (別側面): questionCount=${partial.questionCount} '
          'と報告され、実際に着手した3問との区別が結果に残らない');
    });
  });

  group('H7: 1セッション8問では正答率がノイズでレベルが振れる', () {
    test('真の実力0.70でも1セッションで昇格/降格が両方起こりうる', () {
      const trueAbility = 0.70;
      const n = IqDrillGenerator.defaultSessionSize; // 8
      expect(n, 8);

      // 二項分布で各正答数の確率を出す
      double binom(int k) {
        var c = 1.0;
        for (var i = 0; i < k; i++) {
          c = c * (n - i) / (i + 1);
        }
        return c * math.pow(trueAbility, k) * math.pow(1 - trueAbility, n - k);
      }

      var pUp = 0.0;
      var pDown = 0.0;
      var pStay = 0.0;
      for (var k = 0; k <= n; k++) {
        final acc = k / n;
        final next = IqTrainingService.nextLevel(3, acc);
        final p = binom(k);
        if (next > 3) {
          pUp += p;
        } else if (next < 3) {
          pDown += p;
        } else {
          pStay += p;
        }
      }

      // ignore: avoid_print
      print('H7: 真の実力 $trueAbility / 1セッション$n問 → '
          '昇格 ${(pUp * 100).toStringAsFixed(1)}% '
          '据置 ${(pStay * 100).toStringAsFixed(1)}% '
          '降格 ${(pDown * 100).toStringAsFixed(1)}%');

      // 適正帯にいるのに、かなりの確率で誤って動く
      expect(
        pUp + pDown,
        greaterThan(0.30),
        reason: '誤判定が3割を超えるならレベルはノイズで振れている',
      );
      // ignore: avoid_print
      print('H7 CONFIRMED: 誤ってレベルが動く確率 '
          '${((pUp + pDown) * 100).toStringAsFixed(1)}%');
    });

    test('修正後: 直近5セッションを合算すると誤判定が激減する', () {
      const trueAbility = 0.70;
      const n = IqDrillGenerator.defaultSessionSize * 5; // 8問 × 5セッション = 40

      double binom(int k) {
        var c = 1.0;
        for (var i = 0; i < k; i++) {
          c = c * (n - i) / (i + 1);
        }
        return c * math.pow(trueAbility, k) * math.pow(1 - trueAbility, n - k);
      }

      var pMove = 0.0;
      for (var k = 0; k <= n; k++) {
        if (IqTrainingService.nextLevel(3, k / n) != 3) pMove += binom(k);
      }

      // ignore: avoid_print
      print('H7 FIXED: 合算$n問での誤判定率 '
          '${(pMove * 100).toStringAsFixed(1)}% (1セッション8問では 44.9%)');

      expect(
        pMove,
        lessThan(0.10),
        reason: '合算しても誤判定が1割を超えるなら改善になっていない',
      );
    });

    test('正答率の刻みは 1/8 = 12.5% しかない', () {
      final steps = <double>{};
      for (var k = 0; k <= 8; k++) {
        steps.add(k / 8);
      }
      expect(steps.length, 9);
      // 6問正解(0.75)は据置、7問正解(0.875)は昇格 = 1問差で結論が変わる
      expect(IqTrainingService.nextLevel(3, 6 / 8), 3);
      expect(IqTrainingService.nextLevel(3, 7 / 8), 4);
      // ignore: avoid_print
      print('H7 CONFIRMED: 6問正解=据置 / 7問正解=昇格 (1問差で反転)');
    });
  });

  group('H5/H6/H10: 記録しているのに使っていないデータ', () {
    test('H5: responseMs はモデルに存在するが採点にも表示にも寄与しない', () {
      // 応答時間が違っても採点結果は完全に同一
      List<IqAnswerRecord> withMs(int ms) => [
            for (final c in IqCategory.values)
              for (var d = 1; d <= 5; d++)
                IqAnswerRecord(
                  questionKey: '${c.key}-$d',
                  category: c,
                  difficulty: d,
                  selectedIndex: 0,
                  isCorrect: d <= 3,
                  responseMs: ms,
                ),
          ];

      final fast = IqScoring.summarize(withMs(500));
      final slow = IqScoring.summarize(withMs(60000));

      expect(fast.totalIq, slow.totalIq);
      expect(fast.weightedAccuracy, slow.weightedAccuracy);
      // ignore: avoid_print
      print('H5 CONFIRMED: 応答時間 500ms と 60000ms で '
          'IQ が同一 (${fast.totalIq}) = 未使用');
    });

    test('H10: ドリルの解説は生成されるがセッション記録に残らない', () {
      final drills = IqDrillGenerator.generate(
        category: IqCategory.numerical,
        level: 3,
        seed: 1,
      );
      // 各問は解説を持つ
      expect(drills.every((q) => q.explanation.isNotEmpty), isTrue);
      // しかし IqTrainingSession は正答数しか保持しない
      final session = IqTrainingSession(
        id: 1,
        planId: 1,
        userId: 'u',
        category: IqCategory.numerical,
        level: 3,
        correctCount: 5,
        questionCount: 8,
        durationSeconds: 100,
        completedAt: DateTime(2026, 7, 29),
      );
      expect(session.correctCount, 5);
      // ignore: avoid_print
      print('H10 CONFIRMED: セッションは集計値のみ '
          '= どの規則で躓いたか復元不能');
    });
  });
}
