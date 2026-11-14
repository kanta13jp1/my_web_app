import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../models/spreadsheet_document.dart';

/// A bounded, data-only SpreadsheetML adapter, not a full Excel renderer.
class SpreadsheetXlsxCodec {
  const SpreadsheetXlsxCodec();

  static const compatibilityNotice = 'XLSXはセル値・通常の数式・シート名のみ対応しています。'
      '書式・結合・グラフ・画像・マクロ等は保持しません。'
      '日付書式の数値はシリアル値になります。未対応の数式は計算できません。'
      '元のExcelファイルは変更せず、書き出しは別名で保存してください。';
  static const _ns =
      'http://schemas.openxmlformats.org/spreadsheetml/2006/main';
  static const _rels =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
  static const _package =
      'http://schemas.openxmlformats.org/package/2006/relationships';
  static const _maxBytes = 16 * 1024 * 1024;
  static const _maxExpanded = 32 * 1024 * 1024;
  static const _maxPart = 8 * 1024 * 1024;

  List<SpreadsheetSheet> decode(Uint8List bytes) {
    _checkZip(bytes);
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final parts = <String, ArchiveFile>{};
      for (final file in archive.files) {
        if (file.isFile) {
          if (parts.containsKey(file.name)) {
            throw const FormatException('XLSX内に重複したファイルがあります。');
          }
          parts[file.name] = file;
        }
      }
      XmlDocument read(String name) {
        final file = parts[name];
        if (file == null) throw FormatException('XLSXの必要な情報がありません: $name');
        final output = _BoundedXlsxOutput(_maxPart);
        file.decompress(output);
        final content = output.getBytes();
        if (content.length != file.size || getCrc32(content) != file.crc32) {
          throw const FormatException('XLSXのサイズまたはチェックサムが不正です。');
        }
        final source = utf8.decode(content);
        if (RegExp(r'<!DOCTYPE|<!ENTITY', caseSensitive: false)
            .hasMatch(source)) {
          throw const FormatException('外部エンティティを含むXMLは読み込めません。');
        }
        return XmlDocument.parse(source);
      }

      final workbook = read('xl/workbook.xml');
      if (workbook.rootElement.namespaceUri != _ns) {
        throw const FormatException('このXLSX形式は未対応です。');
      }
      final relationships = <String, String>{};
      for (final rel
          in read('xl/_rels/workbook.xml.rels').rootElement.childElements) {
        if (rel.name.local != 'Relationship') continue;
        if (rel.getAttribute('Type') != '$_rels/worksheet') continue;
        if (rel.getAttribute('TargetMode') == 'External') {
          throw const FormatException('外部参照シートは読み込めません。');
        }
        final target = rel.getAttribute('Target') ?? '';
        if (target.contains('..') ||
            target.contains('\\') ||
            target.contains(':')) {
          throw const FormatException('不正なシート参照です。');
        }
        relationships[rel.getAttribute('Id') ?? ''] =
            target.startsWith('/') ? target.substring(1) : 'xl/$target';
      }
      final strings = <String>[];
      if (parts.containsKey('xl/sharedStrings.xml')) {
        for (final item in _elements(read('xl/sharedStrings.xml'), 'si')) {
          strings.add(_text(item));
        }
      }
      final result = <SpreadsheetSheet>[];
      final names = <String>{};
      var totalCells = 0;
      for (final sheet in _elements(workbook, 'sheet')) {
        if (result.length >= 20) {
          throw const FormatException('XLSXは20シートまで対応しています。');
        }
        final name = sheet.getAttribute('name') ?? '';
        _checkName(name);
        if (!names.add(name.toLowerCase())) {
          throw const FormatException('シート名が重複しています。');
        }
        final path = relationships[sheet.getAttribute('id', namespace: _rels)];
        if (path == null) throw const FormatException('シートの参照が見つかりません。');
        final worksheet = read(path);
        if (worksheet.rootElement.name.local != 'worksheet' ||
            worksheet.rootElement.namespaceUri != _ns) {
          throw const FormatException('通常のワークシート以外は未対応です。');
        }
        final cells = <String, String>{};
        final textCells = <String>[];
        final seen = <String>{};
        var rows = 30;
        var columns = 12;
        for (final cell in _elements(worksheet, 'c')) {
          if (++totalCells > 50000) {
            throw const FormatException('XLSXのセル数が上限を超えています。');
          }
          final address = CellAddress.tryParse(cell.getAttribute('r') ?? '');
          if (address == null || address.row >= 1000 || address.column >= 100) {
            throw const FormatException('XLSXは1000行・100列まで対応しています。');
          }
          if (!seen.add(address.key)) {
            throw const FormatException('セルの参照が重複しています。');
          }
          if (address.row + 1 > rows) rows = address.row + 1;
          if (address.column + 1 > columns) columns = address.column + 1;
          if (rows * columns > 20000) {
            throw const FormatException('1シートの表示範囲は20000セルまでです。');
          }
          final formula = _child(cell, 'f');
          final type = cell.getAttribute('t') ?? 'n';
          var value = _child(cell, 'v')?.innerText ?? '';
          var literal = false;
          if (formula != null) {
            if ((formula.getAttribute('t') ?? 'normal') != 'normal' ||
                formula.innerText.isEmpty) {
              throw const FormatException('共有数式・配列数式は未対応です。通常の数式に変換してください。');
            }
            value = '=${formula.innerText}';
          } else if (type == 's') {
            final index = int.tryParse(value);
            if (index == null || index < 0 || index >= strings.length) {
              throw const FormatException('共有文字列の参照が不正です。');
            }
            value = strings[index];
            literal = true;
          } else if (type == 'inlineStr') {
            final inline = _child(cell, 'is');
            value = inline == null ? '' : _text(inline);
            literal = true;
          } else if (type == 'str') {
            value = _decodeExcelText(value);
            literal = true;
          } else if (type != 'n') {
            throw const FormatException('論理値・エラー値・ISO日付型は未対応です。');
          } else if (value.isNotEmpty &&
              !(double.tryParse(value)?.isFinite ?? false)) {
            throw const FormatException('数値セルが不正です。');
          }
          _checkText(value);
          if (value.isNotEmpty) {
            cells[address.key] = value;
            if (literal) textCells.add(address.key);
          }
        }
        result.add(
          SpreadsheetSheet(
            id: 'xlsx-${result.length + 1}',
            name: name,
            rowCount: rows,
            columnCount: columns,
            cells: Map<String, String>.unmodifiable(cells),
            textCells: List<String>.unmodifiable(textCells),
          ),
        );
      }
      if (result.isEmpty) throw const FormatException('XLSXにシートがありません。');
      return List<SpreadsheetSheet>.unmodifiable(result);
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('XLSXが破損しているか、暗号化されています。');
    }
  }

  Uint8List encode(SpreadsheetDocument document) {
    if (document.sheets.isEmpty || document.sheets.length > 20) {
      throw const FormatException('XLSXは1〜20シートまで対応しています。');
    }
    final archive = Archive();
    var totalBytes = 0;
    void add(String name, String xml) {
      final content = utf8.encode(
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>$xml',
      );
      totalBytes += content.length;
      if (content.length > _maxPart || totalBytes > _maxExpanded) {
        throw const FormatException('XLSXのサイズが上限を超えています。');
      }
      archive.addFile(ArchiveFile(name, content.length, content));
    }

    final names = <String>{};
    final sheets = StringBuffer();
    final rels = StringBuffer();
    final overrides = StringBuffer();
    var cellCount = 0;
    for (var i = 0; i < document.sheets.length; i++) {
      final sheet = document.sheets[i];
      _checkName(sheet.name);
      if (!names.add(sheet.name.toLowerCase())) {
        throw const FormatException('書き出すシート名が重複しています。');
      }
      final n = i + 1;
      sheets.write(
        '<sheet name="${_escape(sheet.name)}" sheetId="$n" r:id="rId$n"/>',
      );
      rels.write(
        '<Relationship Id="rId$n" Type="$_rels/worksheet" Target="worksheets/sheet$n.xml"/>',
      );
      overrides.write(
        '<Override PartName="/xl/worksheets/sheet$n.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>',
      );
      final byRow = <int, Map<int, String>>{};
      var maxRow = 30;
      var maxColumn = 12;
      for (final entry in sheet.cells.entries) {
        if (entry.value.isEmpty) continue;
        if (++cellCount > 50000) {
          throw const FormatException('XLSXのセル数が上限を超えています。');
        }
        final coordinates = entry.key.split(':');
        final row =
            coordinates.length == 2 ? int.tryParse(coordinates[0]) : null;
        final col =
            coordinates.length == 2 ? int.tryParse(coordinates[1]) : null;
        if (row == null ||
            col == null ||
            row < 0 ||
            col < 0 ||
            row >= 1000 ||
            col >= 100 ||
            (row + 1) * (col + 1) > 20000) {
          throw const FormatException('書き出すセル範囲が上限を超えています。');
        }
        _checkText(entry.value);
        if (row + 1 > maxRow) maxRow = row + 1;
        if (col + 1 > maxColumn) maxColumn = col + 1;
        if (maxRow * maxColumn > 20000) {
          throw const FormatException('1シートの表示範囲は20000セルまでです。');
        }
        final address = CellAddress(row: row, column: col);
        final value = entry.value;
        String cell;
        if (!sheet.textCells.contains(entry.key) && value.startsWith('=')) {
          if (value.length == 1) throw const FormatException('空の数式は書き出せません。');
          cell =
              '<c r="${address.label}"><f>${_escape(value.substring(1))}</f></c>';
        } else if (!sheet.textCells.contains(entry.key) &&
            RegExp(r'^-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?$')
                .hasMatch(value) &&
            (double.tryParse(value)?.isFinite ?? false)) {
          cell = '<c r="${address.label}"><v>$value</v></c>';
        } else {
          cell =
              '<c r="${address.label}" t="inlineStr"><is><t xml:space="preserve">${_escape(_encodeExcelText(value))}</t></is></c>';
        }
        (byRow[row] ??= <int, String>{})[col] = cell;
      }
      final rows = byRow.keys.toList()..sort();
      final body = StringBuffer();
      for (final row in rows) {
        final columns = byRow[row]!.keys.toList()..sort();
        body.write(
          '<row r="${row + 1}">${columns.map((c) => byRow[row]![c]).join()}</row>',
        );
      }
      add(
        'xl/worksheets/sheet$n.xml',
        '<worksheet xmlns="$_ns"><sheetData>$body</sheetData></worksheet>',
      );
    }
    add(
      'xl/workbook.xml',
      '<workbook xmlns="$_ns" xmlns:r="$_rels"><sheets>$sheets</sheets><calcPr calcId="0" fullCalcOnLoad="1" forceFullCalc="1"/></workbook>',
    );
    add(
      'xl/_rels/workbook.xml.rels',
      '<Relationships xmlns="$_package">$rels</Relationships>',
    );
    add(
      '_rels/.rels',
      '<Relationships xmlns="$_package"><Relationship Id="rId1" Type="$_rels/officeDocument" Target="xl/workbook.xml"/></Relationships>',
    );
    add(
      '[Content_Types].xml',
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>$overrides</Types>',
    );
    final bytes = Uint8List.fromList(ZipEncoder().encode(archive));
    if (bytes.length > _maxBytes) {
      throw const FormatException('XLSXは16MBまで対応しています。');
    }
    return bytes;
  }

  static Iterable<XmlElement> _elements(XmlNode node, String local) =>
      node.descendants
          .whereType<XmlElement>()
          .where((e) => e.name.local == local && e.namespaceUri == _ns);
  static XmlElement? _child(XmlElement node, String name) {
    for (final child in node.childElements) {
      if (child.name.local == name && child.namespaceUri == _ns) return child;
    }
    return null;
  }

  static String _text(XmlElement node) {
    final text = StringBuffer();
    for (final child in node.childElements) {
      if (child.namespaceUri != _ns) continue;
      if (child.name.local == 't') {
        text.write(_decodeExcelText(child.innerText));
      } else if (child.name.local == 'r') {
        text.write(_decodeExcelText(_child(child, 't')?.innerText ?? ''));
      }
    }
    // rPh contains pronunciation metadata, not the visible cell value.
    return text.toString();
  }

  static String _decodeExcelText(String value) => value.replaceAllMapped(
        RegExp(r'_x([0-9a-fA-F]{4})_'),
        (match) => String.fromCharCode(int.parse(match.group(1)!, radix: 16)),
      );
  static String _encodeExcelText(String value) => value
      .replaceAllMapped(
        RegExp(r'_x[0-9a-fA-F]{4}_'),
        (match) => '_x005F_${match.group(0)!.substring(1)}',
      )
      .replaceAll('\r', '_x000D_');
  static String _escape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
  static void _checkText(String value) {
    if (value.length > 32767 ||
        RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]').hasMatch(value)) {
      throw const FormatException('セル文字列が長すぎるか、使用できない制御文字を含んでいます。');
    }
  }

  static void _checkName(String name) {
    _checkText(name);
    if (name.trim().isEmpty ||
        name.length > 31 ||
        RegExp(r'[\\/\?\*\[\]:]').hasMatch(name) ||
        name.startsWith("'") ||
        name.endsWith("'")) {
      throw const FormatException('Excelのシート名は31文字以内で、禁止文字を含められません。');
    }
  }

  /// Check central-directory sizes before any decompression (no ZIP64/encryption).
  static void _checkZip(Uint8List bytes) {
    if (bytes.length < 22 || bytes.length > _maxBytes) {
      throw const FormatException('XLSXは16MBまで対応しています。');
    }
    final data = ByteData.sublistView(bytes);
    int u16(int p) => data.getUint16(p, Endian.little);
    int u32(int p) => data.getUint32(p, Endian.little);
    var end = -1;
    for (var p = bytes.length - 22; p >= 0 && p >= bytes.length - 65557; p--) {
      if (u32(p) == 0x06054b50 && p + 22 + u16(p + 20) == bytes.length) {
        end = p;
        break;
      }
    }
    if (end < 0 ||
        u16(end + 4) != 0 ||
        u16(end + 6) != 0 ||
        u16(end + 8) != u16(end + 10)) {
      throw const FormatException('通常のZIP形式のXLSXではありません。');
    }
    final count = u16(end + 10);
    var position = u32(end + 16);
    final directoryEnd = position + u32(end + 12);
    if (count == 0 || count > 512 || directoryEnd != end) {
      throw const FormatException('XLSX内のファイル数またはZIP形式が未対応です。');
    }
    var total = 0;
    final names = <String>{};
    for (var i = 0; i < count; i++) {
      if (position + 46 > directoryEnd ||
          u32(position) != 0x02014b50 ||
          (u16(position + 8) & 1) != 0) {
        throw const FormatException('XLSXが破損しているか、暗号化されています。');
      }
      final size = u32(position + 24);
      if (((u32(position + 38) >> 16) & 0xf000) == 0xa000 ||
          (u16(position + 10) != 0 && u16(position + 10) != 8)) {
        throw const FormatException('リンクまたは未対応のZIP圧縮形式です。');
      }
      final nameEnd = position + 46 + u16(position + 28);
      if (nameEnd > directoryEnd ||
          !names.add(base64.encode(bytes.sublist(position + 46, nameEnd)))) {
        throw const FormatException('XLSXのファイル名が不正または重複しています。');
      }
      total += size;
      if (size > _maxPart || total > _maxExpanded) {
        throw const FormatException('XLSX展開サイズが上限を超えています。');
      }
      position +=
          46 + u16(position + 28) + u16(position + 30) + u16(position + 32);
    }
    if (position != directoryEnd) {
      throw const FormatException('XLSXのZIP情報が不正です。');
    }
  }
}

/// Enforce the limit on actual inflation, not only attacker-controlled ZIP sizes.
class _BoundedXlsxOutput extends OutputMemoryStream {
  _BoundedXlsxOutput(this.limit);
  final int limit;

  void _check(int count) {
    if (length + count > limit) {
      throw const FormatException('XLSX展開サイズが上限を超えています。');
    }
  }

  @override
  void writeByte(int value) {
    _check(1);
    super.writeByte(value);
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    _check(length ?? bytes.length);
    super.writeBytes(bytes, length: length);
  }

  @override
  void writeStream(InputStream stream) {
    _check(stream.length);
    super.writeStream(stream);
  }
}
