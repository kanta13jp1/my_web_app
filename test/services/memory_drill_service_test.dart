import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/memory_drill_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('markCompleted stores today count and streak', () async {
    final service = MemoryDrillService();

    var stats = await service.markCompleted(
      'countries_10',
      now: DateTime(2026, 3, 22, 9),
    );
    expect(stats.completedTodayCount, 1);
    expect(stats.currentStreak, 1);
    expect(stats.isCompletedToday('countries_10'), isTrue);

    stats = await service.markCompleted(
      'countries_10',
      now: DateTime(2026, 3, 22, 18),
    );
    expect(stats.completedTodayCount, 1);
    expect(stats.currentStreak, 1);

    stats = await service.markCompleted(
      'beatles_songs_10',
      now: DateTime(2026, 3, 23, 8),
    );
    expect(stats.completedTodayCount, 1);
    expect(stats.currentStreak, 2);
    expect(stats.isCompletedToday('beatles_songs_10'), isTrue);
  });
}
