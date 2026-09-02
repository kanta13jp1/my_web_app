import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/gamification_service.dart';
import 'package:my_web_app/services/import_service.dart';

void main() {
  late ImportService service;

  setUp(() {
    service = ImportService(GamificationService());
  });

  group('ImportService', () {
    test('parseNotionCsvText reads title content and tags', () {
      const csv = 'Title,Content,Tags\n'
          '"Reading memo","Imported from Notion","books,import"\n';

      final drafts = service.parseNotionCsvText(csv);

      expect(drafts, hasLength(1));
      expect(drafts.first.title, 'Reading memo');
      expect(drafts.first.content, 'Imported from Notion');
      expect(drafts.first.tags, <String>['books', 'import']);
      expect(drafts.first.source, 'notion');
    });

    test('parseEvernoteEnexText strips markup and extracts tags', () {
      const enex = '''
<?xml version="1.0" encoding="UTF-8"?>
<en-export>
  <note>
    <title>Evernote memo</title>
    <content><![CDATA[
      <en-note>
        <div>First line</div>
        <div><b>Second line</b></div>
      </en-note>
    ]]></content>
    <tag>archive</tag>
    <tag>ideas</tag>
  </note>
</en-export>
''';

      final drafts = service.parseEvernoteEnexText(enex);

      expect(drafts, hasLength(1));
      expect(drafts.first.title, 'Evernote memo');
      expect(drafts.first.content, 'First line\nSecond line');
      expect(drafts.first.tags, <String>['archive', 'ideas']);
      expect(drafts.first.source, 'evernote');
      expect(drafts.first.sourceId, hasLength(64));
      expect(drafts.first.sourceContentSha256, hasLength(64));
      expect(drafts.first.sourceMetadata['enml'], contains('<en-note>'));
    });

    test('Evernote preview enables only the lossless commit path', () async {
      const enex = '''
<en-export export-date="20260823T034500Z" application="Evernote" version="10">
  <note>
    <title>Safe preview</title>
    <content><![CDATA[<en-note><div>Body</div></en-note>]]></content>
    <resource>
      <data encoding="base64">aGVsbG8=</data>
      <mime>text/plain</mime>
      <resource-attributes><file-name>memo.txt</file-name></resource-attributes>
    </resource>
  </note>
</en-export>
''';

      final preview = await service.buildPreview(
        sourceType: 'evernote',
        fileName: 'batch-001.enex',
        bytes: Uint8List.fromList(utf8.encode(enex)),
      );

      expect(preview.usedEdgeFunction, isFalse);
      expect(preview.canCommit, isTrue);
      expect(preview.commitBlockedReason, isNull);
      expect(preview.sourceExportSha256, hasLength(64));
      expect(preview.resourceCount, 1);
      expect(preview.notes.single.sourceResourceCount, 1);
    });

    test('Evernote drafts cannot enter the legacy commit path', () async {
      const draft = ImportedNoteDraft(
        title: 'Blocked',
        content: 'Body',
        source: 'evernote',
      );

      expect(
        () => service.importNotes(userId: 'user-1', notes: const [draft]),
        throwsA(isA<StateError>()),
      );
    });

    test('ImportPreviewResult.fromJson reads edge preview metadata', () {
      final preview = ImportPreviewResult.fromJson(<String, dynamic>{
        'sourceType': 'markdown',
        'sourceLabel': 'Markdown',
        'fileName': 'note.md',
        'previewMode': 'edge-function',
        'warnings': <String>['Edge preview active'],
        'notes': <Map<String, dynamic>>[
          <String, dynamic>{
            'title': 'Title',
            'content': 'Body',
            'source': 'markdown',
            'tags': <String>[],
          },
        ],
      });

      expect(preview.sourceType, 'markdown');
      expect(preview.usedEdgeFunction, isTrue);
      expect(preview.notes.single.title, 'Title');
      expect(preview.warnings.single, 'Edge preview active');
    });

    test('ImportExecutionResult.fromJson reads execution metadata', () {
      final result = ImportExecutionResult.fromJson(<String, dynamic>{
        'insertedCount': 24,
        'importMode': 'edge-function',
      });

      expect(result.insertedCount, 24);
      expect(result.usedEdgeFunction, isTrue);
      expect(result.importModeLabel, 'Edge Function import');
    });
  });
}
