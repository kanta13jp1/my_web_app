import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/ai_university_learning_outcome_analytics.dart';

void main() {
  test('view and completion events use a fixed no-text contract', () async {
    final rows = <Map<String, Object>>[];
    final analytics = AiUniversityLearningOutcomeAnalytics(
      writer: (row) async => rows.add(row),
    );

    expect(await analytics.recordViewed(), isTrue);
    expect(
      await analytics.recordCompleted(correctAnswers: 2, selfRating: 4),
      isTrue,
    );

    expect(rows, hasLength(2));
    expect(rows.first, <String, Object>{
      'event_name': 'task_viewed',
      'task_version': '01ai_latest_20260828_v1',
      'provider': '01ai',
      'category': 'news',
    });
    expect(rows.last, <String, Object>{
      'event_name': 'task_completed',
      'task_version': '01ai_latest_20260828_v1',
      'provider': '01ai',
      'category': 'news',
      'correct_answers': 2,
      'total_questions': 3,
      'self_rating': 4,
    });
    for (final row in rows) {
      expect(
        row.keys,
        everyElement(
          AiUniversityLearningOutcomeAnalytics.allowedPropertyNames.contains,
        ),
      );
    }
  });

  test('out-of-range aggregates are rejected before writing', () async {
    var writes = 0;
    final analytics = AiUniversityLearningOutcomeAnalytics(
      writer: (_) async => writes += 1,
    );

    expect(
      await analytics.recordCompleted(correctAnswers: 4, selfRating: 3),
      isFalse,
    );
    expect(
      await analytics.recordCompleted(correctAnswers: 1, selfRating: 0),
      isFalse,
    );
    expect(writes, 0);
  });

  test('model-selection task uses its fixed category and version', () async {
    final rows = <Map<String, Object>>[];
    final analytics = AiUniversityLearningOutcomeAnalytics(
      task: AiUniversityLearningOutcomeTask.modelSelection,
      writer: (row) async => rows.add(row),
    );

    expect(await analytics.recordViewed(), isTrue);
    expect(
      await analytics.recordCompleted(correctAnswers: 3, selfRating: 5),
      isTrue,
    );

    expect(rows.first, <String, Object>{
      'event_name': 'task_viewed',
      'task_version': '01ai_models_20260829_v1',
      'provider': '01ai',
      'category': 'models',
    });
    expect(rows.last['correct_answers'], 3);
    expect(rows.last['total_questions'], 3);
    expect(rows.last['self_rating'], 5);
  });
}
