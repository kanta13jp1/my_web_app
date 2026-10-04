import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/evernote_enex_parser.dart';

import '../../tool/evernote_enex_audit.dart';

const _syntheticEnex = '''<?xml version="1.0" encoding="UTF-8"?>
<en-export>
  <note>
    <title>Synthetic 日本語</title>
    <created>20240102T030405Z</created>
    <updated>20240203T040506Z</updated>
    <tag>synthetic-tag</tag>
    <content><![CDATA[<en-note>合成本文</en-note>]]></content>
    <resource>
      <data encoding="base64">aGVsbG8=</data>
      <mime>text/plain</mime>
      <resource-attributes><file-name>synthetic.txt</file-name></resource-attributes>
    </resource>
  </note>
  <note>
    <title>Second synthetic note</title>
    <content><![CDATA[<en-note>Second body</en-note>]]></content>
  </note>
</en-export>''';

void main() {
  final bytes = utf8.encode(_syntheticEnex);

  group('Evernote ENEX streaming audit', () {
    test('matches the buffered audit schema across one-byte chunks', () async {
      final parsed = const EvernoteEnexParser().parseBytes(
        Uint8List.fromList(bytes),
      );
      final report = await buildEvernoteEnexAuditReport(
        Stream<List<int>>.fromIterable(
          bytes.map((byte) => <int>[byte]),
        ),
        fileName: 'synthetic.enex',
        sizeBytes: bytes.length,
      );
      expect(report, <String, dynamic>{
        'fileName': 'synthetic.enex',
        'sizeBytes': bytes.length,
        'exportSha256': parsed.exportSha256,
        'noteCount': parsed.notes.length,
        'resourceCount': parsed.resourceCount,
        'warningCount': parsed.warnings.length,
        'notes': <Map<String, dynamic>>[
          for (var index = 0; index < parsed.notes.length; index += 1)
            <String, dynamic>{
              'ordinal': index + 1,
              'hasSourceId': parsed.notes[index].sourceId.isNotEmpty,
              'hasCreatedAt': parsed.notes[index].createdAt != null,
              'hasUpdatedAt': parsed.notes[index].updatedAt != null,
              'contentSha256': parsed.notes[index].contentSha256,
              'tagCount': parsed.notes[index].tags.length,
              'resourceCount': parsed.notes[index].resources.length,
              'hasRawEnml': parsed.notes[index].enml.trim().isNotEmpty,
              'hasRawXml': parsed.notes[index].rawXml.trim().isNotEmpty,
            },
        ],
      });
      final encoded = jsonEncode(report);
      expect(encoded, isNot(contains('合成本文')));
      expect(encoded, isNot(contains('Synthetic 日本語')));
      expect(encoded, isNot(contains('aGVsbG8=')));
      expect(encoded, isNot(contains('synthetic-tag')));
    });

    test('rejects a stream shorter than its declared size', () async {
      await expectLater(
        buildEvernoteEnexAuditReport(
          Stream<List<int>>.value(bytes),
          fileName: 'synthetic.enex',
          sizeBytes: bytes.length + 1,
        ),
        throwsStateError,
      );
    });

    test('rejects a stream larger than its declared size', () async {
      await expectLater(
        buildEvernoteEnexAuditReport(
          Stream<List<int>>.value(bytes),
          fileName: 'synthetic.enex',
          sizeBytes: bytes.length - 1,
        ),
        throwsStateError,
      );
    });

    test('rejects empty input', () async {
      await expectLater(
        buildEvernoteEnexAuditReport(
          const Stream<List<int>>.empty(),
          fileName: 'synthetic.enex',
          sizeBytes: 0,
        ),
        throwsFormatException,
      );
    });
  });

  group('Evernote ENEX audit command', () {
    late Directory temporaryDirectory;
    late StringBuffer output;
    late StringBuffer errors;

    setUp(() async {
      temporaryDirectory =
          await Directory.systemTemp.createTemp('evernote-audit-synthetic-');
      output = StringBuffer();
      errors = StringBuffer();
    });
    tearDown(() async {
      await temporaryDirectory.delete(recursive: true);
    });

    test('returns usage status without reading input', () async {
      expect(
        await runEvernoteEnexAudit(
          <String>[],
          output: output,
          errors: errors,
        ),
        64,
      );
      expect(output.toString(), isEmpty);
      expect(errors.toString(), contains('Usage:'));
    });

    test('returns missing-file status without disclosing its path', () async {
      final missing = File(
        '${temporaryDirectory.path}/private-synthetic-missing.enex',
      );
      expect(
        await runEvernoteEnexAudit(
          <String>[missing.path],
          output: output,
          errors: errors,
        ),
        66,
      );
      expect(output.toString(), isEmpty);
      expect(errors.toString(), 'ENEX file not found.\n');
      expect(errors.toString(), isNot(contains(missing.path)));
    });

    test('emits a complete report for a valid synthetic file', () async {
      final file = File('${temporaryDirectory.path}/synthetic.enex');
      await file.writeAsBytes(bytes);
      expect(
        await runEvernoteEnexAudit(
          <String>[file.path],
          output: output,
          errors: errors,
        ),
        0,
      );
      final report = jsonDecode(output.toString()) as Map<String, dynamic>;
      expect(report['noteCount'], 2);
      expect(report['resourceCount'], 1);
      expect(report['sizeBytes'], bytes.length);
      expect(errors.toString(), isEmpty);
    });

    test('suppresses partial reports and private parser error details', () async {
      final file = File('${temporaryDirectory.path}/private-synthetic.enex');
      const privateMarker = 'PRIVATE_SYNTHETIC_MARKER';
      await file.writeAsString(
        _syntheticEnex.replaceFirst(
          '</en-export>',
          '<note><title>$privateMarker</title>',
        ),
      );
      expect(
        await runEvernoteEnexAudit(
          <String>[file.path],
          output: output,
          errors: errors,
        ),
        65,
      );
      expect(output.toString(), isEmpty);
      expect(
        errors.toString(),
        'ENEX audit failed; no complete report was produced.\n',
      );
      expect(errors.toString(), isNot(contains(privateMarker)));
      expect(errors.toString(), isNot(contains(file.path)));
    });
  });
}
