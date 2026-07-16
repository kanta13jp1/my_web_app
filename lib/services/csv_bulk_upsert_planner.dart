// Generic CSV bulk-registration (UPSERT) planning core — GitHub Issue #1239.
//
// This is the deterministic, table-agnostic heart of "upload a CSV to bulk
// register/update master data": it parses the CSV, validates the header against
// a column schema, coerces each cell to its declared type, decides per row
// whether it is an INSERT (new key) or an UPDATE (key already exists), and
// collects per-row errors with 1-based row numbers plus success / error /
// insert / update counts (Acceptance Criteria #2, #3, #4).
//
// It intentionally has no Flutter, Supabase, or IO dependencies so the logic is
// pure and fully unit-testable. The file-picker UI (AC#1) and the actual
// chunked Supabase upsert are the thin layer built on top of a returned plan.

/// Declared type of a CSV column, used to coerce and validate cell values.
enum CsvColumnType { text, integer, number, boolean, date }

/// Whether a planned row should be inserted or updated.
enum CsvRowOperation { insert, update }

/// Schema for one column of the incoming CSV / target table.
class CsvColumnSpec {
  /// Canonical column name — matched against the header (case-insensitive) and
  /// used as the key in the produced value map (typically the DB field name).
  final String name;

  /// The column must exist in the header, else the whole file is rejected.
  final bool required;

  /// A required cell value — an empty cell on a data row is a row error.
  final bool requiredValue;

  /// Exactly one column in a schema must set this true: the upsert match key.
  final bool isKey;

  final CsvColumnType type;

  const CsvColumnSpec(
    this.name, {
    this.type = CsvColumnType.text,
    this.required = false,
    this.requiredValue = false,
    this.isKey = false,
  });
}

/// A per-row problem the user can act on (AC#4: row number + reason).
class CsvRowError {
  /// 1-based data-row number (the header row is not counted).
  final int rowNumber;
  final String message;
  final String? column;

  const CsvRowError(this.rowNumber, this.message, {this.column});

  Map<String, dynamic> toJson() => <String, dynamic>{
        'rowNumber': rowNumber,
        'message': message,
        if (column != null) 'column': column,
      };

  @override
  String toString() =>
      'row $rowNumber${column != null ? ' [$column]' : ''}: $message';
}

/// A validated row ready to be written, tagged insert vs update.
class CsvPlannedRow {
  final int rowNumber;
  final CsvRowOperation operation;
  final String key;
  final Map<String, dynamic> values;

  const CsvPlannedRow({
    required this.rowNumber,
    required this.operation,
    required this.key,
    required this.values,
  });
}

/// The outcome of planning a CSV bulk upsert.
class CsvBulkUpsertPlan {
  final List<CsvPlannedRow> rows;
  final List<CsvRowError> errors;

  /// Fatal header problems (missing required column). When non-empty, [rows] is
  /// empty and the file should be rejected before any write.
  final List<String> headerErrors;

  /// Non-fatal notices (e.g. unknown extra columns that will be ignored).
  final List<String> headerWarnings;

  const CsvBulkUpsertPlan({
    required this.rows,
    required this.errors,
    this.headerErrors = const <String>[],
    this.headerWarnings = const <String>[],
  });

  int get insertCount =>
      rows.where((r) => r.operation == CsvRowOperation.insert).length;
  int get updateCount =>
      rows.where((r) => r.operation == CsvRowOperation.update).length;

  /// Rows that will be written successfully.
  int get successCount => rows.length;

  /// Rows that were rejected.
  int get errorCount => errors.length;

  bool get hasHeaderErrors => headerErrors.isNotEmpty;

  /// One-line human summary suitable for the completion toast (AC#3).
  String get summaryLabel {
    if (hasHeaderErrors) {
      return 'Import rejected: ${headerErrors.join('; ')}';
    }
    return '成功 $successCount 件 (新規 $insertCount / 更新 $updateCount) / '
        'エラー $errorCount 件';
  }
}

