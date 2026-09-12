import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/ai_university_entry_funnel_analytics.dart';

void main() {
  group('AiUniversityEntryFunnelAnalytics', () {
    test('tracks discovery selection and lesson start events', () {
      final events = <Map<String, dynamic>>[];
      final analytics = AiUniversityEntryFunnelAnalytics(
        onTrack: (name, props) {
          events.add(<String, dynamic>{'event': name, ...props});
        },
      );

      analytics.trackDiscoveryPathSelected(
        pathType: 'recommended_starter',
        targetProvider: 'gemini',
      );
      analytics.trackLessonStarted(
        provider: 'gemini',
        category: 'overview',
        isFirstTime: true,
      );

      expect(events.length, 2);
      expect(events[0]['event'], 'ai_university_discovery_selected');
      expect(events[0]['path_type'], 'recommended_starter');
      expect(events[0]['target_provider'], 'gemini');

      expect(events[1]['event'], 'ai_university_lesson_started');
      expect(events[1]['provider'], 'gemini');
      expect(events[1]['category'], 'overview');
      expect(events[1]['is_first_time'], true);
    });

    test('tracks lesson completion and repeat learning events', () {
      final events = <Map<String, dynamic>>[];
      final analytics = AiUniversityEntryFunnelAnalytics(
        onTrack: (name, props) {
          events.add(<String, dynamic>{'event': name, ...props});
        },
      );

      analytics.trackLessonCompleted(
        provider: 'anthropic',
        category: 'models',
        durationSeconds: 195,
      );
      analytics.trackRepeatLearning(
        streakDays: 7,
        completedLessonsCount: 14,
      );

      expect(events.length, 2);
      expect(events[0]['event'], 'ai_university_lesson_completed');
      expect(events[0]['duration_bucket_seconds'], 180);

      expect(events[1]['event'], 'ai_university_repeat_learning');
      expect(events[1]['streak_days'], 7);
      expect(events[1]['completed_lessons_bucket'], 10);
    });
  });
}
