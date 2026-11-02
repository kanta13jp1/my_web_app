import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/ai_university_fuyu_lab_analytics.dart';

void main() {
  test('start and completion emit only bounded anonymous fields', () async {
    final rows = <Map<String, Object>>[];
    final analytics = AiUniversityFuyuLabAnalytics(
      writer: (row) async => rows.add(row),
    );

    expect(await analytics.recordStarted(), isTrue);
    expect(
      await analytics.recordCompleted(
        const AiUniversityFuyuLabCompletion(
          attemptOutcome: 'success_after_error',
          completionSeconds: 321,
          rubricScore: 4,
        ),
      ),
      isTrue,
    );

    expect(rows.first, <String, Object>{
      'event_name': 'lab_started',
      'task_version': 'adept_fuyu_model_card_20260830_v1',
    });
    expect(rows.last['task_mode'], 'inference');
    expect(rows.last['attempt_outcome'], 'success_after_error');
    expect(rows.last['completion_seconds'], 321);
    expect(rows.last['rubric_score'], 4);
    expect(
      rows.last.keys,
      everyElement(AiUniversityFuyuLabAnalytics.allowedPropertyNames.contains),
    );
    for (final prohibited in <String>[
      'user_id',
      'session_id',
      'ip_address',
      'url',
      'prompt',
      'generated_text',
      'error_text',
      'free_text',
    ]) {
      expect(rows.last, isNot(contains(prohibited)));
    }
  });

  test('reading completion derives the fallback mode', () async {
    final rows = <Map<String, Object>>[];
    final analytics = AiUniversityFuyuLabAnalytics(
      writer: (row) async => rows.add(row),
    );

    expect(
      await analytics.recordCompleted(
        const AiUniversityFuyuLabCompletion(
          attemptOutcome: 'reading_completed',
          completionSeconds: 600,
          rubricScore: 3,
        ),
      ),
      isTrue,
    );
    expect(rows.single['task_mode'], 'reading_fallback');
  });

  test('invalid enum and numeric ranges never write', () async {
    var writes = 0;
    final analytics = AiUniversityFuyuLabAnalytics(
      writer: (_) async => writes += 1,
    );
    final invalid = <AiUniversityFuyuLabCompletion>[
      const AiUniversityFuyuLabCompletion(
        attemptOutcome: 'unknown',
        completionSeconds: 1,
        rubricScore: 4,
      ),
      const AiUniversityFuyuLabCompletion(
        attemptOutcome: 'first_try_success',
        completionSeconds: 0,
        rubricScore: 4,
      ),
      const AiUniversityFuyuLabCompletion(
        attemptOutcome: 'first_try_success',
        completionSeconds: 86401,
        rubricScore: 4,
      ),
      const AiUniversityFuyuLabCompletion(
        attemptOutcome: 'first_try_success',
        completionSeconds: 60,
        rubricScore: 5,
      ),
    ];

    for (final completion in invalid) {
      expect(await analytics.recordCompleted(completion), isFalse);
    }
    expect(writes, 0);
  });

  test('writer failure is swallowed and reported as not recorded', () async {
    final analytics = AiUniversityFuyuLabAnalytics(
      writer: (_) async => throw StateError('offline'),
    );

    expect(await analytics.recordStarted(), isFalse);
    expect(
      await analytics.recordCompleted(
        const AiUniversityFuyuLabCompletion(
          attemptOutcome: 'first_try_success',
          completionSeconds: 60,
          rubricScore: 4,
        ),
      ),
      isFalse,
    );
  });
}