/// Plan a CSV bulk upsert against a schema and the set of keys already present
/// in the target table.
///
/// - [existingKeys] are the current key-column values in the DB; a row whose key
///   is in this set becomes an UPDATE, otherwise an INSERT.
/// - Rows with a bad type, an empty required value, an empty key, a duplicate
///   key within the file, or too many columns are recorded in [CsvBulkUpsertPlan.errors]
///   and excluded from the applied rows.
///
/// Throws [ArgumentError] for a malformed schema (this is a programming error,
/// not user input): the schema must declare exactly one key column and unique
/// column names.
CsvBulkUpsertPlan planCsvBulkUpsert({
  required String csvText,
  required List<CsvColumnSpec> schema,
  Set<String> existingKeys = const <String>{},
  bool skipEmptyRows = true,
}) {
  final keyColumns = schema.where((c) => c.isKey).toList();
  if (keyColumns.length != 1) {
    throw ArgumentError(
      'schema must declare exactly one key column, found ${keyColumns.length}',
    );
  }
  final seenNames = <String>{};
  for (final col in schema) {
    final lower = col.name.trim().toLowerCase();
    if (lower.isEmpty) {
      throw ArgumentError('schema column name must not be empty');
    }
    if (!seenNames.add(lower)) {
      throw ArgumentError('duplicate schema column name: ${col.name}');
    }
  }
  final keyColumn = keyColumns.first;

  final table = parseCsvTable(csvText);
  if (table.isEmpty) {
    return const CsvBulkUpsertPlan(
      rows: <CsvPlannedRow>[],
      errors: <CsvRowError>[],
      headerErrors: <String>['CSV is empty (no header row).'],
    );
  }

  final header = table.first.map((cell) => cell.trim()).toList();
  final headerLower = header.map((cell) => cell.toLowerCase()).toList();

  // Map each schema column to its header index (case-insensitive).
  final columnIndex = <String, int>{};
  final headerErrors = <String>[];
  for (final col in schema) {
    final idx = headerLower.indexOf(col.name.trim().toLowerCase());
    columnIndex[col.name] = idx;
    if (idx < 0 && col.required) {
      headerErrors.add('required column "${col.name}" is missing from header');
    }
  }
  if (headerErrors.isNotEmpty) {
    return CsvBulkUpsertPlan(
      rows: const <CsvPlannedRow>[],
      errors: const <CsvRowError>[],
      headerErrors: headerErrors,
    );
  }

  // Header columns not covered by the schema are ignored, but surfaced.
  final schemaLowerNames = schema.map((c) => c.name.toLowerCase()).toSet();
  final headerWarnings = <String>[];
  for (final name in header) {
    if (name.isEmpty) continue;
    if (!schemaLowerNames.contains(name.toLowerCase())) {
      headerWarnings.add('unknown column "$name" will be ignored');
    }
  }

  final rows = <CsvPlannedRow>[];
  final errors = <CsvRowError>[];
  final seenKeys = <String>{};

  for (var i = 1; i < table.length; i++) {
    final rowNumber = i; // 1-based data row (header excluded)
    final raw = table[i];

    if (skipEmptyRows && raw.every((cell) => cell.trim().isEmpty)) {
      continue;
    }
    if (raw.length > header.length) {
      errors.add(CsvRowError(
        rowNumber,
        'has ${raw.length} columns but header has ${header.length}',
      ));
      continue;
    }

    // Read + coerce the key first.
    final keyIdx = columnIndex[keyColumn.name]!;
    final keyRaw = _cellAt(raw, keyIdx).trim();
    if (keyRaw.isEmpty) {
      errors.add(CsvRowError(
        rowNumber,
        'key column "${keyColumn.name}" is empty',
        column: keyColumn.name,
      ));
      continue;
    }
    if (!seenKeys.add(keyRaw)) {
      errors.add(CsvRowError(
        rowNumber,
        'duplicate key "$keyRaw" within the file',
        column: keyColumn.name,
      ));
      continue;
    }

    // Coerce every schema column.
    final values = <String, dynamic>{};
    CsvRowError? rowError;
    for (final col in schema) {
      final idx = columnIndex[col.name]!;
      final cell = idx < 0 ? '' : _cellAt(raw, idx).trim();
      if (cell.isEmpty) {
        if (col.requiredValue) {
          rowError = CsvRowError(
            rowNumber,
            'required value for "${col.name}" is empty',
            column: col.name,
          );
          break;
        }
        values[col.name] = col.isKey ? keyRaw : null;
        continue;
      }
      final coerced = _coerce(cell, col.type);
      if (!coerced.ok) {
        rowError = CsvRowError(
          rowNumber,
          '${coerced.error} (value "$cell")',
          column: col.name,
        );
        break;
      }
      values[col.name] = coerced.value;
    }
    if (rowError != null) {
      errors.add(rowError);
      continue;
    }

    rows.add(CsvPlannedRow(
      rowNumber: rowNumber,
      operation: existingKeys.contains(keyRaw)
          ? CsvRowOperation.update
          : CsvRowOperation.insert,
      key: keyRaw,
      values: values,
    ));
  }

  return CsvBulkUpsertPlan(
    rows: rows,
    errors: errors,
    headerWarnings: headerWarnings,
  );
}

