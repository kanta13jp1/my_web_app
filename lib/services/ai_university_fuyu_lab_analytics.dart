import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef AiUniversityFuyuLabWriter = Future<void> Function(
  Map<String, Object> row,
);

class AiUniversityFuyuLabCompletion {
  const AiUniversityFuyuLabCompletion({
    required this.attemptOutcome,
    required this.completionSeconds,
    required this.rubricScore,
  });

  final String attemptOutcome;
  final int completionSeconds;
  final int rubricScore;
}

/// Privacy-minimal analytics for the fixed Fuyu model-card exercise.
///
/// Only finite outcomes and bounded numbers are accepted. Learner text,
/// generated output, errors, identifiers, sessions, IP addresses, and URLs
/// cannot be supplied through this API.
class AiUniversityFuyuLabAnalytics {
  const AiUniversityFuyuLabAnalytics({AiUniversityFuyuLabWriter? writer})
      : _writer = writer;

  factory AiUniversityFuyuLabAnalytics.supabase(SupabaseClient client) {
    return AiUniversityFuyuLabAnalytics(
      writer: (row) async {
        await client.from('ai_university_fuyu_lab_events').insert(row);
      },
    );
  }

  static const taskVersion = 'adept_fuyu_model_card_20260830_v1';
  static const maxCompletionSeconds = 86400;
  static const inferenceOutcomes = <String>{
    'first_try_success',
    'success_after_error',
    'success_after_difference',
    'unresolved_error',
    'unresolved_difference',
  };
  static const readingOutcome = 'reading_completed';
  static const allowedPropertyNames = <String>{
    'event_name',
    'task_version',
    'task_mode',
    'attempt_outcome',
    'completion_seconds',
    'rubric_score',
  };

  final AiUniversityFuyuLabWriter? _writer;

  Future<bool> recordStarted() => _record(<String, Object>{
        'event_name': 'lab_started',
        'task_version': taskVersion,
      });

  Future<bool> recordCompleted(AiUniversityFuyuLabCompletion completion) {
    final isInference = inferenceOutcomes.contains(completion.attemptOutcome);
    final isReading = completion.attemptOutcome == readingOutcome;
    if ((!isInference && !isReading) ||
        completion.completionSeconds < 1 ||
        completion.completionSeconds > maxCompletionSeconds ||
        completion.rubricScore < 0 ||
        completion.rubricScore > 4) {
      return Future.value(false);
    }

    return _record(<String, Object>{
      'event_name': 'lab_completed',
      'task_version': taskVersion,
      'task_mode': isReading ? 'reading_fallback' : 'inference',
      'attempt_outcome': completion.attemptOutcome,
      'completion_seconds': completion.completionSeconds,
      'rubric_score': completion.rubricScore,
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
      debugPrint('AI University Fuyu lab event was dropped.');
      return false;
    }
  }
}
