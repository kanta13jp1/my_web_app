import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/ai_university_content_analytics.dart';

void main() {
  test('records only the fixed anonymous event contract', () async {
    final rows = <Map<String, Object>>[];
    final analytics = AiUniversityContentAnalytics(
      writer: (row) async => rows.add(row),
    );

    await analytics.record(AiUniversityContentEvent.contentFetchFailed);
    await analytics.record(AiUniversityContentEvent.fallbackShown);
    await analytics.record(AiUniversityContentEvent.retryRequested);
    await analytics.record(AiUniversityContentEvent.retrySucceeded);
    await analytics.record(AiUniversityContentEvent.retryFailed);
    await analytics.record(AiUniversityContentEvent.providerSearch);
    await analytics.record(AiUniversityContentEvent.providerSelected);
    await analytics.record(AiUniversityContentEvent.contentOpened);
    await analytics.record(AiUniversityContentEvent.quizCompleted);
    await analytics.record(AiUniversityContentEvent.reviewReturned);

    expect(
      rows.map((row) => row['event_name']).toSet(),
      AiUniversityContentAnalytics.allowedEventNames,
    );
    for (final row in rows) {
      expect(
        row.keys.toSet(),
        AiUniversityContentAnalytics.allowedPropertyNames,
      );
      expect(row['surface'], 'ai_university_content');
      expect(row.keys, isNot(contains('user_id')));
      expect(row.keys, isNot(contains('url')));
      expect(row.keys, isNot(contains('exception')));
      expect(row.keys, isNot(contains('content')));
    }
  });

  test('is disabled and does nothing when no writer is configured', () async {
    const analytics = AiUniversityContentAnalytics();

    expect(analytics.isEnabled, isFalse);
    await analytics.record(AiUniversityContentEvent.retryRequested);
  });

  test('writer failure is swallowed as best-effort analytics', () async {
    final analytics = AiUniversityContentAnalytics(
      writer: (_) async => throw StateError('not configured'),
    );

    await expectLater(
      analytics.record(AiUniversityContentEvent.retryFailed),
      completes,
    );
  });
}
