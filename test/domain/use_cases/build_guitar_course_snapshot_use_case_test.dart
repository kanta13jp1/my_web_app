import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/domain/models/guitar_daily_course.dart';
import 'package:my_web_app/domain/use_cases/build_guitar_course_snapshot_use_case.dart';

void main() {
  const useCase = BuildGuitarCourseSnapshotUseCase();
  const tasks = <GuitarDailyTask>[
    GuitarDailyTask(
      id: 'task-1',
      title: 'Task 1',
      instruction: 'Practice',
      completionCriteria: 'Done',
      minutes: 5,
    ),
  ];
  const days = <GuitarCourseDay>[
    GuitarCourseDay(
      dayNumber: 1,
      phase: GuitarCoursePhase.foundation,
      title: 'Day 1',
      objective: 'Start',
      coachNote: 'Slowly',
      recommendedBpm: 60,
      tasks: tasks,
    ),
    GuitarCourseDay(
      dayNumber: 2,
      phase: GuitarCoursePhase.rhythm,
      title: 'Day 2',
      objective: 'Continue',
      coachNote: 'Steady',
      recommendedBpm: 64,
      tasks: tasks,
    ),
  ];

  test('selects the first incomplete day and calculates a current streak', () {
    final snapshot = useCase(
      days: days,
      progress: GuitarCourseProgress(
        completedTaskIds: const <String>['task-1'],
        completedDayNumbers: const <int>[1],
        practiceDateKeys: const <String>[
          '2026-08-11',
          '2026-08-12',
          '2026-08-13',
        ],
      ),
      today: DateTime(2026, 8, 13),
    );

    expect(snapshot.currentDay?.dayNumber, 2);
    expect(snapshot.completedDayCount, 1);
    expect(snapshot.currentStreak, 3);
    expect(snapshot.courseProgress, 0.5);
  });

  test('keeps a streak when the latest practice was yesterday', () {
    final snapshot = useCase(
      days: days,
      progress: GuitarCourseProgress(
        practiceDateKeys: const <String>['2026-08-11', '2026-08-12'],
      ),
      today: DateTime(2026, 8, 13),
    );

    expect(snapshot.currentStreak, 2);
  });
}
