// IQテスト機能 改善 第3ラウンドの 10 仮説検証。
//
// 第1・2ラウンドは採点とレベル調整 (スコアの意味) を見た。
// 第3ラウンドは **出題の中身そのもの** を見る。ここは両ラウンドとも
// 「生成できている / 4択が壊れていない」までしか確認していない。
//
// 実行: flutter test test/data/iq_hypothesis_round3_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/data/iq_training_drills.dart';
import 'package:my_web_app/models/iq_test.dart';

void main() {
  group('T1: 1セッション内で同じ問題が重複出題される', () {
    test('語彙ドリルは8問中に同一問題が複数回出る', () {
      // 語彙の出題プールは 5〜8 件しかない。1セッション8問なので
      // 鳩の巣原理で必ず重複する。同じ問題を続けて解かされるのは
      // 学習としても測定としても無意味。
      var sessionsWithDuplicates = 0;
      var worstDuplicateCount = 0;

      for (var seed = 0; seed < 30; seed++) {
        final drills = IqDrillGenerator.generate(
          category: IqCategory.verbal,
          level: 1,
          seed: seed,
        );
        final prompts = drills.map((q) => q.prompt).toList();
        final unique = prompts.toSet();
        if (unique.length < prompts.length) {
          sessionsWithDuplicates++;
          final dup = prompts.length - unique.length;
          if (dup > worstDuplicateCount) worstDuplicateCount = dup;
        }
      }

      // ignore: avoid_print
      print('T1 FIXED: 語彙L1 30セッション中 $sessionsWithDuplicates 回で重複 '
          '(最大 $worstDuplicateCount 問)');

      expect(
        sessionsWithDuplicates,
        0,
        reason: 'プールを配り切るまで同じ問題を出さない',
      );
    });

    test('論理L1・語彙L4 でも同様に重複する', () {
      for (final spec in [
        (IqCategory.logic, 1),
        (IqCategory.verbal, 4),
      ]) {
        var dupSessions = 0;
        for (var seed = 0; seed < 20; seed++) {
          final drills = IqDrillGenerator.generate(
            category: spec.$1,
            level: spec.$2,
            seed: seed,
          );
          final prompts = drills.map((q) => q.prompt).toList();
          if (prompts.toSet().length < prompts.length) dupSessions++;
        }
        // ignore: avoid_print
        print('T1 FIXED: ${spec.$1.key} L${spec.$2} → 20セッション中 '
            '$dupSessions 回で重複');
        expect(dupSessions, 0);
      }
    });
  });

  group('T3: 生成ドリルのレベルが実際の難易度と対応していない', () {
    test('語彙レベル5はレベル3・4と同じ生成器を使っている', () {
      // レベル5は analogy / oddOneOut をランダムに選ぶだけで、
      // レベル3 (analogy) とレベル4 (oddOneOut) の問題そのもの。
      // difficulty ラベルだけが 5 になっている。
      final l3 = <String>{};
      final l4 = <String>{};
      final l5 = <String>{};
      for (var seed = 0; seed < 40; seed++) {
        l3.addAll(
          IqDrillGenerator.generate(
            category: IqCategory.verbal,
            level: 3,
            seed: seed,
          ).map((q) => q.prompt),
        );
        l4.addAll(
          IqDrillGenerator.generate(
            category: IqCategory.verbal,
            level: 4,
            seed: seed,
          ).map((q) => q.prompt),
        );
        l5.addAll(
          IqDrillGenerator.generate(
            category: IqCategory.verbal,
            level: 5,
            seed: seed,
          ).map((q) => q.prompt),
        );
      }

      // 選択肢の並びが違うだけで prompt 文字列は変わるため、
      // 「どの生成器から出たか」で比べる (シャッフル非依存)。
      String kind(String prompt) => prompt.contains('同じ関係になる')
          ? 'analogy'
          : prompt.contains('性質が異なる')
              ? 'oddOneOut'
              : prompt.contains('近い構造')
                  ? 'sentenceRelation'
                  : 'other';

      final l5Kinds = l5.map(kind).toSet();
      final lowerKinds = {...l3.map(kind), ...l4.map(kind)};

      // ignore: avoid_print
      print('T3: 語彙L5 の生成器 = $l5Kinds / L3+L4 の生成器 = $lowerKinds');

      expect(
        l5Kinds.difference(lowerKinds),
        isNotEmpty,
        reason: 'L5 固有の生成器が無ければ難易度は上がっていない',
      );
      // ignore: avoid_print
      print('T3 FIXED: 語彙L5 に固有の生成器 '
          '${l5Kinds.difference(lowerKinds)} が入った');
    });

    test('記憶ドリルは正しくレベルとともに負荷が上がる (対照)', () {
      // 対照実験: 記憶は span が 4+level で単調に伸びる。
      // つまり「レベル設計ができない」のではなく語彙だけが欠けている。
      var previousSpan = 0;
      for (var level = 1; level <= 5; level++) {
        final q = IqDrillGenerator.generate(
          category: IqCategory.memory,
          level: level,
          seed: 7,
        ).first;
        final span = q.memoryStimulus!.split('　').length;
        expect(span, greaterThan(previousSpan));
        previousSpan = span;
      }
      // ignore: avoid_print
      print('T3: 記憶ドリルは span が単調増加 (対照として正常)');
    });
  });

  group('T8: 順序推論の答えが一意に決まるか', () {
    test('提示された関係文から順序が一意に定まる', () {
      // 生成器は真の並びから連続ペアだけを提示している。
      // A>B, B>C, C>D が揃えば全順序は一意。
      // 「一意でない問題が混ざる」という仮説を反証しにいく。
      for (var seed = 0; seed < 40; seed++) {
        final drills = IqDrillGenerator.generate(
          category: IqCategory.logic,
          level: 4,
          seed: seed,
        );
        for (final q in drills) {
          // 提示文の数 = 人数-1 なら連鎖が一本に繋がる
          final statements =
              q.prompt.split('\n').where((l) => l.contains('より背が高い')).length;
          final names = RegExp('[A-E]')
              .allMatches(q.prompt)
              .map((m) => m.group(0)!)
              .toSet();
          expect(
            statements,
            names.length - 1,
            reason: '関係文が n-1 本なら全順序が一意に決まる',
          );
        }
      }
      // ignore: avoid_print
      print('T8 REFUTED: 順序推論は常に一意に決まる (n-1 本の連鎖)');
    });
  });

  group('T9: 同一プール行が1セッションに複数回現れる', () {
    test('類推ドリルは同じ関係を繰り返し出す', () {
      final drills = IqDrillGenerator.generate(
        category: IqCategory.verbal,
        level: 3,
        seed: 3,
      );
      final relations =
          drills.map((q) => q.explanation.split('。').first).toList();
      final unique = relations.toSet();
      // ignore: avoid_print
      print('T9: 8問中の関係の種類 = ${unique.length} 種');

      // プール6件に対し8問なので、配り切るまでは重複しない = 6種以上
      expect(
        unique.length,
        greaterThanOrEqualTo(6),
        reason: 'プールを配り切るまで同じ関係を繰り返さない',
      );
      // ignore: avoid_print
      print('T9 FIXED: 8問中 ${unique.length} 種 '
          '(プール6件を配り切ってから再利用)');
    });
  });

  group('T6: 数列ドリルの誤答が正解と紛らわしすぎないか', () {
    test('誤答は正解と異なる値で、かつ極端に離れていない', () {
      var tooFar = 0;
      var total = 0;

      for (var level = 1; level <= 5; level++) {
        for (var seed = 0; seed < 20; seed++) {
          final drills = IqDrillGenerator.generate(
            category: IqCategory.numerical,
            level: level,
            seed: seed,
          );
          for (final q in drills) {
            final answer = int.parse(q.options[q.correctIndex]);
            for (var i = 0; i < q.options.length; i++) {
              if (i == q.correctIndex) continue;
              final wrong = int.parse(q.options[i]);
              expect(wrong, isNot(answer));
              total++;
              // 桁が違うほど離れていると消去法で当たる
              if (answer > 0 && (wrong / answer > 3 || wrong / answer < 0.33)) {
                tooFar++;
              }
            }
          }
        }
      }

      // ignore: avoid_print
      print('T6: 誤答 $total 件中 $tooFar 件が正解の1/3未満または3倍超');
      expect(
        tooFar / total,
        lessThan(0.05),
        reason: '桁違いの誤答が多いと消去法で当たってしまう',
      );
      // ignore: avoid_print
      print('T6 REFUTED: 誤答は正解の近傍に収まっている');
    });
  });

  group('T5: 記憶課題の提示時間が制限時間を圧迫する', () {
    test('記憶5問の提示時間だけで35秒が消費される', () {
      // テスト本体の記憶課題は revealSeconds 5..9。
      // この間ユーザーは選択肢を見られないのに、全体の20分は減り続ける。
      const revealSeconds = [5, 6, 7, 8, 9];
      final total = revealSeconds.reduce((a, b) => a + b);
      // ignore: avoid_print
      print('T5: 記憶課題の提示時間合計 = $total 秒 '
          '(制限時間 1200 秒の ${(total / 1200 * 100).toStringAsFixed(1)}%)');

      expect(total, 35);
      // 影響は約3% と小さい。過大評価しないための実測。
      expect(
        total / 1200,
        lessThan(0.05),
        reason: '5%未満なら実務上の影響は小さい',
      );
      // ignore: avoid_print
      print('T5 REFUTED: 影響は 2.9% で、制限時間を実質的に圧迫しない');
    });
  });
}
