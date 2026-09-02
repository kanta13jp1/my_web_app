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

  test('LLM mechanics task uses its fixed academic identity', () async {
    final rows = <Map<String, Object>>[];
    final analytics = AiUniversityLearningOutcomeAnalytics(
      task: AiUniversityLearningOutcomeTask.llmMechanics,
      writer: (row) async => rows.add(row),
    );

    expect(await analytics.recordViewed(), isTrue);
    expect(
      await analytics.recordCompleted(correctAnswers: 2, selfRating: 4),
      isTrue,
    );

    expect(rows.first, <String, Object>{
      'event_name': 'task_viewed',
      'task_version': 'academic_llm_mechanics_20260829_v1',
      'provider': 'academic',
      'category': 'llm_mechanics',
    });
    expect(rows.last['correct_answers'], 2);
    expect(rows.last['total_questions'], 3);
    expect(rows.last['self_rating'], 4);
  });

  test('Firefly API task records only bounded role-level metrics', () async {
    final rows = <Map<String, Object>>[];
    final analytics = AiUniversityLearningOutcomeAnalytics(
      task: AiUniversityLearningOutcomeTask.fireflyApi,
      writer: (row) async => rows.add(row),
    );

    expect(await analytics.recordViewed(), isTrue);
    expect(
      await analytics.recordFireflyCompleted(
        correctAnswers: 3,
        selfRating: 4,
        learnerRole: 'developer',
        firstCallSucceeded: true,
        secretHandlingPassed: true,
        apiSelectionPassed: true,
        non2xxRecoveryPassed: true,
        estimatedDailyRequests: 500,
        completionSeconds: 420,
      ),
      isTrue,
    );

    expect(rows.first, <String, Object>{
      'event_name': 'task_viewed',
      'task_version': 'adobe_firefly_api_20260831_v1',
      'provider': 'adobe_firefly',
      'category': 'api',
    });
    expect(rows.last, <String, Object>{
      'event_name': 'task_completed',
      'task_version': 'adobe_firefly_api_20260831_v1',
      'provider': 'adobe_firefly',
      'category': 'api',
      'correct_answers': 3,
      'total_questions': 3,
      'self_rating': 4,
      'learner_role': 'developer',
      'first_call_succeeded': true,
      'secret_handling_passed': true,
      'api_selection_passed': true,
      'non_2xx_recovery_passed': true,
      'estimated_daily_requests': 500,
      'completion_seconds': 420,
    });
  });

  test('Firefly API task rejects unbounded role, usage, and duration',
      () async {
    var writes = 0;
    final analytics = AiUniversityLearningOutcomeAnalytics(
      task: AiUniversityLearningOutcomeTask.fireflyApi,
      writer: (_) async => writes += 1,
    );

    Future<bool> submit({
      String learnerRole = 'developer',
      int estimatedDailyRequests = 500,
      int completionSeconds = 420,
    }) =>
        analytics.recordFireflyCompleted(
          correctAnswers: 3,
          selfRating: 4,
          learnerRole: learnerRole,
          firstCallSucceeded: true,
          secretHandlingPassed: true,
          apiSelectionPassed: true,
          non2xxRecoveryPassed: true,
          estimatedDailyRequests: estimatedDailyRequests,
          completionSeconds: completionSeconds,
        );

    expect(await submit(learnerRole: 'unknown'), isFalse);
    expect(await submit(estimatedDailyRequests: 9001), isFalse);
    expect(await submit(completionSeconds: 0), isFalse);
    expect(writes, 0);
  });
}
