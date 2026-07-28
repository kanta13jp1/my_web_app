import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/iq_test.dart';
import 'package:my_web_app/services/iq_training_service.dart';

IqCategoryScore _score(IqCategory category, int iq) {
  return IqCategoryScore(
    category: category,
    correctCount: 3,
    questionCount: 5,
    weightedAccuracy: 0.55,
    iq: iq,
    standardError: 5,
  );
}

IqTestResult _result({
  required int totalIq,
  required Map<IqCategory, int> categoryIqs,
}) {
  return IqTestResult(
    id: 1,
    userId: 'user-1',
    startedAt: DateTime(2026, 7, 27, 10),
    completedAt: DateTime(2026, 7, 27, 10, 20),
    isCompleted: true,
    totalIq: totalIq,
    percentile: 50,
    weightedAccuracy: 0.55,
    correctCount: 15,
    questionCount: 25,
    durationSeconds: 1200,
    categoryScores: [
      for (final entry in categoryIqs.entries) _score(entry.key, entry.value),
    ],
  );
}

IqTrainingSession _session({
  required IqCategory category,
  required int correct,
  required int total,
  required DateTime completedAt,
  int level = 3,
}) {
  return IqTrainingSession(
    id: 1,
    planId: 1,
    userId: 'user-1',
    category: category,
    level: level,
    correctCount: correct,
    questionCount: total,
    durationSeconds: 300,
    completedAt: completedAt,
  );
}

