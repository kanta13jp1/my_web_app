import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// XLSX (Excel) / DOCX (Word) は ZIP アーカイブ内に XML を格納した Office Open XML
/// 形式。ここでは Flutter 非依存の純関数として、バイト列から
/// - XLSX → セル値の2次元配列 (行 × 列)
/// - DOCX → 段落結合済みプレーンテキスト
/// を抽出する。ImportService から呼び出してノートに変換する。
///
/// 名前空間プレフィックス (w:, ...) の有無に依存しないよう、要素の照合は
/// [XmlElement.localName] で行う。
class OfficeDocumentParser {
  const OfficeDocumentParser();

  /// 上限（暴走・巨大ファイル対策）。
  static const int maxRows = 5000;
  static const int maxCols = 256;

  /// XLSX バイト列を最初のワークシートの行配列に変換する。
  /// 共有文字列 (`xl/sharedStrings.xml`) を解決し、セル参照 (A1, B2...) から
  /// 列位置を復元して欠落セルは空文字で埋める。
  List<List<String>> parseXlsxToRows(Uint8List bytes) {
    final archive = _decodeZip(bytes);
    if (archive == null) return const <List<String>>[];

    final sharedStrings = _readSharedStrings(archive);
    final sheetBytes = _firstWorksheetBytes(archive);
    if (sheetBytes == null) return const <List<String>>[];

    final XmlDocument doc;
    try {
      doc = XmlDocument.parse(utf8.decode(sheetBytes, allowMalformed: true));
    } on XmlException {
      return const <List<String>>[];
    }

    final rows = <List<String>>[];
    for (final rowEl in _byLocalName(doc, 'row')) {
      final cells = <int, String>{};
      var maxCol = -1;
      var fallbackCol = 0;
      for (final cell in rowEl.childElements.where((e) => e.localName == 'c')) {
        final ref = cell.getAttribute('r') ?? '';
        final parsedCol = _columnIndexFromRef(ref);
        final col = parsedCol >= 0 ? parsedCol : fallbackCol;
        fallbackCol = col + 1;
        if (col >= maxCols) continue;
        cells[col] = _cellValue(cell, sharedStrings);
        if (col > maxCol) maxCol = col;
      }
      final row = <String>[
        for (var i = 0; i <= maxCol; i++) cells[i] ?? '',
      ];
      rows.add(row);
      if (rows.length >= maxRows) break;
    }
    return rows;
  }

  /// DOCX バイト列を段落 (`w:p`) 単位で改行結合したプレーンテキストに変換する。
  String parseDocxToText(Uint8List bytes) {
    final archive = _decodeZip(bytes);
    if (archive == null) return '';
    final docBytes = _fileBytes(archive, 'word/document.xml');
    if (docBytes == null) return '';

    final XmlDocument doc;
    try {
      doc = XmlDocument.parse(utf8.decode(docBytes, allowMalformed: true));
    } on XmlException {
      return '';
    }

    final paragraphs = <String>[];
    for (final p in _byLocalName(doc, 'p')) {
      final buffer = StringBuffer();
      // 段落内のテキスト (w:t) / タブ (w:tab) / 改行 (w:br) を順に走査する。
      for (final node in p.descendants.whereType<XmlElement>()) {
        switch (node.localName) {
          case 't':
            buffer.write(node.innerText);
            break;
          case 'tab':
            buffer.write('\t');
            break;
          case 'br':
          case 'cr':
            buffer.write('\n');
            break;
        }
      }
      paragraphs.add(buffer.toString());
    }

    return paragraphs.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }

  // ── 内部ヘルパー ─────────────────────────────────────────────────────────

  Archive? _decodeZip(Uint8List bytes) {
    try {
      return ZipDecoder().decodeBytes(bytes, verify: false);
    } catch (_) {
      return null;
    }
  }

  List<int>? _fileBytes(Archive archive, String path) {
    for (final file in archive.files) {
      if (file.isFile && file.name == path) {
        // ArchiveFile.content は Uint8List (List<int>) を返す。
        return file.content;
      }
    }
    return null;
  }

  List<String> _readSharedStrings(Archive archive) {
    final bytes = _fileBytes(archive, 'xl/sharedStrings.xml');
    if (bytes == null) return const <String>[];
    final XmlDocument doc;
    try {
      doc = XmlDocument.parse(utf8.decode(bytes, allowMalformed: true));
    } on XmlException {
      return const <String>[];
    }
    final strings = <String>[];
    for (final si in doc.childElements.expand(
      (root) => root.childElements.where((e) => e.localName == 'si'),
    )) {
      // 通常 <si><t>..</t></si>、リッチテキストは複数 <r><t>..</t></r>。
      final text = si.descendants
          .whereType<XmlElement>()
          .where((e) => e.localName == 't')
          .map((e) => e.innerText)
          .join();
      strings.add(text);
    }
    return strings;
  }

  /// 最初のワークシートのバイト列。`sheet1.xml` を優先し、無ければ
  /// `xl/worksheets/sheetN.xml` を番号昇順で先頭を返す。
  List<int>? _firstWorksheetBytes(Archive archive) {
    final preferred = _fileBytes(archive, 'xl/worksheets/sheet1.xml');
    if (preferred != null) return preferred;

    final sheets = <MapEntry<int, ArchiveFile>>[];
    final pattern = RegExp(r'^xl/worksheets/sheet(\d+)\.xml$');
    for (final file in archive.files) {
      if (!file.isFile) continue;
      final match = pattern.firstMatch(file.name);
      if (match != null) {
        sheets.add(MapEntry(int.parse(match.group(1)!), file));
      }
    }
    if (sheets.isEmpty) return null;
    sheets.sort((a, b) => a.key.compareTo(b.key));
    return sheets.first.value.content;
  }

  String _cellValue(XmlElement cell, List<String> sharedStrings) {
    final type = cell.getAttribute('t');
    if (type == 's') {
      final raw = cell.childElements
          .firstWhere(
            (e) => e.localName == 'v',
            orElse: () => XmlElement(XmlName('v')),
          )
          .innerText;
      final idx = int.tryParse(raw.trim());
      if (idx != null && idx >= 0 && idx < sharedStrings.length) {
        return sharedStrings[idx];
      }
      return '';
    }
    if (type == 'inlineStr') {
      return cell.descendants
          .whereType<XmlElement>()
          .where((e) => e.localName == 't')
          .map((e) => e.innerText)
          .join();
    }
    // 数値 / 真偽 / 数式結果 (str) は <v> の中身をそのまま文字列化。
    for (final child in cell.childElements) {
      if (child.localName == 'v') return child.innerText.trim();
    }
    return '';
  }

  /// "B12" のような参照から 0 始まりの列インデックスを返す。解析不可なら -1。
  static int _columnIndexFromRef(String ref) {
    var index = 0;
    var seen = false;
    for (final code in ref.codeUnits) {
      if (code >= 0x41 && code <= 0x5A) {
        index = index * 26 + (code - 0x41 + 1);
        seen = true;
      } else if (code >= 0x61 && code <= 0x7A) {
        index = index * 26 + (code - 0x61 + 1);
        seen = true;
      } else {
        break;
      }
    }
    return seen ? index - 1 : -1;
  }

  Iterable<XmlElement> _byLocalName(XmlDocument doc, String name) =>
      doc.descendants.whereType<XmlElement>().where((e) => e.localName == name);
}
