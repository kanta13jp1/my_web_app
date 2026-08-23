import '../../domain/models/guitar_daily_course.dart';
import '../models/guitar_daily_course_model.dart';
import '../services/guitar_course_progress_service.dart';
import '../services/guitar_daily_course_catalog_service.dart';

abstract interface class GuitarCourseRepository {
  Future<List<GuitarCourseDay>> getCourse();

  Future<GuitarCourseProgress> getProgress();

  Future<GuitarCourseProgress> setTaskCompleted({
    required int dayNumber,
    required String taskId,
    required bool completed,
  });

  Future<GuitarCourseProgress> completeDay({
    required int dayNumber,
    required DateTime completedAt,
  });
}

class LocalGuitarCourseRepository implements GuitarCourseRepository {
  const LocalGuitarCourseRepository({
    required this.catalogService,
    required this.progressService,
  });

  final GuitarDailyCourseCatalogService catalogService;
  final GuitarCourseProgressService progressService;

  @override
  Future<List<GuitarCourseDay>> getCourse() async {
    final models = await catalogService.loadCourse();
    return List<GuitarCourseDay>.unmodifiable(models.map(_toDomainDay));
  }

  @override
  Future<GuitarCourseProgress> getProgress() async {
    return _toDomainProgress(await progressService.load());
  }

  @override
  Future<GuitarCourseProgress> setTaskCompleted({
    required int dayNumber,
    required String taskId,
    required bool completed,
  }) async {
    final course = await getCourse();
    final day = _findDay(course, dayNumber);
    if (!day.tasks.any((task) => task.id == taskId)) {
      throw ArgumentError.value(
        taskId,
        'taskId',
        'Task does not belong to day',
      );
    }

    final current = await progressService.load();
    if (current.completedDayNumbers.contains(dayNumber)) {
      return _toDomainProgress(current);
    }

    final taskIds = current.completedTaskIds.toSet();
    if (completed) {
      taskIds.add(taskId);
    } else {
      taskIds.remove(taskId);
    }

    final next = GuitarCourseProgressModel(
      completedTaskIds: taskIds.toList(growable: false)..sort(),
      completedDayNumbers: current.completedDayNumbers,
      practiceDateKeys: current.practiceDateKeys,
    );
    await progressService.save(next);
    return _toDomainProgress(next);
  }

  @override
  Future<GuitarCourseProgress> completeDay({
    required int dayNumber,
    required DateTime completedAt,
  }) async {
    final course = await getCourse();
    final day = _findDay(course, dayNumber);
    final current = await progressService.load();
    if (current.completedDayNumbers.contains(dayNumber)) {
      return _toDomainProgress(current);
    }

    final expectedDay = course.firstWhere(
      (candidate) => !current.completedDayNumbers.contains(candidate.dayNumber),
      orElse: () => day,
    );
    if (expectedDay.dayNumber != dayNumber) {
      throw StateError('Complete the current course day before day $dayNumber');
    }
    if (!day.tasks.every(
      (task) => current.completedTaskIds.contains(task.id),
    )) {
      throw StateError('Complete every task before finishing day $dayNumber');
    }

    final completedDays = current.completedDayNumbers.toSet()..add(dayNumber);
    final practiceDates = current.practiceDateKeys.toSet()
      ..add(_dateKey(completedAt));
    final next = GuitarCourseProgressModel(
      completedTaskIds: current.completedTaskIds,
      completedDayNumbers: completedDays.toList(growable: false)..sort(),
      practiceDateKeys: practiceDates.toList(growable: false)..sort(),
    );
    await progressService.save(next);
    return _toDomainProgress(next);
  }

  GuitarCourseDay _findDay(List<GuitarCourseDay> course, int dayNumber) {
    for (final day in course) {
      if (day.dayNumber == dayNumber) return day;
    }
    throw ArgumentError.value(dayNumber, 'dayNumber', 'Unknown course day');
  }

  GuitarCourseDay _toDomainDay(GuitarCourseDayModel model) {
    return GuitarCourseDay(
      dayNumber: model.dayNumber,
      phase: _parsePhase(model.phase),
      title: model.title,
      objective: model.objective,
      coachNote: model.coachNote,
      recommendedBpm: model.recommendedBpm,
      relatedSongId: model.relatedSongId,
      tasks: List<GuitarDailyTask>.unmodifiable(
        model.tasks.map(
          (task) => GuitarDailyTask(
            id: task.id,
            title: task.title,
            instruction: task.instruction,
            completionCriteria: task.completionCriteria,
            minutes: task.minutes,
          ),
        ),
      ),
    );
  }

  GuitarCourseProgress _toDomainProgress(GuitarCourseProgressModel model) {
    return GuitarCourseProgress(
      completedTaskIds: model.completedTaskIds,
      completedDayNumbers: model.completedDayNumbers,
      practiceDateKeys: model.practiceDateKeys,
    );
  }

  GuitarCoursePhase _parsePhase(String raw) {
    return switch (raw) {
      'foundation' => GuitarCoursePhase.foundation,
      'rhythm' => GuitarCoursePhase.rhythm,
      'fingerstyle' => GuitarCoursePhase.fingerstyle,
      'performance' => GuitarCoursePhase.performance,
      _ => throw FormatException('Unknown guitar course phase: $raw'),
    };
  }

  String _dateKey(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}
