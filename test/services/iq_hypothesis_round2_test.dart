// IQテスト機能 改善 第2ラウンドの 10 仮説検証。
//
// 第1ラウンド (PR #4385) で入れた修正そのものを敵対的に検証する。
// 自分が直したばかりのコードは、直したという安心感で検査が甘くなる。
//
// 実行: flutter test test/services/iq_hypothesis_round2_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/data/iq_question_bank.dart';
import 'package:my_web_app/models/iq_test.dart';
import 'package:my_web_app/services/iq_scoring.dart';
import 'package:my_web_app/services/iq_training_service.dart';

IqCategoryScore _score(
  IqCategory category,
  int iq, {
  double standardError = 18.5,
}) =>
    IqCategoryScore(
      category: category,
      correctCount: 3,
      questionCount: 5,
      weightedAccuracy: 0.55,
      iq: iq,
      standardError: standardError,
    );

IqTestResult _result({
  required int totalIq,
  required List<IqCategoryScore> scores,
  int questionCount = 25,
  int? attemptedCount,
}) =>
    IqTestResult(
      id: 1,
      userId: 'u',
      startedAt: DateTime(2026, 7, 29, 10),
      completedAt: DateTime(2026, 7, 29, 10, 20),
      isCompleted: true,
      totalIq: totalIq,
      percentile: 50,
      weightedAccuracy: 0.55,
      correctCount: 14,
      questionCount: questionCount,
      attemptedCount: attemptedCount,
      durationSeconds: 1200,
      categoryScores: scores,
    );

IqTrainingSession _session({
  required IqCategory category,
  required int level,
  required int correct,
  required int total,
  required DateTime at,
}) =>
    IqTrainingSession(
      id: 1,
      planId: 1,
      userId: 'u',
      category: category,
      level: level,
      correctCount: correct,
      questionCount: total,
      durationSeconds: 300,
      completedAt: at,
    );

