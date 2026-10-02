import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum AiUniversityContentEvent {
  contentFetchFailed('content_fetch_failed'),
  fallbackShown('fallback_shown'),
  retryRequested('retry_requested'),
  retrySucceeded('retry_succeeded'),
  retryFailed('retry_failed'),
  providerSearch('provider_search'),
  providerSelected('provider_selected'),
  contentOpened('content_opened'),
  quizCompleted('quiz_completed'),
  reviewReturned('review_returned');

  const AiUniversityContentEvent(this.databaseValue);

  final String databaseValue;
}

typedef AiUniversityAnalyticsWriter = Future<void> Function(
  Map<String, Object> row,
);

/// Anonymous, best-effort reliability and learning-journey analytics for AI University.
///
/// The API intentionally accepts no dynamic properties. It cannot send a user
/// identifier, URL, exception, location, content, or free-form diagnostic text.
/// An instance without a writer is disabled and is a no-op.
class AiUniversityContentAnalytics {
  const AiUniversityContentAnalytics({AiUniversityAnalyticsWriter? writer})
      : _writer = writer;

  factory AiUniversityContentAnalytics.supabase(SupabaseClient client) {
    return AiUniversityContentAnalytics(
      writer: (row) async {
        await client.from('ai_university_content_events').insert(row);
      },
    );
  }

  static const Set<String> allowedEventNames = <String>{
    'content_fetch_failed',
    'fallback_shown',
    'retry_requested',
    'retry_succeeded',
    'retry_failed',
    'provider_search',
    'provider_selected',
    'content_opened',
    'quiz_completed',
    'review_returned',
  };

  static const Set<String> allowedPropertyNames = <String>{
    'event_name',
    'surface',
  };

  static const String _surface = 'ai_university_content';
  final AiUniversityAnalyticsWriter? _writer;

  bool get isEnabled => _writer != null;

  Future<void> record(AiUniversityContentEvent event) async {
    final writer = _writer;
    if (writer == null || !allowedEventNames.contains(event.databaseValue)) {
      return;
    }

    final row = <String, Object>{
      'event_name': event.databaseValue,
      'surface': _surface,
    };
    assert(row.keys.every(allowedPropertyNames.contains));
    try {
      await writer(row);
    } catch (_) {
      // Analytics must never alter the fallback/retry user experience.
      debugPrint('AI University content analytics event was dropped.');
    }
  }
}
