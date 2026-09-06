import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/inbox_capture_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeSupabaseClient extends Fake implements SupabaseClient {}

void main() {
  group('Inbox capture payload', () {
    test('stores plain text as an unorganized Inbox note', () {
      final savedAt = DateTime.utc(2026, 8, 4, 1, 2, 3);

      final payload = buildInboxNoteInsert(
        userId: 'user-123',
        text: '  First thought\nsecond line  ',
        savedAt: savedAt,
      );

      expect(payload['user_id'], 'user-123');
      expect(payload['title'], 'First thought');
      expect(payload['content'], 'First thought\nsecond line');
      expect(payload['tags'], <String>['inbox']);
      expect(payload['capture_status'], inboxCaptureStatus);
      expect(payload['capture_source'], inboxCaptureSource);
      expect(payload['inbox_saved_at'], savedAt.toIso8601String());
      expect(payload['classification_status'], pendingClassificationStatus);
      expect(payload['classification_category'], isNull);
      expect(payload['classification_source'], isNull);
      expect(payload['classified_at'], isNull);
      expect(payload['is_archived'], isFalse);
      expect(payload['is_pinned'], isFalse);
    });

    test('uses the first non-empty line and caps generated titles', () {
      final title = deriveInboxNoteTitle(
        '\n   \nabcdefghijklmnopqrstuvwxyz',
        maxLength: 10,
      );

      expect(title, 'abcdefghij');
    });

    test('rejects whitespace-only captures', () {
      expect(
        () => buildInboxNoteInsert(
          userId: 'user-123',
          text: '  \n  ',
          savedAt: DateTime.utc(2026, 8, 4),
        ),
        throwsArgumentError,
      );
    });

    test('classification request exposes only the action and note id', () {
      final request = buildInboxClassificationRequest(42);

      expect(request, <String, dynamic>{
        'action': 'notes.classify',
        'note_id': 42,
      });
      expect(request, isNot(contains('content')));
      expect(request, isNot(contains('title')));
      expect(request, isNot(contains('user_id')));
      expect(() => buildInboxClassificationRequest(0), throwsArgumentError);
    });

    test('classification launcher receives only the persisted note id',
        () async {
      int? launchedNoteId;
      final service = InboxCaptureService(
        _FakeSupabaseClient(),
        classificationLauncher: (noteId) async {
          launchedNoteId = noteId;
        },
      );

      await service.requestClassification(42);

      expect(launchedNoteId, 42);
    });
  });
}
