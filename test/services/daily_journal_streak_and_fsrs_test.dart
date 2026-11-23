import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/daily_journal_entry.dart';
import 'package:my_web_app/services/ai_fsrs_service.dart';
import 'package:my_web_app/services/daily_journal_streak_service.dart';
import 'package:my_web_app/services/fsrs_scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('DailyJournalStreakService (#2778)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(const <String, Object>{});
    });

    test(
        'auto-generates daily journal entry and updates streak profile across consecutive days and gaps',
        () async {
      const service = DailyJournalStreakService();

      final day1 = await service.recordTaskCompletion(
        taskTitle: 'タスクA',
        now: DateTime.utc(2026, 11, 20, 9, 0),
      );
      expect(day1.profile.currentStreak, 1);
      expect(day1.profile.longestStreak, 1);
      expect(day1.profile.toProfileJson()['current_streak'], 1);
      expect(day1.entry.dateKey, '2026-11-20');

      // Same day second completion keeps currentStreak == 1, increments totalCompletedTasks.
      final sameDay = await service.recordTaskCompletion(
        taskTitle: 'タスクB',
        now: DateTime.utc(2026, 11, 20, 18, 0),
      );
      expect(sameDay.profile.currentStreak, 1);
      expect(sameDay.profile.totalCompletedTasks, 2);

      // Next consecutive day increments streak -> 2.
      final day2 = await service.recordTaskCompletion(
        taskTitle: 'タスクC',
        now: DateTime.utc(2026, 11, 21, 10, 0),
      );
      expect(day2.profile.currentStreak, 2);
      expect(day2.profile.longestStreak, 2);

      // 2-day gap resets currentStreak to 1 while retaining longestStreak == 2.
      final afterGap = await service.recordTaskCompletion(
        taskTitle: 'タスクD',
        now: DateTime.utc(2026, 11, 24, 10, 0),
      );
      expect(afterGap.profile.currentStreak, 1);
      expect(afterGap.profile.longestStreak, 2);

      final entries = await service.loadEntries();
      expect(entries.length, 4);
      expect(entries.first.taskTitle, 'タスクD');
    });
  });

  group('FsrsScheduler & AiFsrsService (#1386)', () {
    test(
        'computes FSRS v4.5 retrievability R(S,S)=0.90, response-speed adjustment, and lapse drop',
        () {
      final rAtStability = FsrsScheduler.computeRetrievability(
        elapsedDays: 10.0,
        stability: 10.0,
      );
      expect(rAtStability, closeTo(0.9, 0.001));

      final now = DateTime.utc(2026, 11, 24, 0, 0);
      final baseCard = FsrsCardState(
        questionId: 'q_1',
        provider: 'gemini',
        stability: 4.0,
        difficulty: 5.0,
        reps: 2,
        lastReview: now.subtract(const Duration(days: 4)),
        dueDate: now,
        state: 'review',
      );

      final fastEasy = FsrsScheduler.scheduleNext(
        baseCard,
        grade: 4,
        elapsedMs: 2500,
        isCorrect: true,
        now: now,
      );
      final slowGood = FsrsScheduler.scheduleNext(
        baseCard,
        grade: 3,
        elapsedMs: 25000,
        isCorrect: true,
        now: now,
      );
      expect(fastEasy.stability, greaterThan(slowGood.stability));
      expect(fastEasy.scheduledDays, greaterThan(slowGood.scheduledDays));
      expect(fastEasy.difficulty, lessThan(5.0));

      final lapsed = FsrsScheduler.scheduleNext(
        baseCard,
        grade: 1,
        elapsedMs: 12000,
        isCorrect: false,
        now: now,
      );
      expect(lapsed.stability, lessThan(baseCard.stability));
      expect(lapsed.scheduledDays, 1);
      expect(lapsed.nextCard.state, 'relearning');
      expect(lapsed.nextCard.lapses, 1);
    });

    test('prioritizes overdue cards ahead of future cards in Practice Queue',
        () {
      final now = DateTime.utc(2026, 11, 24, 12, 0);
      final future = FsrsCardState(
        questionId: 'q_future',
        provider: 'gemini',
        dueDate: now.add(const Duration(days: 2)),
      );
      final overdueNewest = FsrsCardState(
        questionId: 'q_overdue_recent',
        provider: 'gemini',
        dueDate: now.subtract(const Duration(hours: 2)),
      );
      final overdueOldest = FsrsCardState(
        questionId: 'q_overdue_oldest',
        provider: 'gemini',
        dueDate: now.subtract(const Duration(days: 3)),
      );

      final sorted = FsrsScheduler.sortPracticeQueue(
        <FsrsCardState>[future, overdueNewest, overdueOldest],
        now: now,
      );
      expect(
        sorted.map((c) => c.questionId).toList(),
        const <String>['q_overdue_oldest', 'q_overdue_recent', 'q_future'],
      );

      final service = AiFsrsService();
      final outcome = service.gradeCardLocal(
        overdueOldest,
        grade: 3,
        elapsedMs: 3200,
        isCorrect: true,
        now: now,
      );
      expect(outcome.nextDue.isAfter(now), isTrue);
      expect(outcome.nextCard.lastElapsedMs, 3200);
    });
  });
}
