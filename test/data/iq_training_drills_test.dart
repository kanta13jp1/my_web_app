import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/data/iq_training_drills.dart';
import 'package:my_web_app/models/iq_test.dart';

void main() {
  group('生成されたドリルの整合性', () {
    // 全領域 × 全レベル × 複数 seed を総当たりする。
    // 生成器が1つでも「正解が選択肢に無い」問題を吐くと解けなくなるため、
    // ここは網羅的に回す価値がある。
    test('どの領域・レベル・seed でも解ける問題になっている', () {
      for (final category in IqCategory.values) {
        for (var level = 1; level <= 5; level++) {
          for (var seed = 0; seed < 25; seed++) {
            final drills = IqDrillGenerator.generate(
              category: category,
              level: level,
              seed: seed,
            );

            final label = '${category.key}/L$level/seed$seed';
            expect(
              drills.length,
              IqDrillGenerator.defaultSessionSize,
              reason: label,
            );

            for (final q in drills) {
              expect(q.category, category, reason: label);
              expect(q.difficulty, level, reason: label);
              expect(q.prompt.trim(), isNotEmpty, reason: label);
              expect(q.explanation.trim(), isNotEmpty, reason: label);

              // 正解が必ず選択肢の中にある
              expect(
                q.correctIndex,
                inInclusiveRange(0, q.options.length - 1),
                reason: '$label: correctIndex が範囲外',
              );
              // 原則4択。ただし順序推論のように答えの候補が本質的に3つしか
              // ない問題型もあるため下限は3とする。2択以下は当てずっぽうで
              // 当たりすぎるので許容しない。
              expect(
                q.options.length,
                inInclusiveRange(3, 4),
                reason: '$label: 選択肢数が不正 (${q.options})',
              );

              // 選択肢が重複していると正解が2つ存在してしまう
              expect(
                q.options.toSet().length,
                q.options.length,
                reason: '$label: 選択肢が重複 (${q.options})',
              );

              for (final option in q.options) {
                expect(
                  option.trim(),
                  isNotEmpty,
                  reason: '$label: 空の選択肢',
                );
              }
            }
          }
        }
      }
    });

    test('同じ seed なら同じ問題が出る (再現性)', () {
      final a = IqDrillGenerator.generate(
        category: IqCategory.numerical,
        level: 3,
        seed: 99,
      );
      final b = IqDrillGenerator.generate(
        category: IqCategory.numerical,
        level: 3,
        seed: 99,
      );

      for (var i = 0; i < a.length; i++) {
        expect(a[i].prompt, b[i].prompt);
        expect(a[i].options, b[i].options);
        expect(a[i].correctIndex, b[i].correctIndex);
      }
    });

    test('seed が違えば内容が変わる (毎回同じ問題にならない)', () {
      final a = IqDrillGenerator.generate(
        category: IqCategory.numerical,
        level: 3,
        seed: 1,
      );
      final b = IqDrillGenerator.generate(
        category: IqCategory.numerical,
        level: 3,
        seed: 2,
      );

      final promptsA = a.map((q) => q.prompt).toList();
      final promptsB = b.map((q) => q.prompt).toList();
      expect(promptsA, isNot(equals(promptsB)));
    });

    test('問題キーが一意', () {
      for (final category in IqCategory.values) {
        final drills = IqDrillGenerator.generate(
          category: category,
          level: 3,
          seed: 5,
          count: 20,
        );
        expect(drills.map((q) => q.key).toSet().length, drills.length);
      }
    });

    test('レベルは 1..5 にクランプされる', () {
      final low = IqDrillGenerator.generate(
        category: IqCategory.logic,
        level: -3,
        seed: 1,
      );
      final high = IqDrillGenerator.generate(
        category: IqCategory.logic,
        level: 99,
        seed: 1,
      );

      expect(low.first.difficulty, 1);
      expect(high.first.difficulty, 5);
    });

    test('count を指定した数だけ生成する', () {
      final drills = IqDrillGenerator.generate(
        category: IqCategory.verbal,
        level: 2,
        seed: 3,
        count: 15,
      );
      expect(drills.length, 15);
    });
  });

  group('領域ごとの性質', () {
    test('記憶ドリルは刺激と提示時間を持ち、レベルでスパンが伸びる', () {
      for (var level = 1; level <= 5; level++) {
        final drills = IqDrillGenerator.generate(
          category: IqCategory.memory,
          level: level,
          seed: 11,
        );

        for (final q in drills) {
          expect(q.hasMemoryPhase, isTrue);
          expect(q.revealSeconds, greaterThan(0));

          // 全角スペース区切りの数字列
          final digits = q.memoryStimulus!.split('　');
          expect(digits.length, 4 + level);
        }
      }
    });

    test('記憶ドリルの提示時間はレベルとともに増える', () {
      int revealFor(int level) => IqDrillGenerator.generate(
            category: IqCategory.memory,
            level: level,
            seed: 4,
          ).first.revealSeconds!;

      var previous = revealFor(1);
      for (var level = 2; level <= 5; level++) {
        final current = revealFor(level);
        expect(current, greaterThan(previous));
        previous = current;
      }
    });

    test('空間ドリルは等幅表示フラグを立てる', () {
      final drills = IqDrillGenerator.generate(
        category: IqCategory.spatial,
        level: 4,
        seed: 8,
      );
      for (final q in drills) {
        expect(q.monospacePrompt, isTrue);
      }
    });

    test('空間ドリルは対称な盤面でも必ず4択になる', () {
      // 対称なグリッドは変換結果が一致して誤答を作れず、放置すると3択に縮む。
      // 総当たり補充でそれを防いでいることを固定する。
      for (var level = 1; level <= 5; level++) {
        for (var seed = 0; seed < 40; seed++) {
          final drills = IqDrillGenerator.generate(
            category: IqCategory.spatial,
            level: level,
            seed: seed,
          );
          for (final q in drills) {
            expect(
              q.options.length,
              4,
              reason: 'spatial/L$level/seed$seed: ${q.options}',
            );
          }
        }
      }
    });

    test('空間ドリルの選択肢は正しいグリッド形式', () {
      for (var level = 1; level <= 5; level++) {
        final drills = IqDrillGenerator.generate(
          category: IqCategory.spatial,
          level: level,
          seed: 13,
        );

        for (final q in drills) {
          for (final option in q.options) {
            final rows = option.split('\n');
            // 正方グリッドであること
            for (final row in rows) {
              final cells = row.split(' ');
              expect(cells.length, rows.length);
              for (final cell in cells) {
                expect(['■', '□'], contains(cell));
              }
            }
          }
        }
      }
    });

    test('数列ドリルの選択肢はすべて数値', () {
      for (var level = 1; level <= 5; level++) {
        final drills = IqDrillGenerator.generate(
          category: IqCategory.numerical,
          level: level,
          seed: 21,
        );

        for (final q in drills) {
          for (final option in q.options) {
            expect(
              int.tryParse(option),
              isNotNull,
              reason: '数値でない選択肢: $option',
            );
          }
        }
      }
    });

    test('数列ドリルの解説に正解が含まれる', () {
      final drills = IqDrillGenerator.generate(
        category: IqCategory.numerical,
        level: 3,
        seed: 33,
      );
      for (final q in drills) {
        expect(q.explanation, contains(q.options[q.correctIndex]));
      }
    });
  });
}
