import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
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
      expect(note.contentSha256, hasLength(64));
      expect(note.rawXml, contains('<note-attributes>'));

      final resource = note.resources.single;
      expect(resource.fileName, 'memo.txt');
      expect(resource.mimeType, 'text/plain');
      expect(resource.data, Uint8List.fromList(utf8.encode('hello')));
      expect(resource.dataSha256, hasLength(64));
      expect(resource.recognitionXml, contains('<recoIndex>'));
      expect(resource.toManifestJson()['byte_length'], 5);
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
        <div><en-todo checked="false"/>Follow up</div>
        <div><a href="evernote:///view/1/s1/guid/guid/">Internal link</a></div>
        <div><en-media type="text/plain" hash="5d41402abc4b2a76b9719d911017c592"/></div>
      </en-note>
    ]]></content>
    <created>20240102T030405Z</created>
    <updated>20240607T080910.123456Z</updated>
    <tag>archive</tag>
    <tag>ideas &amp; plans</tag>
    <note-attributes>
      <author>Migration test</author>
      <source-url>https://example.com/source?id=1&amp;lang=ja</source-url>
      <application-data key="future-key"><value>kept</value></application-data>
    </note-attributes>
    <resource>
      <data encoding="base64" hash="5d41402abc4b2a76b9719d911017c592">aGVsbG8=</data>
      <mime>text/plain</mime>
      <width>10</width>
      <height>20</height>
      <recognition><![CDATA[<recoIndex><item><t>hello</t></item></recoIndex>]]></recognition>
      <resource-attributes>
        <file-name>memo.txt</file-name>
        <attachment>true</attachment>
      </resource-attributes>
    </resource>
  </note>
</en-export>
''';
