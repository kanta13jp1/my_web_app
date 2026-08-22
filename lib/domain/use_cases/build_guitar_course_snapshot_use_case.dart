import '../models/guitar_daily_course.dart';

class BuildGuitarCourseSnapshotUseCase {
  const BuildGuitarCourseSnapshotUseCase();

  GuitarCourseSnapshot call({
    required List<GuitarCourseDay> days,
    required GuitarCourseProgress progress,
    required DateTime today,
  }) {
    GuitarCourseDay? currentDay;
    for (final day in days) {
      if (!progress.completedDayNumbers.contains(day.dayNumber)) {
        currentDay = day;
        break;
      }
    }

    return GuitarCourseSnapshot(
      days: days,
      progress: progress,
      currentDay: currentDay,
      currentStreak: _calculateStreak(progress.practiceDateKeys, today),
    );
  }

  int _calculateStreak(Set<String> practicedDates, DateTime today) {
    if (practicedDates.isEmpty) return 0;

    var cursor = DateTime(today.year, today.month, today.day);
    if (!practicedDates.contains(_dateKey(cursor))) {
      cursor = cursor.subtract(const Duration(days: 1));
    }

    var streak = 0;
    while (practicedDates.contains(_dateKey(cursor))) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  String _dateKey(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}
