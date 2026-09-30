import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/domain/models/spreadsheet_document.dart';
import 'package:my_web_app/domain/use_cases/evaluate_spreadsheet_formula_use_case.dart';
import 'package:my_web_app/domain/use_cases/spreadsheet_xlsx_codec.dart';

const ns = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main';
const rels =
    'http://schemas.openxmlformats.org/officeDocument/2006/relationships';

Uint8List fixture(String cells,
    {String target = 'worksheets/custom.xml', String? strings}) {
  final files = <String, String>{
    'xl/workbook.xml':
        '<workbook xmlns="$ns" xmlns:r="$rels"><sheets><sheet name="売上" sheetId="7" r:id="rId42"/></sheets></workbook>',
    'xl/_rels/workbook.xml.rels':
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId42" Type="$rels/worksheet" Target="$target"/></Relationships>',
    'xl/worksheets/custom.xml':
        '<worksheet xmlns="$ns"><sheetData><row r="1">$cells</row></sheetData></worksheet>',
    if (strings != null)
      'xl/sharedStrings.xml': '<sst xmlns="$ns">$strings</sst>',
  };
  final archive = Archive();
  for (final entry in files.entries) {
    final content = utf8.encode(entry.value);
    archive.addFile(ArchiveFile(entry.key, content.length, content));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

void main() {
  const codec = SpreadsheetXlsxCodec();
  test('roundtrips multiple sheets, sparse cells, whitespace and formulas', () {
    final source = SpreadsheetDocument.blank().copyWith(
      sheets: [
        SpreadsheetSheet.blank(id: 'a', name: '売上 & 予算').copyWith(
          cells: {
            '0:0': ' 日本語 <&> " ',
            '0:1': '00123',
            '1:0': '12.5',
            '1:1': '=A2*2',
          },
        ),
        SpreadsheetSheet.blank(id: 'b', name: '空'),
      ],
    );
    final decoded = codec.decode(codec.encode(source));
    expect(decoded, hasLength(2));
    expect(decoded.first.name, '売上 & 予算');
    expect(decoded.first.cells, source.sheets.first.cells);
    expect(decoded.last.cells, isEmpty);
    expect(decoded.first.textCells, contains('0:1'));
  });
  test('uses relationships and reads shared rich strings and inline strings',
      () {
    final decoded = codec.decode(
      fixture(
        '<c r="A1" t="s"><v>0</v></c><c r="B1" t="inlineStr"><is><t>001</t></is></c><c r="C1"><f>A2+1</f><v>3</v></c>',
        strings: '<si><r><t>日</t></r><r><t>本語</t></r></si>',
      ),
    );
    expect(decoded.first.cells, {'0:0': '日本語', '0:1': '001', '0:2': '=A2+1'});
  });
  test('literal formula-like text stays literal through JSON and XLSX', () {
    final sheet = codec
        .decode(fixture('<c r="A1" t="inlineStr"><is><t>=1+2</t></is></c>'))
        .single;
    final document = SpreadsheetDocument.fromJson(SpreadsheetDocument.blank()
        .copyWith(sheets: [sheet], activeSheetId: sheet.id).toJson());
    expect(
        const EvaluateSpreadsheetFormulaUseCase()(
                document, const CellAddress(row: 0, column: 0))
            .displayValue,
        '=1+2');
    final decoded = codec.decode(codec.encode(document)).single;
    expect(decoded.textCells, ['0:0']);
    expect(decoded.cells['0:0'], '=1+2');
  });
  test('SUM ignores literal formula-like text in ranges', () {
    final sheet = SpreadsheetSheet.blank(id: 'a', name: '売上').copyWith(
      cells: {'0:0': '=ignored', '1:0': '5', '2:0': '=SUM(A1:A2)'},
      textCells: ['0:0'],
    );
    final doc = SpreadsheetDocument.blank()
        .copyWith(sheets: [sheet], activeSheetId: 'a');
    expect(
        const EvaluateSpreadsheetFormulaUseCase()(
                doc, const CellAddress(row: 2, column: 0))
            .displayValue,
        '5');
  });
  test('rejects excessive formula range work', () {
    final doc = SpreadsheetDocument.blank().replaceSheet(
        SpreadsheetSheet.blank(id: 'sheet-1', name: 'a')
            .copyWith(cells: {'0:0': '=SUM(A2:A1000000)'}));
    expect(
        const EvaluateSpreadsheetFormulaUseCase()(
                doc, const CellAddress(row: 0, column: 0))
            .displayValue,
        '#NUM!');
  });
  for (final cell in [
    '<c r="A1" t="s"><v>99</v></c>',
    '<c r="A1"><f t="shared" si="0">A2+1</f></c>',
    '<c r="A1"><f t="array" ref="A1:A2">A2+1</f></c>',
    '<c r="A1001"><v>1</v></c>',
    '<c r="A1" t="b"><v>1</v></c>',
    '<c r="A1"><v>not-a-number</v></c>',
    '<c r="A1"><v>1</v></c><c r="A1"><v>2</v></c>',
  ]) {
    test('rejects unsupported or invalid cell $cell', () {
      expect(() => codec.decode(fixture(cell)), throwsFormatException);
    });
  }
  test('rejects traversal relationships', () {
    expect(() => codec.decode(fixture('', target: '../other.xml')),
        throwsFormatException);
  });
  test('rejects oversized central directory before decompression', () {
    final bytes = fixture('');
    final data = ByteData.sublistView(bytes);
    for (var i = 0; i < bytes.length - 46; i++) {
      if (data.getUint32(i, Endian.little) == 0x02014b50) {
        data.setUint32(i + 24, 9 * 1024 * 1024, Endian.little);
        break;
      }
    }
    expect(() => codec.decode(bytes), throwsFormatException);
  });
  test('rejects invalid output names and XML controls', () {
    for (final sheet in [
      SpreadsheetSheet.blank(id: 'a', name: 'invalid/name'),
      SpreadsheetSheet.blank(id: 'a', name: 'valid')
          .copyWith(cells: {'0:0': '\u0000'}),
    ]) {
      expect(
          () => codec
              .encode(SpreadsheetDocument.blank().copyWith(sheets: [sheet])),
          throwsFormatException);
    }
  });
  test('rejects duplicate names case-insensitively', () {
    final doc = SpreadsheetDocument.blank().copyWith(
      sheets: [
        SpreadsheetSheet.blank(id: 'a', name: 'Sales'),
        SpreadsheetSheet.blank(id: 'b', name: 'sales'),
      ],
    );
    expect(() => codec.encode(doc), throwsFormatException);
  });
  test('independent openpyxl input and output interoperability in cloud', () {
    final directory = Platform.environment['XLSX_INTEROP_DIR'];
    if (directory == null) return;
    final decoded =
        codec.decode(File('$directory/input.xlsx').readAsBytesSync());
    expect(decoded.map((s) => s.name), ['売上', '予算']);
    expect(decoded.first.cells['0:0'], '商品');
    expect(decoded.first.cells['1:1'], '12.5');
    expect(decoded.first.cells['2:1'], '=B2*2');
    expect(decoded.first.cells['0:2'], '00123');
    final doc = SpreadsheetDocument.blank()
        .copyWith(sheets: decoded, activeSheetId: decoded.first.id);
    File('$directory/output.xlsx').writeAsBytesSync(codec.encode(doc));
  });
}
