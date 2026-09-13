import '../models/toeic_practice.dart';

class BuildToeicDashboardSnapshotUseCase {
  const BuildToeicDashboardSnapshotUseCase();

  ToeicDashboardSnapshot call({
    required ToeicProgress progress,
    required DateTime today,
  }) {
    return ToeicDashboardSnapshot(
      progress: progress,
      currentStreak: _calculateStreak(progress.practiceDateKeys, today),
      todayCompleted: progress.practiceDateKeys.contains(_dateKey(today)),
      recommendedPart: _recommendedPart(progress),
    );
  }

  ToeicPart _recommendedPart(ToeicProgress progress) {
    final practiced = ToeicPart.values.where(
      (part) => (progress.answeredByPart[part] ?? 0) > 0,
    );
    if (practiced.isEmpty) return ToeicPart.part5;

    var weakest = practiced.first;
    for (final part in practiced.skip(1)) {
      if (progress.accuracyFor(part) < progress.accuracyFor(weakest)) {
        weakest = part;
      }
    }
    return weakest;
  }

  int _calculateStreak(Set<String> practiceDateKeys, DateTime today) {
    if (practiceDateKeys.isEmpty) return 0;
    var cursor = DateTime(today.year, today.month, today.day);
    if (!practiceDateKeys.contains(_dateKey(cursor))) {
      cursor = cursor.subtract(const Duration(days: 1));
    }

    var streak = 0;
    while (practiceDateKeys.contains(_dateKey(cursor))) {
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
