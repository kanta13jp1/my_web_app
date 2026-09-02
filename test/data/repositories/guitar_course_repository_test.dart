import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/data/models/guitar_daily_course_model.dart';
import 'package:my_web_app/data/repositories/guitar_course_repository.dart';
import 'package:my_web_app/data/services/guitar_course_progress_service.dart';
import 'package:my_web_app/data/services/guitar_daily_course_catalog_service.dart';
import 'package:my_web_app/domain/models/guitar_daily_course.dart';

void main() {
  group('LocalGuitarCourseRepository', () {
    late _MemoryProgressService progressService;
    late LocalGuitarCourseRepository repository;

    setUp(() {
      progressService = _MemoryProgressService();
      repository = LocalGuitarCourseRepository(
        catalogService: const GuitarDailyCourseCatalogService(),
        progressService: progressService,
      );
    });

    test(
      'maps a progressive 14-day course with unique concrete tasks',
      () async {
        final course = await repository.getCourse();

        expect(course, hasLength(14));
        expect(course.first.phase, GuitarCoursePhase.foundation);
        expect(course.last.phase, GuitarCoursePhase.performance);
        expect(course.expand((day) => day.tasks), hasLength(42));
        expect(
          course.expand((day) => day.tasks).map((task) => task.id).toSet(),
          hasLength(42),
        );
        expect(course.every((day) => day.tasks.length == 3), isTrue);
        expect(
          course.every(
            (day) => day.tasks.every(
              (task) => task.completionCriteria.trim().isNotEmpty,
            ),
          ),
          isTrue,
        );
      },
    );

    test('requires every current-day task before completing the day', () async {
      await expectLater(
        repository.completeDay(
          dayNumber: 1,
          completedAt: DateTime(2026, 8, 13),
        ),
        throwsStateError,
      );

      final firstDay = (await repository.getCourse()).first;
      for (final task in firstDay.tasks) {
        await repository.setTaskCompleted(
          dayNumber: firstDay.dayNumber,
          taskId: task.id,
          completed: true,
        );
      }
      final progress = await repository.completeDay(
        dayNumber: 1,
        completedAt: DateTime(2026, 8, 13),
      );

      expect(progress.completedDayNumbers, <int>{1});
      expect(progress.practiceDateKeys, <String>{'2026-08-13'});
    });

    test(
      'does not allow a later day to be completed out of sequence',
      () async {
        final secondDay = (await repository.getCourse())[1];
        for (final task in secondDay.tasks) {
          await repository.setTaskCompleted(
            dayNumber: secondDay.dayNumber,
            taskId: task.id,
            completed: true,
          );
        }

        await expectLater(
          repository.completeDay(
            dayNumber: 2,
            completedAt: DateTime(2026, 8, 13),
          ),
          throwsStateError,
        );
      },
    );
  });
}

class _MemoryProgressService implements GuitarCourseProgressService {
  GuitarCourseProgressModel value = const GuitarCourseProgressModel();

  @override
  Future<GuitarCourseProgressModel> load() async => value;

  @override
  Future<void> save(GuitarCourseProgressModel progress) async {
    value = progress;
  }
}
