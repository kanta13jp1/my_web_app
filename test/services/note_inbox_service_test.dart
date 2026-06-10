import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/note_inbox_service.dart';

void main() {
  group('NoteInboxService', () {
    test('buildInboxTitle uses the first meaningful line', () {
      final title = NoteInboxService.buildInboxTitle(
        '\n  Follow up invoice with client\nsecond line',
        DateTime(2026, 6, 10, 9, 5),
      );

      expect(title, 'Follow up invoice with client');
    });

    test('buildInboxTitle truncates long one-line captures', () {
      final title = NoteInboxService.buildInboxTitle(
        'a' * 80,
        DateTime(2026, 6, 10, 9, 5),
      );

      expect(title.length, 51);
      expect(title.endsWith('...'), isTrue);
    });

    test('classifyText extracts deterministic tags and status', () {
      final result = NoteInboxService.classifyText(
        title: 'Budget meeting',
        content: 'Review invoice payment tasks before the sync.',
      );

      expect(result.tags, containsAll(<String>['task', 'meeting', 'money']));
      expect(
        result.classificationStatus,
        NoteInboxService.classificationStatusClassified,
      );
      expect(result.captureStatus, NoteInboxService.captureStatusInbox);
    });
  });
}
