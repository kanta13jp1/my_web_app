import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/evernote_enml_markdown_converter.dart';
import 'package:my_web_app/services/evernote_enex_parser.dart';

void main() {
  const parser = EvernoteEnexParser();

  group('EvernoteEnexParser', () {
    test('preserves ENML, metadata, links, and resource bytes', () {
      final export = parser.parseText(_completeEnex);

      expect(export.application, 'Evernote/Windows');
      expect(export.version, '10.120.3');
      expect(export.exportDate, DateTime.utc(2026, 8, 23, 3, 45));
      expect(export.notes, hasLength(1));
      expect(export.resourceCount, 1);
      expect(export.taskCount, 1);
      expect(export.exportSha256, hasLength(64));

      final note = export.notes.single;
      expect(note.sourceId, 'evernote-guid-1');
      expect(note.createdAt, DateTime.utc(2024, 1, 2, 3, 4, 5));
      expect(note.updatedAt, DateTime.utc(2024, 6, 7, 8, 9, 10, 123, 456));
      expect(note.tags, <String>['archive', 'ideas & plans']);
      expect(note.attributes['author'], 'Migration test');
      expect(
        note.attributes['source-url'],
        'https://example.com/source?id=1&lang=ja',
      );
      expect(
        note.attributes['application-data:future-key'],
        '<value>kept</value>',
      );
      expect(note.links, <String>['evernote:///view/1/s1/guid/guid/']);
      expect(note.plainText, contains('☐ Follow up'));
      expect(note.plainText, contains('[Attachment: memo.txt]'));
      expect(note.markdownText, contains('## Plan'));
      expect(note.markdownText, contains('**Bold** and *italic*'));
      expect(note.markdownText, contains('- [ ] Follow up'));
      expect(
        note.markdownText,
        contains('[Internal link](evernote-note:guid)'),
      );
      expect(
        EvernoteEnmlMarkdownConverter.sourceIdFromReference(
          'evernote-note:guid',
        ),
        'guid',
      );
      expect(
        note.markdownText,
        contains(
          '[memo.txt](evernote-resource:5d41402abc4b2a76b9719d911017c592)',
        ),
      );
      expect(note.markdownText, contains('| Key | Value |'));
      expect(note.markdownText, contains('| --- | --- |'));
      expect(note.noteReminder, isNotNull);
      expect(note.noteReminder!.order, 1710000000000);
      expect(note.noteReminder!.reminderAt, DateTime.utc(2024, 7, 1, 9));
      expect(note.noteReminder!.completedAt, DateTime.utc(2024, 7, 2, 9));
      expect(note.tasks, hasLength(1));
      final task = note.tasks.single;
      expect(task.title, 'Structured follow up');
      expect(task.status, 'open');
      expect(task.inNote, isTrue);
      expect(task.dueAt, DateTime.utc(2024, 7, 10, 9));
      expect(task.dueDateUiOption, 'date_time');
      expect(task.timeZone, 'Asia/Tokyo');
      expect(task.recurrence, 'RRULE:FREQ=WEEKLY');
      expect(task.repeatAfterCompletion, isTrue);
      expect(task.creator, 'owner@example.com');
      expect(task.assigneeUserId, 'evernote-user-42');
      expect(task.assigneeEmail, 'delegate@example.com');
      expect(task.assigneeDisplayName, 'Delegated reviewer');
      expect(task.assigneeRawXml, contains('<assignee>'));
      expect(
        task.toJson()['assignee'],
        containsPair('email', 'delegate@example.com'),
      );
      expect(task.reminders, hasLength(1));
      expect(task.reminders.single.status, 'active');
      expect(
        task.reminders.single.reminderAt,
        DateTime.utc(2024, 7, 9, 9),
      );
      expect(
        note.toImportMetadata()['tasks'],
        isA<List<dynamic>>().having((tasks) => tasks.length, 'length', 1),
      );
      expect(note.toImportMetadata()['note_reminder'], isA<Map>());
      expect(note.contentSha256, hasLength(64));
      expect(note.rawXml, contains('<note-attributes>'));

      final resource = note.resources.single;
      expect(resource.fileName, 'memo.txt');
      expect(resource.mimeType, 'text/plain');
      expect(resource.data, Uint8List.fromList(utf8.encode('hello')));
      expect(resource.dataSha256, hasLength(64));
      expect(resource.recognitionXml, contains('<recoIndex'));
      expect(resource.recognition, isNotNull);
      expect(resource.recognition!.documentType, 'printed');
      expect(resource.recognition!.regions, hasLength(1));
      expect(resource.recognition!.regions.single.x, 0);
      expect(
        resource.recognition!.regions.single.displayCandidate.text,
        'hello',
      );
      expect(resource.recognition!.searchText, contains('hello'));
      expect(
        resource.toManifestJson()['recognition'],
        isA<Map<String, dynamic>>(),
      );
      expect(resource.toManifestJson()['byte_length'], 5);
    });

    test('retains malformed recognition for cloud OCR fallback', () {
      final malformed = _completeEnex.replaceFirst(
        'x="0" y="0"',
        'x="-1" y="0"',
      );

      final export = parser.parseText(malformed);
      final resource = export.notes.single.resources.single;

      expect(resource.recognition, isNull);
      expect(resource.recognitionXml, contains('x="-1"'));
      expect(
        export.warnings,
        contains(
          'A resource contains invalid Evernote recognition data; '
          'raw XML retained for cloud OCR fallback.',
        ),
      );
    });

    test('builds a deterministic source id when ENEX has no guid', () {
      final first = parser.parseText(_minimalEnex).notes.single;
      final second = parser.parseText(_minimalEnex).notes.single;

      expect(first.sourceGuid, isNull);
      expect(first.sourceId, second.sourceId);
      expect(first.sourceId, hasLength(64));
    });

    test('rejects content that is not an ENEX export', () {
      expect(
        () => parser.parseText('<notes />'),
        throwsA(isA<FormatException>()),
      );
    });

    test('blocks unresolved attachments and encrypted sections', () {
      final export = parser.parseText(_unsafeEnex);

      expect(export.warnings, hasLength(2));
      expect(
        export.warnings,
        anyElement(contains('attachment reference(s) could not be matched')),
      );
      expect(
        export.warnings,
        anyElement(contains('encrypted ENML section(s)')),
      );
      expect(
        export.notes.single.markdownText,
        contains('[Unresolved Evernote attachment]'),
      );
    });

    test('streams one note subtree at a time across byte boundaries', () async {
      final bytes = Uint8List.fromList(utf8.encode(_streamingEnex));
      final notes = <EvernoteEnexNote>[];
      final progress = <int>[];
      var activeCallbacks = 0;
      var maximumActiveCallbacks = 0;

      final summary = await parser.parseStream(
        Stream<List<int>>.fromIterable(
          bytes.map<List<int>>((byte) => <int>[byte]),
        ),
        totalBytes: bytes.length,
        onProgress: (processedBytes, totalBytes) {
          progress.add(processedBytes);
        },
        onNote: (note) async {
          activeCallbacks += 1;
          if (activeCallbacks > maximumActiveCallbacks) {
            maximumActiveCallbacks = activeCallbacks;
          }
          await Future<void>.delayed(Duration.zero);
          notes.add(note);
          activeCallbacks -= 1;
        },
      );
      final full = parser.parseBytes(bytes);

      expect(summary.exportSha256, full.exportSha256);
      expect(summary.exportDate, full.exportDate);
      expect(summary.application, full.application);
      expect(summary.version, full.version);
      expect(summary.noteCount, full.notes.length);
      expect(summary.resourceCount, full.resourceCount);
      expect(summary.warnings, full.warnings);
      expect(summary.processedBytes, bytes.length);
      expect(
        notes.map((note) => note.sourceId),
        full.notes.map((note) => note.sourceId),
      );
      expect(
        notes.map((note) => note.title),
        full.notes.map((note) => note.title),
      );
      expect(
        notes.map((note) => note.contentSha256),
        full.notes.map((note) => note.contentSha256),
      );
      expect(notes.first.resources.single.data, utf8.encode('hello'));
      expect(notes.last.title, '日本語ノート');
      expect(maximumActiveCallbacks, 1);
      expect(progress.first, 0);
      expect(progress.last, bytes.length);
      expect(
        progress.indexed.skip(1).every(
              (entry) => entry.$2 >= progress[entry.$1 - 1],
            ),
        isTrue,
      );
    });

    test('rejects a stream whose declared size is incomplete', () async {
      final bytes = Uint8List.fromList(utf8.encode(_minimalEnex));

      await expectLater(
        parser.parseStream(
          Stream<List<int>>.value(bytes),
          totalBytes: bytes.length + 1,
          onNote: (_) {},
        ),
        throwsStateError,
      );
    });

    test('rejects a streamed XML document that is not ENEX', () async {
      await expectLater(
        parser.parseStream(
          Stream<List<int>>.value(utf8.encode('<notes />')),
          onNote: (_) {},
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

const _minimalEnex = '''
<?xml version="1.0" encoding="UTF-8"?>
<en-export export-date="20260823T034500Z" application="Evernote" version="10">
  <note>
    <title>Minimal</title>
    <content><![CDATA[<en-note><div>Body</div></en-note>]]></content>
    <created>20240102T030405Z</created>
  </note>
</en-export>
''';

const _completeEnex = '''
<?xml version="1.0" encoding="UTF-8"?>
<en-export export-date="20260823T034500Z" application="Evernote/Windows" version="10.120.3">
  <note>
    <guid>evernote-guid-1</guid>
    <title>Migration &amp; verification</title>
    <content><![CDATA[
      <en-note>
        <h2>Plan</h2>
        <div><strong>Bold</strong> and <em>italic</em></div>
        <div><en-todo checked="false"/>Follow up</div>
        <div><a href="evernote:///view/1/s1/guid/guid/">Internal link</a></div>
        <div><en-media type="text/plain" hash="5d41402abc4b2a76b9719d911017c592"/></div>
        <table><tr><th>Key</th><th>Value</th></tr><tr><td>A</td><td>B</td></tr></table>
      </en-note>
    ]]></content>
    <created>20240102T030405Z</created>
    <updated>20240607T080910.123456Z</updated>
    <tag>archive</tag>
    <tag>ideas &amp; plans</tag>
    <note-attributes>
      <author>Migration test</author>
      <source-url>https://example.com/source?id=1&amp;lang=ja</source-url>
      <reminder-order>1710000000000</reminder-order>
      <reminder-time>20240701T090000Z</reminder-time>
      <reminder-done-time>20240702T090000Z</reminder-done-time>
      <application-data key="future-key"><value>kept</value></application-data>
    </note-attributes>
    <task>
      <title>Structured follow up</title>
      <created>20240601T010203Z</created>
      <updated>20240602T020304Z</updated>
      <taskStatus>open</taskStatus>
      <inNote>true</inNote>
      <taskFlag>priority</taskFlag>
      <sortWeight>100</sortWeight>
      <noteLevelID>task-1</noteLevelID>
      <taskGroupNoteLevelID>group-1</taskGroupNoteLevelID>
      <dueDate>20240710T090000Z</dueDate>
      <dueDateUIOption>date_time</dueDateUIOption>
      <timeZone>Asia/Tokyo</timeZone>
      <recurrence>RRULE:FREQ=WEEKLY</recurrence>
      <repeatAfterCompletion>true</repeatAfterCompletion>
      <statusUpdated>20240602T020304Z</statusUpdated>
      <creator>owner@example.com</creator>
      <lastEditor>editor@example.com</lastEditor>
      <assignee>
        <userID>evernote-user-42</userID>
        <email>delegate@example.com</email>
        <displayName>Delegated reviewer</displayName>
      </assignee>
      <reminder>
        <created>20240601T010203Z</created>
        <updated>20240602T020304Z</updated>
        <noteLevelID>reminder-1</noteLevelID>
        <reminderDate>20240709T090000Z</reminderDate>
        <reminderDateUIOption>date_time</reminderDateUIOption>
        <timeZone>Asia/Tokyo</timeZone>
        <dueDateOffset>-86400000</dueDateOffset>
        <reminderStatus>active</reminderStatus>
      </reminder>
    </task>
    <resource>
      <data encoding="base64" hash="5d41402abc4b2a76b9719d911017c592">aGVsbG8=</data>
      <mime>text/plain</mime>
      <width>10</width>
      <height>20</height>
      <recognition><![CDATA[
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE recoIndex SYSTEM "http://xml.evernote.com/pub/recoIndex.dtd">
        <recoIndex
            docType="printed"
            objType="image"
            objID="5d41402abc4b2a76b9719d911017c592"
            engineVersion="5.5.22.7"
            recoType="service"
            lang="en"
            objWidth="10"
            objHeight="20">
          <item x="0" y="0" w="10" h="20">
            <t w="99">hello</t>
            <t w="70">Hello</t>
          </item>
        </recoIndex>
      ]]></recognition>
      <resource-attributes>
        <file-name>memo.txt</file-name>
        <attachment>true</attachment>
      </resource-attributes>
    </resource>
  </note>
</en-export>
''';

const _unsafeEnex = '''
<?xml version="1.0" encoding="UTF-8"?>
<en-export export-date="20260823T034500Z" application="Evernote" version="10">
  <note>
    <title>Unsafe</title>
    <content><![CDATA[
      <en-note>
        <en-media type="image/png" hash="missing-resource"/>
        <en-crypt hint="unlock first">ciphertext</en-crypt>
      </en-note>
    ]]></content>
  </note>
</en-export>
''';

const _streamingEnex = '''
<?xml version="1.0" encoding="UTF-8"?>
<en-export export-date="20260823T034500Z" application="Evernote" version="10">
  <note>
    <guid>stream-1</guid>
    <title>First</title>
    <content><![CDATA[<en-note><div>One</div></en-note>]]></content>
    <resource>
      <data encoding="base64">aGVsbG8=</data>
      <mime>text/plain</mime>
    </resource>
  </note>
  <note>
    <title>日本語ノート</title>
    <content><![CDATA[<en-note><div>二番目</div></en-note>]]></content>
  </note>
</en-export>
''';
