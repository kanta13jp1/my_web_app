class CellAddress {
  const CellAddress({required this.row, required this.column})
      : assert(row >= 0),
        assert(column >= 0);

  final int row;
  final int column;

  String get key => '$row:$column';

  String get label => '${columnLabel(column)}${row + 1}';

  static CellAddress? tryParse(String value) {
    final match = RegExp(
      r'^([A-Za-z]+)([1-9][0-9]*)$',
    ).firstMatch(value.trim());
    if (match == null) return null;

    var column = 0;
    for (final unit in match.group(1)!.toUpperCase().codeUnits) {
      column = (column * 26) + unit - 64;
    }
    return CellAddress(row: int.parse(match.group(2)!) - 1, column: column - 1);
  }

  static String columnLabel(int column) {
    var value = column + 1;
    final buffer = StringBuffer();
    while (value > 0) {
      final remainder = (value - 1) % 26;
      buffer.writeCharCode(65 + remainder);
      value = (value - 1) ~/ 26;
    }
    return buffer.toString().split('').reversed.join();
  }

  @override
  bool operator ==(Object other) {
    return other is CellAddress && row == other.row && column == other.column;
  }

  @override
  int get hashCode => Object.hash(row, column);
}

class SpreadsheetSheet {
  const SpreadsheetSheet({
    required this.id,
    required this.name,
    required this.rowCount,
    required this.columnCount,
    required this.cells,
  });

  factory SpreadsheetSheet.blank({
    required String id,
    required String name,
  }) {
    return SpreadsheetSheet(
      id: id,
      name: name,
      rowCount: 30,
      columnCount: 12,
      cells: const <String, String>{},
    );
  }

  factory SpreadsheetSheet.fromJson(
    Map<String, Object?> json, {
    required String fallbackId,
    required String fallbackName,
  }) {
    return SpreadsheetSheet(
      id: json['id']?.toString() ?? fallbackId,
      name: json['name']?.toString() ?? fallbackName,
      rowCount: _positiveInt(json['rowCount'], fallback: 30),
      columnCount: _positiveInt(json['columnCount'], fallback: 12),
      cells: _readCells(json['cells']),
    );
  }

  final String id;
  final String name;
  final int rowCount;
  final int columnCount;
  final Map<String, String> cells;

  String inputAt(CellAddress address) => cells[address.key] ?? '';

  SpreadsheetSheet copyWith({
    String? name,
    int? rowCount,
    int? columnCount,
    Map<String, String>? cells,
  }) {
    return SpreadsheetSheet(
      id: id,
      name: name ?? this.name,
      rowCount: rowCount ?? this.rowCount,
      columnCount: columnCount ?? this.columnCount,
      cells: Map<String, String>.unmodifiable(cells ?? this.cells),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'name': name,
      'rowCount': rowCount,
      'columnCount': columnCount,
      'cells': cells,
    };
  }

  static Map<String, String> _readCells(Object? rawCells) {
    final cells = <String, String>{};
    if (rawCells is Map) {
      for (final entry in rawCells.entries) {
        cells[entry.key.toString()] = entry.value?.toString() ?? '';
      }
    }
    return Map<String, String>.unmodifiable(cells);
  }

  static int _positiveInt(Object? value, {required int fallback}) {
    final parsed = value is int ? value : int.tryParse(value?.toString() ?? '');
    return parsed != null && parsed > 0 ? parsed : fallback;
  }
}

class SpreadsheetDocument {
  const SpreadsheetDocument({
    required this.id,
    required this.title,
    required this.sheets,
    required this.activeSheetId,
    required this.updatedAt,
  });

  factory SpreadsheetDocument.blank({
    String id = 'local-workbook',
    DateTime? now,
  }) {
    return SpreadsheetDocument(
      id: id,
      title: '無題のブック',
      sheets: <SpreadsheetSheet>[
        SpreadsheetSheet.blank(id: 'sheet-1', name: 'シート1'),
      ],
      activeSheetId: 'sheet-1',
      updatedAt: now ?? DateTime.now(),
    );
  }

  factory SpreadsheetDocument.fromJson(Map<String, Object?> json) {
    final sheets = <SpreadsheetSheet>[];
    final rawSheets = json['sheets'];
    if (rawSheets is List) {
      for (var index = 0; index < rawSheets.length; index++) {
        final rawSheet = rawSheets[index];
        if (rawSheet is! Map) continue;
        sheets.add(
          SpreadsheetSheet.fromJson(
            Map<String, Object?>.from(rawSheet),
            fallbackId: 'sheet-${index + 1}',
            fallbackName: 'シート${index + 1}',
          ),
        );
      }
    }
    if (sheets.isEmpty) {
      sheets.add(
        SpreadsheetSheet.fromJson(
          json,
          fallbackId: 'sheet-1',
          fallbackName: 'シート1',
        ),
      );
    }
    final requestedActiveId = json['activeSheetId']?.toString();
    final activeSheetId = sheets.any((sheet) => sheet.id == requestedActiveId)
        ? requestedActiveId!
        : sheets.first.id;
    return SpreadsheetDocument(
      id: json['id']?.toString() ?? 'local-workbook',
      title: json['title']?.toString() ?? '無題のブック',
      sheets: List<SpreadsheetSheet>.unmodifiable(sheets),
      activeSheetId: activeSheetId,
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  final String id;
  final String title;
  final List<SpreadsheetSheet> sheets;
  final String activeSheetId;
  final DateTime updatedAt;

  SpreadsheetSheet get activeSheet {
    return sheets.firstWhere(
      (sheet) => sheet.id == activeSheetId,
      orElse: () => sheets.first,
    );
  }

  int get rowCount => activeSheet.rowCount;
  int get columnCount => activeSheet.columnCount;
  Map<String, String> get cells => activeSheet.cells;

  String inputAt(CellAddress address) => activeSheet.inputAt(address);

  SpreadsheetDocument replaceSheet(
    SpreadsheetSheet replacement, {
    DateTime? updatedAt,
  }) {
    return copyWith(
      sheets: <SpreadsheetSheet>[
        for (final sheet in sheets)
          if (sheet.id == replacement.id) replacement else sheet,
      ],
      updatedAt: updatedAt,
    );
  }

  SpreadsheetDocument copyWith({
    String? title,
    List<SpreadsheetSheet>? sheets,
    String? activeSheetId,
    DateTime? updatedAt,
  }) {
    return SpreadsheetDocument(
      id: id,
      title: title ?? this.title,
      sheets: List<SpreadsheetSheet>.unmodifiable(sheets ?? this.sheets),
      activeSheetId: activeSheetId ?? this.activeSheetId,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'version': 2,
      'title': title,
      'sheets': sheets.map((sheet) => sheet.toJson()).toList(growable: false),
      'activeSheetId': activeSheetId,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
