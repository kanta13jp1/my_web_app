import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/domain/models/spreadsheet_document.dart';
import 'package:my_web_app/domain/use_cases/spreadsheet_csv_codec.dart';

void main() {
  const codec = SpreadsheetCsvCodec();

  test('decodes quoted commas, line breaks and escaped quotes', () {
    final bytes = Uint8List.fromList(
      utf8.encode(
        '\uFEFF商品,備考,金額\r\n'
        'りんご,"青森, 長野",120\r\n'
        'メモ,"1行目\n2行目 ""確認""",',
      ),
    );

    final sheet = codec.decode(
      bytes: bytes,
      sheetId: 'sheet-2',
      sheetName: '売上',
    );

    expect(sheet.inputAt(const CellAddress(row: 0, column: 0)), '商品');
    expect(sheet.inputAt(const CellAddress(row: 1, column: 1)), '青森, 長野');
    expect(
      sheet.inputAt(const CellAddress(row: 2, column: 1)),
      '1行目\n2行目 "確認"',
    );
    expect(sheet.inputAt(const CellAddress(row: 2, column: 2)), '');
  });

  test('encodes only the used range with an Excel-friendly UTF-8 BOM', () {
    const sheet = SpreadsheetSheet(
      id: 'sheet-1',
      name: 'シート1',
      rowCount: 30,
      columnCount: 12,
      cells: <String, String>{
        '0:0': '商品',
        '0:1': '備考',
        '1:0': 'りんご',
        '1:1': '青森, 長野',
        '2:1': '=SUM(C1:C2)',
      },
    );

    final encodedBytes = codec.encode(sheet);
    final encoded = utf8.decode(encodedBytes.sublist(3));

    expect(encodedBytes.take(3), <int>[0xEF, 0xBB, 0xBF]);
    expect(
      encoded,
      '商品,備考\r\nりんご,"青森, 長野"\r\n,=SUM(C1:C2)',
    );
  });
}
