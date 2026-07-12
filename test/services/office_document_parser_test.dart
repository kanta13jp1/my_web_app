import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/gamification_service.dart';
import 'package:my_web_app/services/import_service.dart';
import 'package:my_web_app/services/office_document_parser.dart';

/// テスト用に最小の OOXML (XLSX/DOCX) ZIP をメモリ上で組み立てる。
Uint8List _zip(Map<String, String> files) {
  final archive = Archive();
  files.forEach((name, content) {
    archive.addFile(ArchiveFile.string(name, content));
  });
  return ZipEncoder().encodeBytes(archive);
}

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

Uint8List _xlsx({
  required List<String> shared,
  required String sheetInner,
}) {
  final sst = '<?xml version="1.0" encoding="UTF-8"?>'
      '<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '${shared.map((s) => '<si><t>${_esc(s)}</t></si>').join()}'
      '</sst>';
  final sheet = '<?xml version="1.0" encoding="UTF-8"?>'
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<sheetData>$sheetInner</sheetData></worksheet>';
  return _zip({
    'xl/sharedStrings.xml': sst,
    'xl/worksheets/sheet1.xml': sheet,
  });
}

String _sharedCell(String ref, int index) =>
    '<c r="$ref" t="s"><v>$index</v></c>';

Uint8List _docx(String bodyInner) {
  final doc = '<?xml version="1.0" encoding="UTF-8"?>'
      '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
      '<w:body>$bodyInner</w:body></w:document>';
  return _zip({'word/document.xml': doc});
}

void main() {
  const parser = OfficeDocumentParser();

  group('OfficeDocumentParser.parseXlsxToRows', () {
    test('resolves shared strings and cell references', () {
      final bytes = _xlsx(
        shared: <String>['Title', 'Content', 'Tags', 'Memo A', 'Body A'],
        sheetInner: '<row r="1">'
            '${_sharedCell('A1', 0)}${_sharedCell('B1', 1)}${_sharedCell('C1', 2)}'
            '</row>'
            '<row r="2">'
            '${_sharedCell('A2', 3)}${_sharedCell('B2', 4)}'
            '</row>',
      );

      final rows = parser.parseXlsxToRows(bytes);
      expect(rows, hasLength(2));
      expect(rows[0], <String>['Title', 'Content', 'Tags']);
      expect(rows[1], <String>['Memo A', 'Body A']);
    });

    test('fills gaps from column refs and reads inline + numeric cells', () {
      // A1 shared, C1 inline string (B1 missing), D1 numeric.
      final bytes = _xlsx(
        shared: <String>['Alpha'],
        sheetInner: '<row r="1">'
            '${_sharedCell('A1', 0)}'
            '<c r="C1" t="inlineStr"><is><t>Gamma</t></is></c>'
            '<c r="D1"><v>42</v></c>'
            '</row>',
      );
      final rows = parser.parseXlsxToRows(bytes);
      expect(rows, hasLength(1));
      // B1 gap filled with empty string.
      expect(rows[0], <String>['Alpha', '', 'Gamma', '42']);
    });

    test('returns empty list for non-zip bytes', () {
      expect(
        parser.parseXlsxToRows(Uint8List.fromList(<int>[1, 2, 3])),
        isEmpty,
      );
    });
  });

  group('OfficeDocumentParser.parseDocxToText', () {
    test('joins paragraphs and honours tab/break', () {
      final bytes = _docx(
        '<w:p><w:r><w:t>First paragraph</w:t></w:r></w:p>'
        '<w:p><w:r><w:t>Second</w:t><w:tab/><w:t>tabbed</w:t></w:r></w:p>'
        '<w:p><w:r><w:t>Line</w:t><w:br/><w:t>break</w:t></w:r></w:p>',
      );
      final text = parser.parseDocxToText(bytes);
      expect(text, 'First paragraph\nSecond\ttabbed\nLine\nbreak');
    });

    test('returns empty string for non-zip bytes', () {
      expect(parser.parseDocxToText(Uint8List.fromList(<int>[9, 9, 9])), '');
    });
  });

  group('ImportService XLSX/DOCX', () {
    late ImportService service;
    setUp(() => service = ImportService(GamificationService()));

    test('parseXlsxBytes maps Title/Content/Tags columns to notes', () {
      final bytes = _xlsx(
        shared: <String>[
          'Title',
          'Content',
          'Tags',
          'Reading memo',
          'Imported body',
          'books,import',
        ],
        sheetInner: '<row r="1">'
            '${_sharedCell('A1', 0)}${_sharedCell('B1', 1)}${_sharedCell('C1', 2)}'
            '</row>'
            '<row r="2">'
            '${_sharedCell('A2', 3)}${_sharedCell('B2', 4)}${_sharedCell('C2', 5)}'
            '</row>',
      );

      final drafts = service.parseXlsxBytes(bytes);
      expect(drafts, hasLength(1));
      expect(drafts.first.title, 'Reading memo');
      expect(drafts.first.content, 'Imported body');
      expect(drafts.first.tags, <String>['books', 'import']);
      expect(drafts.first.source, 'xlsx');
    });

    test('parseXlsxBytes falls back to row-per-note without known headers', () {
      final bytes = _xlsx(
        shared: <String>['col1', 'col2', 'foo', 'bar', 'baz', 'qux'],
        sheetInner: '<row r="1">'
            '${_sharedCell('A1', 0)}${_sharedCell('B1', 1)}'
            '</row>'
            '<row r="2">'
            '${_sharedCell('A2', 2)}${_sharedCell('B2', 3)}'
            '</row>',
      );
      final drafts = service.parseXlsxBytes(bytes);
      // No Title/Content column -> every row (incl. first) becomes a note.
      expect(drafts, hasLength(2));
      expect(drafts.first.title, 'col1');
      expect(drafts.first.content, 'col1\ncol2');
      expect(drafts.last.title, 'foo');
      expect(drafts.last.content, 'foo\nbar');
    });

    test('parseDocxBytes builds a single note titled from the first line', () {
      final bytes = _docx(
        '<w:p><w:r><w:t>Meeting notes</w:t></w:r></w:p>'
        '<w:p><w:r><w:t>- point one</w:t></w:r></w:p>',
      );
      final draft = service.parseDocxBytes(bytes, fileName: 'notes.docx');
      expect(draft.source, 'docx');
      expect(draft.title, 'Meeting notes');
      expect(draft.content, 'Meeting notes\n- point one');
    });

    test('parseDocxBytes uses filename when the document has no text', () {
      final draft = service.parseDocxBytes(
        _docx('<w:p></w:p>'),
        fileName: 'empty-doc.docx',
      );
      expect(draft.title, 'empty-doc');
      expect(draft.content, '');
    });
  });
}
