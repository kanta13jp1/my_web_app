import 'dart:convert';
import 'dart:typed_data';

import '../models/spreadsheet_document.dart';

class SpreadsheetCsvCodec {
  const SpreadsheetCsvCodec();

  SpreadsheetSheet decode({
    required Uint8List bytes,
    required String sheetId,
    required String sheetName,
  }) {
    var source = utf8.decode(bytes, allowMalformed: true);
    if (source.startsWith('\uFEFF')) source = source.substring(1);
    final rows = _parseRows(source);
    final cells = <String, String>{};
    var columnCount = 0;
    for (var row = 0; row < rows.length; row++) {
      final values = rows[row];
      if (values.length > columnCount) columnCount = values.length;
      for (var column = 0; column < values.length; column++) {
        final value = values[column];
        if (value.isEmpty) continue;
        cells[CellAddress(row: row, column: column).key] = value;
      }
    }
    return SpreadsheetSheet(
      id: sheetId,
      name: sheetName,
      rowCount: rows.length < 30 ? 30 : rows.length,
      columnCount: columnCount < 12 ? 12 : columnCount,
      cells: Map<String, String>.unmodifiable(cells),
    );
  }

  Uint8List encode(SpreadsheetSheet sheet) {
    var lastRow = -1;
    var lastColumn = -1;
    for (final entry in sheet.cells.entries) {
      if (entry.value.isEmpty) continue;
      final parts = entry.key.split(':');
      if (parts.length != 2) continue;
      final row = int.tryParse(parts[0]);
      final column = int.tryParse(parts[1]);
      if (row == null || column == null) continue;
      if (row > lastRow) lastRow = row;
      if (column > lastColumn) lastColumn = column;
    }

    final buffer = StringBuffer('\uFEFF');
    if (lastRow < 0 || lastColumn < 0) {
      return Uint8List.fromList(utf8.encode(buffer.toString()));
    }
    for (var row = 0; row <= lastRow; row++) {
      for (var column = 0; column <= lastColumn; column++) {
        if (column > 0) buffer.write(',');
        buffer.write(
          _escape(sheet.inputAt(CellAddress(row: row, column: column))),
        );
      }
      if (row < lastRow) buffer.write('\r\n');
    }
    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }

  List<List<String>> _parseRows(String source) {
    if (source.isEmpty) return const <List<String>>[];
    final rows = <List<String>>[];
    var row = <String>[];
    var field = StringBuffer();
    var insideQuotes = false;

    for (var index = 0; index < source.length; index++) {
      final character = source[index];
      if (insideQuotes) {
        if (character == '"') {
          if (index + 1 < source.length && source[index + 1] == '"') {
            field.write('"');
            index++;
          } else {
            insideQuotes = false;
          }
        } else {
          field.write(character);
        }
        continue;
      }

      if (character == '"' && field.isEmpty) {
        insideQuotes = true;
      } else if (character == ',') {
        row.add(field.toString());
        field = StringBuffer();
      } else if (character == '\r' || character == '\n') {
        row.add(field.toString());
        rows.add(row);
        row = <String>[];
        field = StringBuffer();
        if (character == '\r' &&
            index + 1 < source.length &&
            source[index + 1] == '\n') {
          index++;
        }
      } else {
        field.write(character);
      }
    }

    if (insideQuotes) {
      throw const FormatException('CSVの引用符が閉じられていません。');
    }
    row.add(field.toString());
    rows.add(row);
    if (rows.length > 1 && rows.last.every((value) => value.isEmpty)) {
      rows.removeLast();
    }
    return rows;
  }

  String _escape(String value) {
    if (!value.contains(RegExp('[,"\r\n]'))) return value;
    return '"${value.replaceAll('"', '""')}"';
  }
}
