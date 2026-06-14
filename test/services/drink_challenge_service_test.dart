import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/drink_challenge_service.dart';

void main() {
  group('DrinkChallengeService', () {
    const service = DrinkChallengeService();

    test('detects weekend nights as drinking occasions', () {
      // 2026-06-19=金, 20=土, 21=日, 22=月。
      final occasions = service.occasionsBetween(
        DateTime(2026, 6, 19),
        DateTime(2026, 6, 22),
      );
      expect(occasions.map((o) => o.date.day), [19, 20, 21]);
      expect(
        occasions[0].reasons,
        contains(DrinkOccasionReason.fridayNight),
      );
      expect(
        occasions[2].reasons,
        contains(DrinkOccasionReason.sundayNight),
      );
    });

    test('detects holidays and holiday eves', () {
      // 2026-07-20=海の日(月/祝)。前日 7-19=日(祝前日でもある)。
      final occasions = service.occasionsBetween(
        DateTime(2026, 7, 18),
        DateTime(2026, 7, 20),
      );
      final byDay = {for (final o in occasions) o.date.day: o};
      expect(byDay.containsKey(20), isTrue);
      expect(byDay[20]!.reasons, contains(DrinkOccasionReason.holiday));
      expect(byDay[19]!.reasons, contains(DrinkOccasionReason.holidayEve));
      expect(byDay[19]!.reasons, contains(DrinkOccasionReason.sundayNight));
      // 7-18=土。
      expect(byDay[18]!.reasons, contains(DrinkOccasionReason.saturdayNight));
    });

    test('isHoliday matches the 2026 substitute and national holidays', () {
      expect(service.isHoliday(DateTime(2026, 5, 6)), isTrue); // 振替休日
      expect(service.isHoliday(DateTime(2026, 9, 22)), isTrue); // 国民の休日
      expect(service.isHoliday(DateTime(2026, 6, 15)), isFalse);
    });

    test('computes saved amount and progress from records', () {
      final records = <String, DrinkRecordStatus>{
        '2026-06-19': DrinkRecordStatus.abstained,
        '2026-06-20': DrinkRecordStatus.abstained,
        '2026-06-21': DrinkRecordStatus.drank,
      };
      final stats = service.computeStats(
        records: records,
        totalDebtYen: -7000000,
        baseDate: DateTime(2026, 6, 22),
      );
      expect(stats.abstainedCount, 2);
      expect(stats.drankCount, 1);
      expect(stats.targetCount, 700);
      expect(stats.perSessionYen, 10000); // 7,000,000 / 700
      expect(stats.savedYen, 20000); // 2 × 10,000
      expect(stats.remainingCount, 698);
      expect(stats.abstentionRate, closeTo(2 / 3, 0.001));
      expect(stats.progressRatio, closeTo(2 / 700, 0.0001));
      expect(stats.projectedCompletionDate, isNotNull);
    });

    test('projects completion today when target is reached', () {
      final records = <String, DrinkRecordStatus>{
        for (var i = 0; i < 700; i++) 'rec_$i': DrinkRecordStatus.abstained,
      };
      final stats = service.computeStats(
        records: records,
        totalDebtYen: -7000000,
        baseDate: DateTime(2026, 6, 22),
      );
      expect(stats.remainingCount, 0);
      expect(stats.progressRatio, 1.0);
      expect(stats.projectedCompletionDate, DateTime(2026, 6, 22));
    });

    test('handles empty records without dividing by zero', () {
      final stats = service.computeStats(
        records: const <String, DrinkRecordStatus>{},
        totalDebtYen: -7000000,
        baseDate: DateTime(2026, 6, 22),
      );
      expect(stats.abstainedCount, 0);
      expect(stats.savedYen, 0);
      expect(stats.abstentionRate, 0);
      expect(stats.remainingCount, 700);
    });
  });
}