void main() {
  group('levelForIq', () {
    test('偏差IQの区切りに対応したレベルを返す', () {
      expect(IqTrainingService.levelForIq(140), 5);
      expect(IqTrainingService.levelForIq(130), 5);
      expect(IqTrainingService.levelForIq(120), 4);
      expect(IqTrainingService.levelForIq(115), 4);
      expect(IqTrainingService.levelForIq(105), 3);
      expect(IqTrainingService.levelForIq(100), 3);
      expect(IqTrainingService.levelForIq(90), 2);
      expect(IqTrainingService.levelForIq(85), 2);
      expect(IqTrainingService.levelForIq(70), 1);
    });

    test('IQ が高いほどレベルが下がることはない', () {
      var previous = IqTrainingService.levelForIq(55);
      for (var iq = 56; iq <= 145; iq++) {
        final current = IqTrainingService.levelForIq(iq);
        expect(current, greaterThanOrEqualTo(previous));
        previous = current;
      }
    });
  });

  group('weeklySessionsForGap', () {
    test('総合との差が大きいほど回数が多い', () {
      expect(IqTrainingService.weeklySessionsForGap(20), 5);
      expect(IqTrainingService.weeklySessionsForGap(12), 4);
      expect(IqTrainingService.weeklySessionsForGap(7), 3);
      expect(IqTrainingService.weeklySessionsForGap(0), 2);
    });

    test('差が負 (総合より強い) でも最低回数は割り当てる', () {
      expect(IqTrainingService.weeklySessionsForGap(-10), 2);
    });
  });

  group('nextLevel', () {
    test('正答率が高ければ上がる', () {
      expect(IqTrainingService.nextLevel(3, 0.9), 4);
    });

    test('正答率が低ければ下がる', () {
      expect(IqTrainingService.nextLevel(3, 0.4), 2);
    });

    test('適正帯なら据え置き', () {
      expect(IqTrainingService.nextLevel(3, 0.7), 3);
    });

    test('上限・下限を超えない', () {
      expect(IqTrainingService.nextLevel(5, 1.0), 5);
      expect(IqTrainingService.nextLevel(1, 0.0), 1);
    });
  });

  group('buildPlanDraft', () {
    test('弱点領域があればそれを対象にし、basis で理由を示す', () {
      final result = _result(
        totalIq: 100,
        categoryIqs: {
          IqCategory.logic: 110,
          IqCategory.numerical: 105,
          IqCategory.spatial: 80,
          IqCategory.memory: 85,
          IqCategory.verbal: 100,
        },
      );

      final draft = IqTrainingService.buildPlanDraft(result);

      expect(draft.basis, IqPlanBasis.weakAreaDetected);
      expect(
        draft.targets.map((t) => t.category),
        containsAll([IqCategory.spatial, IqCategory.memory]),
      );
      expect(
        draft.targets.map((t) => t.category),
        isNot(contains(IqCategory.logic)),
      );
    });

    test('弱点が最も低い順に並ぶ', () {
      final result = _result(
        totalIq: 100,
        categoryIqs: {
          IqCategory.logic: 110,
          IqCategory.numerical: 110,
          IqCategory.spatial: 85,
          IqCategory.memory: 75,
          IqCategory.verbal: 90,
        },
      );

      final draft = IqTrainingService.buildPlanDraft(result);
      expect(draft.targets.first.category, IqCategory.memory);
    });

    test('弱点がなくても学習対象は出し、basis で区別できる', () {
      // 全領域が総合と同じ = はっきりした弱点なし
      final result = _result(
        totalIq: 100,
        categoryIqs: {
          IqCategory.logic: 100,
          IqCategory.numerical: 100,
          IqCategory.spatial: 100,
          IqCategory.memory: 100,
          IqCategory.verbal: 100,
        },
      );

      final draft = IqTrainingService.buildPlanDraft(result);

      // 「弱点なし」と「未評価」を取り違えないことがこの機能の要
      expect(draft.basis, IqPlanBasis.balancedProfile);
      expect(draft.targets, isNotEmpty);
      expect(draft.basisMessageJa, contains('弱点はありません'));
    });

    test('開始レベルは領域別IQから決まる', () {
      final result = _result(
        totalIq: 110,
        categoryIqs: {
          IqCategory.logic: 120,
          IqCategory.spatial: 85,
        },
      );

      final draft = IqTrainingService.buildPlanDraft(result);
      final spatial =
          draft.targets.firstWhere((t) => t.category == IqCategory.spatial);

      expect(spatial.baselineIq, 85);
      expect(spatial.startLevel, IqTrainingService.levelForIq(85));
    });

    test('対象数は maxTargets を超えない', () {
      final result = _result(
        totalIq: 120,
        categoryIqs: {
          IqCategory.logic: 80,
          IqCategory.numerical: 82,
          IqCategory.spatial: 84,
          IqCategory.memory: 86,
          IqCategory.verbal: 88,
        },
      );

      final draft = IqTrainingService.buildPlanDraft(result, maxTargets: 3);
      expect(draft.targets.length, 3);
    });
  });

  group('currentLevelFor', () {
    const target = IqTrainingTarget(
      category: IqCategory.spatial,
      baselineIq: 85,
      startLevel: 2,
      weeklySessions: 4,
    );

    test('実績が無ければ開始レベルのまま', () {
      expect(
        IqTrainingService.currentLevelFor(target: target, sessions: []),
        2,
      );
    });

    test('高正答率が続けばレベルが上がる', () {
      final sessions = [
        for (var i = 0; i < 3; i++)
          _session(
            category: IqCategory.spatial,
            correct: 8,
            total: 8,
            completedAt: DateTime(2026, 7, 20 + i),
          ),
      ];

      expect(
        IqTrainingService.currentLevelFor(target: target, sessions: sessions),
        5,
      );
    });

    test('低正答率が続けば下限で止まる', () {
      final sessions = [
        for (var i = 0; i < 4; i++)
          _session(
            category: IqCategory.spatial,
            correct: 1,
            total: 8,
            completedAt: DateTime(2026, 7, 20 + i),
          ),
      ];

      expect(
        IqTrainingService.currentLevelFor(target: target, sessions: sessions),
        1,
      );
    });

    test('他領域のセッションは影響しない', () {
      final sessions = [
        for (var i = 0; i < 3; i++)
          _session(
            category: IqCategory.verbal,
            correct: 8,
            total: 8,
            completedAt: DateTime(2026, 7, 20 + i),
          ),
      ];

      expect(
        IqTrainingService.currentLevelFor(target: target, sessions: sessions),
        2,
      );
    });

    test('直近 window 件だけを見る', () {
      // 古い高正答率が大量にあっても、直近の低正答率が反映される
      final sessions = [
        for (var i = 0; i < 10; i++)
          _session(
            category: IqCategory.spatial,
            correct: 8,
            total: 8,
            completedAt: DateTime(2026, 7, i + 1),
          ),
        for (var i = 0; i < 5; i++)
          _session(
            category: IqCategory.spatial,
            correct: 1,
            total: 8,
            completedAt: DateTime(2026, 7, 20 + i),
          ),
      ];

      final level = IqTrainingService.currentLevelFor(
        target: target,
        sessions: sessions,
        window: 5,
      );
      expect(level, 1);
    });

    test('順序が前後して渡されても時系列順に適用する', () {
      final ascending = [
        _session(
          category: IqCategory.spatial,
          correct: 8,
          total: 8,
          completedAt: DateTime(2026, 7, 21),
        ),
        _session(
          category: IqCategory.spatial,
          correct: 1,
          total: 8,
          completedAt: DateTime(2026, 7, 22),
        ),
      ];
      final descending = ascending.reversed.toList();

      expect(
        IqTrainingService.currentLevelFor(
          target: target,
          sessions: descending,
        ),
        IqTrainingService.currentLevelFor(
          target: target,
          sessions: ascending,
        ),
      );
    });

    test('問題数0のセッションは無視する', () {
      final sessions = [
        _session(
          category: IqCategory.spatial,
          correct: 0,
          total: 0,
          completedAt: DateTime(2026, 7, 21),
        ),
      ];

      expect(
        IqTrainingService.currentLevelFor(target: target, sessions: sessions),
        2,
      );
    });
  });

  group('shouldRetest', () {
    test('実施回数が少ないうちは勧めない', () {
      final sessions = [
        for (var i = 0; i < 5; i++)
          _session(
            category: IqCategory.spatial,
            correct: 6,
            total: 8,
            completedAt: DateTime(2026, 7, i + 1),
          ),
      ];
      expect(IqTrainingService.shouldRetest(sessions), isFalse);
      expect(IqTrainingService.sessionsUntilRetest(sessions), 7);
    });

    test('閾値に達したら勧める', () {
      final sessions = [
        for (var i = 0; i < 12; i++)
          _session(
            category: IqCategory.spatial,
            correct: 6,
            total: 8,
            completedAt: DateTime(2026, 7, i + 1),
          ),
      ];
      expect(IqTrainingService.shouldRetest(sessions), isTrue);
      expect(IqTrainingService.sessionsUntilRetest(sessions), 0);
    });
  });
}
