import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef AiUniversityLearningOutcomeWriter = Future<void> Function(
  Map<String, Object> row,
);

enum AiUniversityLearningOutcomeTask {
  latestInfo(
    taskVersion: '01ai_latest_20260828_v1',
    provider: '01ai',
    category: 'news',
  ),
  fireflyLatestInfo(
    taskVersion: 'adobe_firefly_news_20260903_v1',
    provider: 'adobe_firefly',
    category: 'news',
  ),
  modelSelection(
    taskVersion: '01ai_models_20260829_v1',
    provider: '01ai',
    category: 'models',
  ),
  fireflyApi(
    taskVersion: 'adobe_firefly_api_20260831_v1',
    provider: 'adobe_firefly',
    category: 'api',
  ),
  llmMechanics(
    taskVersion: 'academic_llm_mechanics_20260829_v1',
    provider: 'academic',
    category: 'llm_mechanics',
  );

  const AiUniversityLearningOutcomeTask({
    required this.taskVersion,
    required this.provider,
    required this.category,
  });

  final String taskVersion;
  final String provider;
  final String category;
}

/// Anonymous, course-bounded learning outcome analytics.
///
/// Only the fixed task identity and aggregate metrics are accepted. Learner
/// text, answers, user/session identifiers, URLs, and free-form properties
/// cannot be supplied through this API.
class AiUniversityLearningOutcomeAnalytics {
  const AiUniversityLearningOutcomeAnalytics({
    AiUniversityLearningOutcomeWriter? writer,
    this.task = AiUniversityLearningOutcomeTask.latestInfo,
  }) : _writer = writer;

  factory AiUniversityLearningOutcomeAnalytics.supabase(
    SupabaseClient client, {
    AiUniversityLearningOutcomeTask task =
        AiUniversityLearningOutcomeTask.latestInfo,
  }) {
    return AiUniversityLearningOutcomeAnalytics(
      task: task,
      writer: (row) async {
        await client.from('ai_university_learning_outcome_events').insert(row);
      },
    );
  }

  static const String taskVersion = '01ai_latest_20260828_v1';
  static const Set<String> allowedPropertyNames = <String>{
    'event_name',
    'task_version',
    'provider',
    'category',
    'correct_answers',
    'total_questions',
    'self_rating',
    'learner_role',
    'first_call_succeeded',
    'secret_handling_passed',
    'api_selection_passed',
    'non_2xx_recovery_passed',
    'estimated_daily_requests',
    'completion_seconds',
    'release_feature',
    'output_kind',
    'input_asset_count',
    'legacy_workflow_minutes',
    'latest_workflow_minutes',
    'revision_count',
    'usable_output',
    'workplace_applicable',
    'adoption_decision',
  };
  static const Set<String> allowedFireflyLearnerRoles = <String>{
    'developer',
    'operations',
    'creator',
    'product_owner',
  };
  static const Set<String> allowedFireflyLatestInfoFeatures = <String>{
    'central_workspace',
    'interfaces_batch',
  };
  static const Set<String> allowedFireflyOutputKinds = <String>{
    'image',
    'video',
    'asset_batch',
  };
  static const Set<int> allowedFireflyInputAssetCounts = <int>{1, 10, 100, 500};
  static const Set<String> allowedFireflyAdoptionDecisions = <String>{
    'adopt',
    'pilot',
    'defer',
  };

  final AiUniversityLearningOutcomeWriter? _writer;
  final AiUniversityLearningOutcomeTask task;

  Future<bool> recordViewed() => _record(<String, Object>{
        'event_name': 'task_viewed',
        'task_version': task.taskVersion,
        'provider': task.provider,
        'category': task.category,
      });

  Future<bool> recordCompleted({
    required int correctAnswers,
    required int selfRating,
  }) {
    if (correctAnswers < 0 || correctAnswers > 3) return Future.value(false);
    if (selfRating < 1 || selfRating > 5) return Future.value(false);

    return _record(<String, Object>{
      'event_name': 'task_completed',
      'task_version': task.taskVersion,
      'provider': task.provider,
      'category': task.category,
      'correct_answers': correctAnswers,
      'total_questions': 3,
      'self_rating': selfRating,
    });
  }

