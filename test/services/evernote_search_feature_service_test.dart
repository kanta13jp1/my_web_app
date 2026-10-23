import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/evernote_search_feature_service.dart';

void main() {
  group('EvernoteSearchFeatureService', () {
    test('derives attachment, task, checkbox, and content categories', () {
      final features = EvernoteSearchFeatureService.infer(
        content: '''
- [x] migrated
- [ ] review
https://drive.google.com/file/d/example
report@example.com
| Item | Price |
| --- | --- |
Total: ¥1,200 (25%)
''',
        attachmentMimeTypes: const <String>[
          'application/pdf',
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ],
        taskStatuses: const <String>['open', 'completed'],
      );

      expect(features.hasCheckedTodo, isTrue);
      expect(features.hasUncheckedTodo, isTrue);
      expect(
        features.containsTypes,
        containsAll(<String>[
          'attachment',
          'filepdf',
          'filespreadsheet',
          'fileoffice',
          'entodo',
          'task',
          'taskcompleted',
          'tasknotcompleted',
          'url',
          'urlgoogledrive',
          'email',
          'table',
          'numberprice',
          'numberpercent',
        ]),
      );
    });

    test('reads source and encrypted markers from preserved metadata', () {
      final features = EvernoteSearchFeatureService.infer(
        content: '',
        sourceMetadata: const <String, dynamic>{
          'attributes': <String, dynamic>{'source': 'mobile.ios'},
          'has_encrypted_text': true,
        },
      );

      expect(features.source, 'mobile.ios');
      expect(features.hasEncryptedText, isTrue);
      expect(features.containsTypes, contains('encrypt'));
    });

    test('keeps unsupported semantic categories absent without evidence', () {
      final features = EvernoteSearchFeatureService.infer(content: 'plain');

      expect(features.containsTypes, isNot(contains('person')));
      expect(features.containsTypes, isNot(contains('calendarevent')));
      expect(features.resourceMimeTypes, isEmpty);
    });
  });
}
