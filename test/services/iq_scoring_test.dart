import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/iq_test.dart';
import 'package:my_web_app/services/iq_scoring.dart';

IqAnswerRecord _answer({
  required IqCategory category,
  required int difficulty,
  required bool isCorrect,
  String? key,
}) {
  return IqAnswerRecord(
    questionKey: key ?? '${category.key}-$difficulty',
    category: category,
    difficulty: difficulty,
    selectedIndex: isCorrect ? 0 : 1,
    isCorrect: isCorrect,
    responseMs: 1000,
  );
}

/// 5領域 × 難易度1..5 の完全な回答セットを作る。
List<IqAnswerRecord> _fullSet({
  required bool Function(IqCategory, int) correct,
}) {
  return [
    for (final category in IqCategory.values)
      for (var d = 1; d <= 5; d++)
        _answer(
          category: category,
          difficulty: d,
          isCorrect: correct(category, d),
        ),
  ];
}

void main() {
  group('weightedAccuracy', () {
    test('回答が無ければ 0', () {
      expect(IqScoring.weightedAccuracy([]), 0);
    });

    test('全問正解で 1.0', () {
      final answers = _fullSet(correct: (_, __) => true);
      expect(IqScoring.weightedAccuracy(answers), 1.0);
    });

    test('全問不正解で 0.0', () {
      final answers = _fullSet(correct: (_, __) => false);
      expect(IqScoring.weightedAccuracy(answers), 0.0);
    });

    test('難しい問題の正解のほうが重い', () {
      // 難易度5だけ正解 (重み 5 / 合計 1+2+3+4+5 = 15)
      final hardOnly = [
        for (var d = 1; d <= 5; d++)
          _answer(
            category: IqCategory.logic,
            difficulty: d,
            isCorrect: d == 5,
          ),
      ];
      // 難易度1だけ正解 (重み 1 / 15)
      final easyOnly = [
        for (var d = 1; d <= 5; d++)
          _answer(
            category: IqCategory.logic,
            difficulty: d,
            isCorrect: d == 1,
          ),
      ];

      expect(IqScoring.weightedAccuracy(hardOnly), closeTo(5 / 15, 1e-9));
      expect(IqScoring.weightedAccuracy(easyOnly), closeTo(1 / 15, 1e-9));
      expect(
        IqScoring.weightedAccuracy(hardOnly),
        greaterThan(IqScoring.weightedAccuracy(easyOnly)),
      );
    });
  });

  group('abilityToIq', () {
    test('母集団平均の ability はちょうど IQ100 になる', () {
      expect(
        IqScoring.abilityToIq(IqCalibration.populationMeanAbility),
        100,
      );
    });

    test('平均 +1SD は IQ115 相当', () {
      const ability = IqCalibration.populationMeanAbility +
          IqCalibration.populationSdAbility;
      expect(IqScoring.abilityToIq(ability), 115);
    });

    test('平均 -1SD は IQ85 相当', () {
      const ability = IqCalibration.populationMeanAbility -
          IqCalibration.populationSdAbility;
      expect(IqScoring.abilityToIq(ability), 85);
    });

    test('全問不正解は下限にクランプされる', () {
      // ability=0 は素の換算で約54 → minIq でクランプされる
      expect(IqScoring.abilityToIq(0.0), IqCalibration.minIq);
    });

    test('全問正解でも天井は約138で、maxIq には届かない', () {
      // 25問では高得点側を細かく弁別できないため、意図的に天井が低い。
      // maxIq は換算定数を変えたときの安全弁であって到達点ではない。
      final perfect = IqScoring.abilityToIq(1.0);
      expect(perfect, 138);
      expect(perfect, lessThan(IqCalibration.maxIq));
    });

    test('レンジ外の入力でもクランプ内に収まる', () {
      expect(IqScoring.abilityToIq(5.0), IqCalibration.maxIq);
      expect(IqScoring.abilityToIq(-5.0), IqCalibration.minIq);
    });

    test('ability に対して単調増加する', () {
      var previous = IqScoring.abilityToIq(0.0);
      for (var a = 0.05; a <= 1.0; a += 0.05) {
        final current = IqScoring.abilityToIq(a);
        expect(current, greaterThanOrEqualTo(previous));
        previous = current;
      }
    });
  });

  group('normalCdf / percentile', () {
    test('CDF(0) は 0.5', () {
      expect(IqScoring.normalCdf(0), closeTo(0.5, 1e-6));
    });

    test('CDF(1.96) は約 0.975', () {
      expect(IqScoring.normalCdf(1.96), closeTo(0.975, 1e-3));
    });

    test('CDF は対称', () {
      expect(
        IqScoring.normalCdf(-1.0) + IqScoring.normalCdf(1.0),
        closeTo(1.0, 1e-6),
      );
    });

    test('IQ100 のパーセンタイルは 50', () {
      expect(IqScoring.percentileForIq(100), closeTo(50, 0.5));
    });

    test('IQ130 のパーセンタイルは約 97.7', () {
      expect(IqScoring.percentileForIq(130), closeTo(97.7, 0.5));
    });

    test('端でも 0/100 ちょうどにはならない', () {
      expect(IqScoring.percentileForIq(40), greaterThan(0));
      expect(IqScoring.percentileForIq(160), lessThan(100));
    });
  });

  group('standardError', () {
    test('設問数が増えるほど小さくなる', () {
      final few = IqScoring.standardError(0.5, 5);
      final many = IqScoring.standardError(0.5, 50);
      expect(many, lessThan(few));
    });

    test('満点でも誤差ゼロにはしない', () {
      // SE=0 だと「誤差なしで測れた」と誤読されるため下限を設けている
      expect(IqScoring.standardError(1.0, 25), greaterThan(0));
    });

    test('設問数0でも例外を投げない', () {
      expect(IqScoring.standardError(0.5, 0), greaterThan(0));
    });
  });

  group('categoryScores', () {
    test('回答があった領域だけを返す', () {
      final answers = [
        _answer(category: IqCategory.logic, difficulty: 1, isCorrect: true),
        _answer(category: IqCategory.verbal, difficulty: 2, isCorrect: false),
      ];
      final scores = IqScoring.categoryScores(answers);
      expect(scores.map((s) => s.category), [
        IqCategory.logic,
        IqCategory.verbal,
      ]);
    });

    test('領域ごとに独立して集計する', () {
      // 論理は全問正解、言語は全問不正解
      final answers = _fullSet(
        correct: (category, _) => category == IqCategory.logic,
      );
      final scores = IqScoring.categoryScores(answers);

      final logic = scores.firstWhere((s) => s.category == IqCategory.logic);
      final verbal = scores.firstWhere((s) => s.category == IqCategory.verbal);

      expect(logic.correctCount, 5);
      expect(verbal.correctCount, 0);
      expect(logic.iq, greaterThan(verbal.iq));
    });

    test('領域別IQは領域用のレンジでクランプされる', () {
      final answers = _fullSet(correct: (_, __) => true);
      final scores = IqScoring.categoryScores(answers);
      for (final score in scores) {
        expect(score.iq, lessThanOrEqualTo(IqCalibration.maxCategoryIq));
        expect(score.iq, greaterThanOrEqualTo(IqCalibration.minCategoryIq));
      }
    });
  });

  group('summarize', () {
    test('総合と領域別の両方を返す', () {
      final answers = _fullSet(correct: (_, d) => d <= 3);
      final summary = IqScoring.summarize(answers);

      expect(summary.questionCount, 25);
      expect(summary.correctCount, 15);
      expect(summary.categoryScores.length, IqCategory.values.length);
    });

    test('信頼区間は推定値を含む', () {
      final summary = IqScoring.summarize(_fullSet(correct: (_, d) => d <= 3));
      expect(summary.iqLower, lessThan(summary.totalIq));
      expect(summary.iqUpper, greaterThan(summary.totalIq));
    });

    test('weakAreas は総合を明確に下回る領域だけを返す', () {
      // 空間だけ全問不正解、他は全問正解
      final answers = _fullSet(
        correct: (category, _) => category != IqCategory.spatial,
      );
      final summary = IqScoring.summarize(answers);

      expect(
        summary.weakAreas().map((s) => s.category),
        contains(IqCategory.spatial),
      );
      expect(
        summary.weakAreas().map((s) => s.category),
        isNot(contains(IqCategory.logic)),
      );
    });

    test('全領域が同一なら weakAreas は空', () {
      final answers = _fullSet(correct: (_, d) => d <= 3);
      final summary = IqScoring.summarize(answers);
      expect(summary.weakAreas(), isEmpty);
    });

    test('未回答 (不正解扱い) を含めても例外を投げない', () {
      final answers = [
        for (final category in IqCategory.values)
          for (var d = 1; d <= 5; d++)
            IqAnswerRecord(
              questionKey: '${category.key}-$d',
              category: category,
              difficulty: d,
              selectedIndex: null,
              isCorrect: false,
              responseMs: 0,
            ),
      ];
      final summary = IqScoring.summarize(answers);
      expect(summary.correctCount, 0);
      expect(summary.totalIq, IqCalibration.minIq);
    });
  });
}