class _Coerced {
  final bool ok;
  final dynamic value;
  final String? error;
  const _Coerced.success(this.value)
      : ok = true,
        error = null;
  const _Coerced.failure(this.error)
      : ok = false,
        value = null;
}

_Coerced _coerce(String cell, CsvColumnType type) {
  switch (type) {
    case CsvColumnType.text:
      return _Coerced.success(cell);
    case CsvColumnType.integer:
      final n = int.tryParse(cell);
      return n == null
          ? const _Coerced.failure('expected an integer')
          : _Coerced.success(n);
    case CsvColumnType.number:
      final n = num.tryParse(cell);
      return n == null
          ? const _Coerced.failure('expected a number')
          : _Coerced.success(n);
    case CsvColumnType.boolean:
      final lower = cell.toLowerCase();
      const truthy = <String>{'true', '1', 'yes', 'y', 'はい', '真'};
      const falsy = <String>{'false', '0', 'no', 'n', 'いいえ', '偽'};
      if (truthy.contains(lower)) return const _Coerced.success(true);
      if (falsy.contains(lower)) return const _Coerced.success(false);
      return const _Coerced.failure('expected a boolean (true/false)');
    case CsvColumnType.date:
      // Accept ISO date or datetime; normalize to the original trimmed string.
      if (!RegExp(r'^\d{4}-\d{2}-\d{2}([T ].*)?$').hasMatch(cell)) {
        return const _Coerced.failure('expected a YYYY-MM-DD date');
      }
      final parsed = DateTime.tryParse(cell);
      return parsed == null
          ? const _Coerced.failure('is not a valid date')
          : _Coerced.success(cell);
  }
}

String _cellAt(List<String> row, int index) {
  if (index < 0 || index >= row.length) return '';
  return row[index];
}

/// Parse CSV text into a table of string cells. Handles quoted fields, escaped
/// double-quotes (""), CRLF/CR/LF line endings, and a leading UTF-8 BOM.
/// This mirrors the RFC-4180-style reader used elsewhere in the app but is
/// exposed standalone so the planner has no cross-service dependency.
List<List<String>> parseCsvTable(String input) {
  var text = input;
  if (text.isNotEmpty && text.codeUnitAt(0) == 0xFEFF) {
    text = text.substring(1); // strip BOM
  }

  final rows = <List<String>>[];
  final currentRow = <String>[];
  final currentCell = StringBuffer();
  var inQuotes = false;

  for (var i = 0; i < text.length; i++) {
    final char = text[i];
    final next = i + 1 < text.length ? text[i + 1] : null;

    if (char == '"') {
      if (inQuotes && next == '"') {
        currentCell.write('"');
        i++;
      } else {
        inQuotes = !inQuotes;
      }
      continue;
    }

    if (char == ',' && !inQuotes) {
      currentRow.add(currentCell.toString());
      currentCell.clear();
      continue;
    }

    if ((char == '\n' || char == '\r') && !inQuotes) {
      if (char == '\r' && next == '\n') {
        i++;
      }
      currentRow.add(currentCell.toString());
      rows.add(List<String>.from(currentRow));
      currentRow.clear();
      currentCell.clear();
      continue;
    }

    currentCell.write(char);
  }

  if (currentCell.isNotEmpty || currentRow.isNotEmpty) {
    currentRow.add(currentCell.toString());
    rows.add(List<String>.from(currentRow));
  }

  return rows;
}
