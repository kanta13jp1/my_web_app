import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef AiUniversityLearningOutcomeWriter = Future<void> Function(
  Map<String, Object> row,
);

/// Anonymous, course-bounded learning outcome analytics.
///
/// Only the fixed task identity and aggregate metrics are accepted. Learner
/// text, answers, user/session identifiers, URLs, and free-form properties
/// cannot be supplied through this API.
class AiUniversityLearningOutcomeAnalytics {
  const AiUniversityLearningOutcomeAnalytics({
    AiUniversityLearningOutcomeWriter? writer,
  }) : _writer = writer;

  factory AiUniversityLearningOutcomeAnalytics.supabase(
    SupabaseClient client,
  ) {
    return AiUniversityLearningOutcomeAnalytics(
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
  };

  final AiUniversityLearningOutcomeWriter? _writer;

  Future<bool> recordViewed() => _record(<String, Object>{
        'event_name': 'task_viewed',
        'task_version': taskVersion,
        'provider': '01ai',
        'category': 'news',
      });

  Future<bool> recordCompleted({
    required int correctAnswers,
    required int selfRating,
  }) {
    if (correctAnswers < 0 || correctAnswers > 3) return Future.value(false);
    if (selfRating < 1 || selfRating > 5) return Future.value(false);

    return _record(<String, Object>{
      'event_name': 'task_completed',
      'task_version': taskVersion,
      'provider': '01ai',
      'category': 'news',
      'correct_answers': correctAnswers,
      'total_questions': 3,
      'self_rating': selfRating,
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