  Future<bool> recordFireflyCompleted({
    required int correctAnswers,
    required int selfRating,
    required String learnerRole,
    required bool firstCallSucceeded,
    required bool secretHandlingPassed,
    required bool apiSelectionPassed,
    required bool non2xxRecoveryPassed,
    required int estimatedDailyRequests,
    required int completionSeconds,
  }) {
    if (task != AiUniversityLearningOutcomeTask.fireflyApi) {
      return Future.value(false);
    }
    if (correctAnswers < 0 || correctAnswers > 3) return Future.value(false);
    if (selfRating < 1 || selfRating > 5) return Future.value(false);
    if (!allowedFireflyLearnerRoles.contains(learnerRole)) {
      return Future.value(false);
    }
    if (estimatedDailyRequests < 1 || estimatedDailyRequests > 9000) {
      return Future.value(false);
    }
    if (completionSeconds < 1 || completionSeconds > 3600) {
      return Future.value(false);
    }

    return _record(<String, Object>{
      'event_name': 'task_completed',
      'task_version': task.taskVersion,
      'provider': task.provider,
      'category': task.category,
      'correct_answers': correctAnswers,
      'total_questions': 3,
      'self_rating': selfRating,
      'learner_role': learnerRole,
      'first_call_succeeded': firstCallSucceeded,
      'secret_handling_passed': secretHandlingPassed,
      'api_selection_passed': apiSelectionPassed,
      'non_2xx_recovery_passed': non2xxRecoveryPassed,
      'estimated_daily_requests': estimatedDailyRequests,
      'completion_seconds': completionSeconds,
    });
  }

  Future<bool> recordFireflyLatestInfoCompleted({
    required int correctAnswers,
    required int selfRating,
    required String releaseFeature,
    required String outputKind,
    required int inputAssetCount,
    required int legacyWorkflowMinutes,
    required int latestWorkflowMinutes,
    required int revisionCount,
    required bool usableOutput,
    required bool workplaceApplicable,
    required String adoptionDecision,
  }) {
    if (task != AiUniversityLearningOutcomeTask.fireflyLatestInfo) {
      return Future.value(false);
    }
    if (correctAnswers < 0 || correctAnswers > 3) return Future.value(false);
    if (selfRating < 1 || selfRating > 5) return Future.value(false);
    if (!allowedFireflyLatestInfoFeatures.contains(releaseFeature)) {
      return Future.value(false);
    }
    if (!allowedFireflyOutputKinds.contains(outputKind)) {
      return Future.value(false);
    }
    if (!allowedFireflyInputAssetCounts.contains(inputAssetCount)) {
      return Future.value(false);
    }
    if (legacyWorkflowMinutes < 1 || legacyWorkflowMinutes > 120) {
      return Future.value(false);
    }
    if (latestWorkflowMinutes < 1 || latestWorkflowMinutes > 120) {
      return Future.value(false);
    }
    if (revisionCount < 0 || revisionCount > 20) {
      return Future.value(false);
    }
    if (!allowedFireflyAdoptionDecisions.contains(adoptionDecision)) {
      return Future.value(false);
    }

    return _record(<String, Object>{
      'event_name': 'task_completed',
      'task_version': task.taskVersion,
      'provider': task.provider,
      'category': task.category,
      'correct_answers': correctAnswers,
      'total_questions': 3,
      'self_rating': selfRating,
      'release_feature': releaseFeature,
      'output_kind': outputKind,
      'input_asset_count': inputAssetCount,
      'legacy_workflow_minutes': legacyWorkflowMinutes,
      'latest_workflow_minutes': latestWorkflowMinutes,
      'revision_count': revisionCount,
      'usable_output': usableOutput,
      'workplace_applicable': workplaceApplicable,
      'adoption_decision': adoptionDecision,
    });
  }

  Future<bool> _record(Map<String, Object> row) async {
    final writer = _writer;
    if (writer == null || !row.keys.every(allowedPropertyNames.contains)) {
      return false;
    }

    try {
      await writer(row);
      return true;
    } catch (_) {
      debugPrint('AI University learning outcome event was dropped.');
      return false;
    }
  }
}
