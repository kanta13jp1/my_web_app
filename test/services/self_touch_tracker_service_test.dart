import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/self_touch_tracker_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('recordEvent stores touch events and aggregates daily and weekly counts',
      () async {
    const service = SelfTouchTrackerService();
    final prefs = await SharedPreferences.getInstance();

    var snapshot = await service.recordEvent(
      trigger: 'stuck',
      intensity: 3,
      prefs: prefs,
      now: DateTime(2026, 5, 1, 10),
    );
    snapshot = await service.recordEvent(
      trigger: 'word_search',
      intensity: 4,
      note: 'meeting memo',
      prefs: prefs,
      now: DateTime(2026, 5, 2, 9),
    );

    expect(snapshot.events, hasLength(2));
    expect(snapshot.events.first.trigger, 'word_search');
    expect(snapshot.stats.todayCount, 1);
    expect(snapshot.stats.last7DaysCount, 2);

    final daily = service.dailyBuckets(
      stats: snapshot.stats,
      now: DateTime(2026, 5, 2, 12),
    );
    expect(daily.last.count, 1);
    expect(daily[daily.length - 2].count, 1);

    final weekly = service.weeklyBuckets(
      stats: snapshot.stats,
      now: DateTime(2026, 5, 2, 12),
    );
    expect(weekly.last.count, 2);
  });

  test('replacement prompt turns on after repeated events in thirty minutes',
      () async {
    const service = SelfTouchTrackerService();
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime(2026, 5, 2, 14);

    for (var i = 0; i < 3; i += 1) {
      await service.recordEvent(
        trigger: 'stress',
        intensity: 4,
        prefs: prefs,
        now: now.add(Duration(minutes: i * 8)),
      );
    }

    final snapshot = await service.loadSnapshot(
      prefs: prefs,
      now: now.add(const Duration(minutes: 20)),
    );

    expect(snapshot.stats.last30MinutesCount, 3);
    expect(snapshot.stats.shouldPromptReplacement, isTrue);

    final plans = service.replacementPlans(trigger: 'stress', intensity: 4);
    expect(plans.first.title, contains('リセット'));
    expect(
      plans.expand((plan) => plan.steps),
      contains('ペン、ストレスボール、タオルのどれかを片手で持つ'),
    );
  });

  test('deleteEvent removes only the selected record', () async {
    const service = SelfTouchTrackerService();
    final prefs = await SharedPreferences.getInstance();

    var snapshot = await service.recordEvent(
      trigger: 'boredom',
      intensity: 2,
      prefs: prefs,
      now: DateTime(2026, 5, 2, 10),
    );
    snapshot = await service.recordEvent(
      trigger: 'focus',
      intensity: 1,
      prefs: prefs,
      now: DateTime(2026, 5, 2, 11),
    );

    final remaining = await service.deleteEvent(
      id: snapshot.events.first.id,
      prefs: prefs,
      now: DateTime(2026, 5, 2, 12),
    );

    expect(remaining.events, hasLength(1));
    expect(remaining.events.single.trigger, 'boredom');
    expect(remaining.stats.todayCount, 1);
  });
}
