enum GuitarCoursePhase { foundation, rhythm, fingerstyle, performance }

class GuitarDailyTask {
  const GuitarDailyTask({
    required this.id,
    required this.title,
    required this.instruction,
    required this.completionCriteria,
    required this.minutes,
  });

  final String id;
  final String title;
  final String instruction;
  final String completionCriteria;
  final int minutes;
}

class GuitarCourseDay {
  const GuitarCourseDay({
    required this.dayNumber,
    required this.phase,
    required this.title,
    required this.objective,
    required this.coachNote,
    required this.recommendedBpm,
    required this.tasks,
    this.relatedSongId,
  });

  final int dayNumber;
  final GuitarCoursePhase phase;
  final String title;
  final String objective;
  final String coachNote;
  final int recommendedBpm;
  final List<GuitarDailyTask> tasks;
  final String? relatedSongId;

  int get totalMinutes => tasks.fold<int>(0, (sum, task) => sum + task.minutes);
}

class GuitarCourseProgress {
  GuitarCourseProgress({
    Iterable<String> completedTaskIds = const <String>[],
    Iterable<int> completedDayNumbers = const <int>[],
    Iterable<String> practiceDateKeys = const <String>[],
  })  : completedTaskIds = Set<String>.unmodifiable(completedTaskIds),
        completedDayNumbers = Set<int>.unmodifiable(completedDayNumbers),
        practiceDateKeys = Set<String>.unmodifiable(practiceDateKeys);

  final Set<String> completedTaskIds;
  final Set<int> completedDayNumbers;
  final Set<String> practiceDateKeys;
}

class GuitarCourseSnapshot {
  GuitarCourseSnapshot({
    required List<GuitarCourseDay> days,
    required this.progress,
    required this.currentDay,
    required this.currentStreak,
  }) : days = List<GuitarCourseDay>.unmodifiable(days);

  final List<GuitarCourseDay> days;
  final GuitarCourseProgress progress;
  final GuitarCourseDay? currentDay;
  final int currentStreak;

  int get completedDayCount => progress.completedDayNumbers.length;
  int get totalDayCount => days.length;
  bool get isCourseCompleted => days.isNotEmpty && currentDay == null;

  int get completedCurrentTaskCount {
    final day = currentDay;
    if (day == null) return 0;
    return day.tasks
        .where((task) => progress.completedTaskIds.contains(task.id))
        .length;
  }

  bool get canCompleteCurrentDay {
    final day = currentDay;
    return day != null &&
        day.tasks.isNotEmpty &&
        day.tasks.every((task) => progress.completedTaskIds.contains(task.id));
  }

  double get courseProgress {
    if (days.isEmpty) return 0;
    return completedDayCount / days.length;
  }
}
