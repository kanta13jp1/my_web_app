import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/domain/models/toeic_practice.dart';
import 'package:my_web_app/domain/use_cases/build_toeic_dashboard_snapshot_use_case.dart';

void main() {
  const useCase = BuildToeicDashboardSnapshotUseCase();

  test('derives streak, today completion, and weakest practiced part', () {
    final snapshot = useCase(
      progress: const ToeicProgress(
        targetScore: 730,
        totalAnswered: 14,
        totalCorrect: 10,
        answeredByPart: <ToeicPart, int>{
          ToeicPart.part5: 10,
          ToeicPart.part6: 4,
        },
        correctByPart: <ToeicPart, int>{ToeicPart.part5: 8, ToeicPart.part6: 2},
        practiceDateKeys: <String>{'2026-08-22', '2026-08-23'},
      ),
      today: DateTime(2026, 8, 23, 20),
    );

    expect(snapshot.currentStreak, 2);
    expect(snapshot.todayCompleted, isTrue);
    expect(snapshot.recommendedPart, ToeicPart.part6);
  });

  test('recommends Part 5 before the first practice session', () {
    final snapshot = useCase(
      progress: ToeicProgress.initial(),
      today: DateTime(2026, 8, 23),
    );

    expect(snapshot.currentStreak, 0);
    expect(snapshot.todayCompleted, isFalse);
    expect(snapshot.recommendedPart, ToeicPart.part5);
  });
}
