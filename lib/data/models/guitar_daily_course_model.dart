class GuitarDailyTaskModel {
  const GuitarDailyTaskModel({
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

class GuitarCourseDayModel {
  const GuitarCourseDayModel({
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
  final String phase;
  final String title;
  final String objective;
  final String coachNote;
  final int recommendedBpm;
  final List<GuitarDailyTaskModel> tasks;
  final String? relatedSongId;
}

class GuitarCourseProgressModel {
  const GuitarCourseProgressModel({
    this.completedTaskIds = const <String>[],
    this.completedDayNumbers = const <int>[],
    this.practiceDateKeys = const <String>[],
  });

  final List<String> completedTaskIds;
  final List<int> completedDayNumbers;
  final List<String> practiceDateKeys;
}