void main() {
  group('R1: standardError が 0 だと弱点判定が全通しになる', () {
    test('SE=0 では 1 ポイント差でも弱点と判定される', () {
      // fromJson は standard_error 欠損時に 0 を入れる。
      // 新しい判定式は gap > 1.0 * SE なので、SE=0 だと
      // 「総合を少しでも下回れば弱点」に退化する。
      final result = _result(
        totalIq: 100,
        scores: [
          _score(IqCategory.logic, 99, standardError: 0),
          _score(IqCategory.spatial, 100, standardError: 0),
        ],
      );

      final weak = result.weakAreas();
      // ignore: avoid_print
      print('R1 FIXED: SE=0 でも 1 ポイント差は弱点にならない '
          '(検出 ${weak.length} 件)');

      expect(
        weak,
        isEmpty,
        reason: 'SE に下限を課したので、誤差ゼロ扱いのデータでも過検出しない',
      );
    });

    test('fromJson は standard_error 欠損時に 0 を入れる', () {
      final score = IqCategoryScore.fromJson({
        'category': 'logic',
        'correct_count': 3,
        'question_count': 5,
        'weighted_accuracy': 0.55,
        'category_iq': 100,
        // standard_error なし
      });
      // 生の値は 0 のままだが、判定に使う実効値は下限で守られる
      expect(score.standardError, 0);
      expect(
        score.effectiveStandardError,
        IqCategoryScore.minimumStandardError,
      );
      // ignore: avoid_print
      print('R1 FIXED: 生値 0 / 実効値 '
          '${score.effectiveStandardError} で判定式を保護');
    });
  });

  group('R2: 修正前のテストは振り返りを復元できない', () {
    test('同じ seed でも修正後は別の問題セットになりうる', () {
      // 修正前: seed は選択肢順だけを変えた → 出題は常に既定フォーム。
      // 修正後: seed が出題そのものも選ぶ。
      // つまり修正前に seed=X で受けた人の回答キーは既定フォーム側なのに、
      // 復元は代替フォームを混ぜた集合を返す。
      const seed = 42;
      final reconstructed =
          IqQuestionBank.standardTest(seed: seed).map((q) => q.key).toSet();
      final legacyForm =
          IqQuestionBank.standardTest().map((q) => q.key).toSet();

      final missing = legacyForm.difference(reconstructed);
      // ignore: avoid_print
      print('R2: 修正前フォームのうち復元集合に無いキー = ${missing.length} 件');

      expect(
        missing,
        isNotEmpty,
        reason: '一致するなら復元は壊れていない',
      );
      // ignore: avoid_print
      print('R2 CONFIRMED: 修正前の回答は振り返りから静かに脱落する');
    });
  });

  group('R3: 追加したのに呼ばれていない関数がある', () {
    test('hasEnoughEvidenceForLevelChange は動くが誰も使っていない', () {
      // 関数自体は正しく動く
      final sessions = [
        _session(
          category: IqCategory.logic,
          level: 3,
          correct: 6,
          total: 8,
          at: DateTime(2026, 7, 20),
        ),
      ];
      expect(
        IqTrainingService.hasEnoughEvidenceForLevelChange(
          sessions,
          IqCategory.logic,
        ),
        isFalse,
      );
      // ignore: avoid_print
      print('R3 FIXED: 最小標本の判定が currentLevelFor に組み込まれた');
    });

    test('試行数が1セッションでもレベルが動いてしまう', () {
      const target = IqTrainingTarget(
        category: IqCategory.logic,
        baselineIq: 100,
        startLevel: 3,
        weeklySessions: 3,
      );
      // たった8問の1セッションで昇格が起きる
      final level = IqTrainingService.currentLevelFor(
        target: target,
        sessions: [
          _session(
            category: IqCategory.logic,
            level: 3,
            correct: 8,
            total: 8,
            at: DateTime(2026, 7, 20),
          ),
        ],
      );
      expect(
        level,
        3,
        reason: '8問 (最小標本24問未満) ではレベルを動かさない',
      );
      // ignore: avoid_print
      print('R3 FIXED: 8問だけではレベルが動かない '
          '(最小 ${IqTrainingService.minQuestionsForLevelChange} 問)');
    });
  });

  group('R4: 異なるレベルのセッションを混ぜて合算している', () {
    test('レベル1とレベル5の試行が1つの正答率に合算される', () {
      const target = IqTrainingTarget(
        category: IqCategory.logic,
        baselineIq: 100,
        startLevel: 3,
        weeklySessions: 3,
      );

      // レベル1で満点、レベル5で全滅 → 難易度がまるで違う試行を平均している
      final sessions = [
        _session(
          category: IqCategory.logic,
          level: 1,
          correct: 8,
          total: 8,
          at: DateTime(2026, 7, 20),
        ),
        _session(
          category: IqCategory.logic,
          level: 5,
          correct: 0,
          total: 8,
          at: DateTime(2026, 7, 21),
        ),
      ];

      final level = IqTrainingService.currentLevelFor(
        target: target,
        sessions: sessions,
      );
      // 直近レベル(5)の試行だけを見る。8問しかないので最小標本に届かず据置。
      // ignore: avoid_print
      print('R4 FIXED: レベル1満点は合算されず、直近レベル5の判定結果 = '
          'レベル$level');

      expect(
        level,
        5,
        reason: '直近レベルの試行だけで判定し、標本不足なら据え置く',
      );
    });
  });

  group('R5: 完答率の閾値', () {
    test('3問スキップは許容し、半分未着手は警告する', () {
      final mild = _result(
        totalIq: 100,
        scores: [_score(IqCategory.logic, 100)],
        attemptedCount: 22,
      );
      final severe = _result(
        totalIq: 100,
        scores: [_score(IqCategory.logic, 100)],
        attemptedCount: 10,
      );

      // ignore: avoid_print
      print('R5 FIXED: 22/25 (${(mild.completionRate * 100).round()}%) '
          '→ reliable=${mild.isReliable} / '
          '10/25 (${(severe.completionRate * 100).round()}%) '
          '→ reliable=${severe.isReliable}');

      // 閾値 0.9 では3問スキップで警告が出て日常化し、
      // 本当に測れていない回を見落とす。0.8 に緩めた。
      expect(mild.isReliable, isTrue);
      expect(severe.isReliable, isFalse);
    });

    test('旧データ (attemptedCount 欠損) は信頼できる扱いになる', () {
      final legacy = _result(
        totalIq: 100,
        scores: [_score(IqCategory.logic, 100)],
        // attemptedCount なし
      );
      expect(legacy.completionRate, 1.0);
      expect(legacy.isReliable, isTrue);
      // ignore: avoid_print
      print('R5: 旧データは完答扱いにフォールバック (意図どおり)');
    });
  });

  group('R6: 弱点判定ロジックが2箇所に重複している', () {
    test('IqScoreSummary と IqTestResult が同じ計算を別々に持つ', () {
      final answers = [
        for (final c in IqCategory.values)
          for (var d = 1; d <= 5; d++)
            IqAnswerRecord(
              questionKey: '${c.key}-$d',
              category: c,
              difficulty: d,
              selectedIndex: 0,
              isCorrect: c != IqCategory.spatial,
              responseMs: 1000,
            ),
      ];

      final summary = IqScoring.summarize(answers);
      final result = _result(
        totalIq: summary.totalIq,
        scores: summary.categoryScores,
      );

      final fromSummary = summary.weakAreas().map((s) => s.category).toSet();
      final fromResult = result.weakAreas().map((s) => s.category).toSet();

      expect(fromSummary, fromResult);

      // 判定の実体を IqCategoryScore.selectWeak に一本化したので、
      // 両クラスは同じ関数を呼ぶだけになり乖離しえない。
      final direct = IqCategoryScore.selectWeak(
        summary.categoryScores,
        summary.totalIq,
      ).map((s) => s.category).toSet();
      expect(direct, fromSummary);
      expect(direct, fromResult);
      // ignore: avoid_print
      print('R6 FIXED: 両クラスとも selectWeak に委譲 (実装は1箇所)');
    });
  });

  group('R7: パーセンタイル表示の精度', () {
    test('信頼区間 ±36 に対し 0.1% 刻みで提示している', () {
      final se = IqScoring.standardError(0.55, 25);
      const iq = 110;
      final p = IqScoring.percentileForIq(iq);
      final pLow = IqScoring.percentileForIq((iq - 1.96 * se).round());
      final pHigh = IqScoring.percentileForIq((iq + 1.96 * se).round());

      // ignore: avoid_print
      print('R7: IQ$iq → 上位 ${(100 - p).toStringAsFixed(1)}% / '
          'CI 内では 上位 ${(100 - pHigh).toStringAsFixed(1)}% 〜 '
          '${(100 - pLow).toStringAsFixed(1)}%');

      expect(
        (pHigh - pLow).abs(),
        greaterThan(10),
        reason: 'CI 内でパーセンタイルが十分動くなら 0.1% 刻みは過剰精度',
      );
      // ignore: avoid_print
      print('R7 CONFIRMED (表示側で緩和): 小数第1位は根拠が無いため'
          '整数の概数表示へ変更。基礎的な不確かさ自体は残る');
    });
  });

  group('R9: 代替フォームの難易度が同等である保証', () {
    test('同一セルの2問は難易度ラベルだけが一致し中身は未検証', () {
      final byCell = <String, List<IqQuestion>>{};
      for (final q in IqQuestionBank.allQuestions) {
        byCell
            .putIfAbsent('${q.category.key}-${q.difficulty}', () => [])
            .add(q);
      }

      for (final entry in byCell.entries) {
        expect(entry.value.length, 2, reason: entry.key);
        // 揃っているのは difficulty (= 得点の重み) だけ
        expect(
          entry.value.map((q) => q.difficulty).toSet().length,
          1,
          reason: entry.key,
        );
      }
      // ignore: avoid_print
      print('R9 CONFIRMED: 重み構成は保証されるが、'
          '実際の正答率が同等かは受験データがないと検証不能');
    });
  });

  group('R10: グリッド説明の頑健性', () {
    test('全角スペース区切りのグリッドは説明に変換されない', () {
      // 記憶課題の刺激は全角スペース区切り。空間問題は半角。
      // 将来どちらかが混ざると説明が作れず ■□ が読み上げられる。
      const halfWidth = '■ □\n□ □';
      const fullWidth = '■　□\n□　□';

      final a = describeGridText(halfWidth);
      final b = describeGridText(fullWidth);

      // ignore: avoid_print
      print('R10: 半角区切り → ${a.replaceAll("\\n", " / ")}');
      // ignore: avoid_print
      print('R10: 全角区切り → ${b.replaceAll("\\n", " / ")}');

      expect(a, contains('塗り'));
      expect(
        b,
        contains('塗り'),
        reason: '全角区切りでも説明に変換できるべき',
      );
    });
  });
}
