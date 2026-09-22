import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint, debugPrintStack;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'import_service.dart';

enum BusinessCsvCommitMode { allOrRollback, validRowsOnly }

class BusinessCsvImportRow {
  final int rowNumber;
  final String rawText;
  final String title;
  final String content;
  final List<String> tags;
  final String externalId;

  const BusinessCsvImportRow({
    required this.rowNumber,
    required this.rawText,
    required this.title,
    required this.content,
    this.tags = const <String>[],
    this.externalId = '',
  });

  factory BusinessCsvImportRow.fromJson(Map<String, dynamic> json) {
    return BusinessCsvImportRow(
      rowNumber: _toInt(json['rowNumber'] ?? json['row_number']),
      rawText:
          json['rawText']?.toString() ?? json['raw_text']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      tags: _stringList(json['tags']),
      externalId: json['externalId']?.toString() ??
          json['external_id']?.toString() ??
          '',
    );
  }

  ImportedNoteDraft toNoteDraft() {
    return ImportedNoteDraft(
      title: title.trim(),
      content: content.trim(),
      source: 'business_csv',
      tags: tags,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'rowNumber': rowNumber,
      'rawText': rawText,
      'title': title,
      'content': content,
      'tags': tags,
      'externalId': externalId,
    };
  }
}

class BusinessCsvErrorRow {
  final int rowNumber;
  final String rawText;
  final String title;
  final List<String> reasons;

  const BusinessCsvErrorRow({
    required this.rowNumber,
    required this.rawText,
    required this.title,
    required this.reasons,
  });

  factory BusinessCsvErrorRow.fromJson(Map<String, dynamic> json) {
    return BusinessCsvErrorRow(
      rowNumber: _toInt(json['rowNumber'] ?? json['row_number']),
      rawText:
          json['rawText']?.toString() ?? json['raw_text']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      reasons: _stringList(json['reasons'] ?? json['errors']),
    );
  }

  String get reasonText => reasons.join('; ');

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'rowNumber': rowNumber,
      'rawText': rawText,
      'title': title,
      'reasons': reasons,
    };
  }
}

class BusinessCsvDryRunResult {
  final String fileName;
  final int totalRows;
  final List<BusinessCsvImportRow> rows;
  final List<BusinessCsvImportRow> validRows;
  final List<BusinessCsvErrorRow> errorRows;
  final List<String> warnings;
  final String checkedBy;

  const BusinessCsvDryRunResult({
    required this.fileName,
    required this.totalRows,
    this.rows = const <BusinessCsvImportRow>[],
    required this.validRows,
    required this.errorRows,
    this.warnings = const <String>[],
    this.checkedBy = 'local',
  });

  factory BusinessCsvDryRunResult.fromJson(Map<String, dynamic> json) {
    return BusinessCsvDryRunResult(
      fileName:
          json['fileName']?.toString() ?? json['file_name']?.toString() ?? '',
      totalRows: _toInt(json['totalRows'] ?? json['total_rows']),
      rows: _rowList(json['rows'] ?? json['allRows'] ?? json['all_rows']),
      validRows: _rowList(json['validRows'] ?? json['valid_rows']),
      errorRows: _errorList(json['errorRows'] ?? json['error_rows']),
      warnings: _stringList(json['warnings']),
      checkedBy: json['checkedBy']?.toString() ??
          json['checked_by']?.toString() ??
          'postgres-rpc',
    );
  }

  BusinessCsvDryRunResult copyWith({
    List<BusinessCsvImportRow>? rows,
    List<String>? warnings,
    String? checkedBy,
  }) {
    return BusinessCsvDryRunResult(
      fileName: fileName,
      totalRows: totalRows,
      rows: rows ?? this.rows,
      validRows: validRows,
      errorRows: errorRows,
      warnings: warnings ?? this.warnings,
      checkedBy: checkedBy ?? this.checkedBy,
    );
  }

  int get validCount => validRows.length;

  int get errorCount => errorRows.length;

  bool get hasErrors => errorRows.isNotEmpty;

  bool get usedServerDryRun => checkedBy == 'postgres-rpc';

  List<ImportedNoteDraft> get validNotes =>
      validRows.map((row) => row.toNoteDraft()).toList(growable: false);

  String get errorCsv {
    final lines = <String>[
      'row_number,title,error_reason,raw_text',
      ...errorRows.map(
        (row) => <String>[
          row.rowNumber.toString(),
          row.title,
          row.reasonText,
          row.rawText,
        ].map(_escapeCsv).join(','),
      ),
    ];
    return lines.join('\n');
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'fileName': fileName,
      'totalRows': totalRows,
      'rows': rows.map((row) => row.toJson()).toList(),
      'validRows': validRows.map((row) => row.toJson()).toList(),
      'errorRows': errorRows.map((row) => row.toJson()).toList(),
      'warnings': warnings,
      'checkedBy': checkedBy,
    };
  }
}

class BusinessCsvCommitResult {
  final int insertedCount;
  final bool rolledBack;
  final BusinessCsvCommitMode commitMode;
  final BusinessCsvDryRunResult dryRun;

  const BusinessCsvCommitResult({
    required this.insertedCount,
    required this.rolledBack,
    required this.commitMode,
    required this.dryRun,
  });

  factory BusinessCsvCommitResult.fromJson(Map<String, dynamic> json) {
    final modeText = json['commitMode']?.toString() ??
        json['commit_mode']?.toString() ??
        'valid_rows_only';
    return BusinessCsvCommitResult(
      insertedCount: _toInt(json['insertedCount'] ?? json['inserted_count']),
      rolledBack: json['rolledBack'] == true || json['rolled_back'] == true,
      commitMode: modeText == 'all_or_rollback'
          ? BusinessCsvCommitMode.allOrRollback
          : BusinessCsvCommitMode.validRowsOnly,
      dryRun: BusinessCsvDryRunResult.fromJson(
        _asMap(json['dryRun'] ?? json['dry_run']),
      ),
    );
  }
}

class BusinessCsvImportService {
  final SupabaseClient? _clientOverride;

  const BusinessCsvImportService({SupabaseClient? clientOverride})
      : _clientOverride = clientOverride;

  SupabaseClient? get _client {
    if (_clientOverride != null) {
      return _clientOverride;
    }
    try {
      return Supabase.instance.client;
    } on AssertionError {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<BusinessCsvDryRunResult> previewCsvBytes({
    required String fileName,
    required Uint8List bytes,
    bool preferServerDryRun = true,
  }) async {
    final rows = parseCsvBytes(bytes);
    if (preferServerDryRun) {
      final client = _client;
      if (client != null) {
        try {
          final dynamic response = await client.rpc(
            'preview_business_note_csv_import',
            params: <String, dynamic>{
              'p_rows': rows.map((row) => row.toJson()).toList(),
              'p_file_name': fileName,
            },
          );
          if (response is Map) {
            return BusinessCsvDryRunResult.fromJson(
              Map<String, dynamic>.from(response),
            ).copyWith(rows: rows);
          }
        } catch (error, stackTrace) {
          debugPrint('Business CSV server dry-run failed: $error');
          debugPrintStack(stackTrace: stackTrace);
        }
      }
    }
    return dryRunRows(
      fileName: fileName,
      rows: rows,
      warnings: preferServerDryRun
          ? const <String>[
              'Server dry-run was unavailable, so local validation was used.',
            ]
          : const <String>[],
    );
  }

  Future<BusinessCsvCommitResult> commitRows({
    required String fileName,
    required List<BusinessCsvImportRow> rows,
    required BusinessCsvCommitMode mode,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase client is not available for CSV commit.');
    }
    final dynamic response = await client.rpc(
      'commit_business_note_csv_import',
      params: <String, dynamic>{
        'p_rows': rows.map((row) => row.toJson()).toList(),
        'p_file_name': fileName,
        'p_rollback_on_error': mode == BusinessCsvCommitMode.allOrRollback,
      },
    );
    if (response is Map) {
      return BusinessCsvCommitResult.fromJson(
        Map<String, dynamic>.from(response),
      );
    }
    throw Exception('Unexpected CSV commit response.');
  }

  List<BusinessCsvImportRow> parseCsvBytes(Uint8List bytes) {
    return parseCsvText(utf8.decode(bytes, allowMalformed: true));
  }

  List<BusinessCsvImportRow> parseCsvText(String csvText) {
    final rows = _parseCsv(csvText);
    if (rows.length <= 1) {
      return const <BusinessCsvImportRow>[];
    }
    final headers =
        rows.first.map((cell) => cell.trim().toLowerCase()).toList();
    final titleIndex = _findColumnIndex(headers, const <String>[
      'title',
      'name',
      'subject',
    ]);
    final contentIndex = _findColumnIndex(headers, const <String>[
      'content',
      'body',
      'text',
      'description',
    ]);
    final tagsIndex = _findColumnIndex(headers, const <String>[
      'tags',
      'tag',
      'labels',
    ]);
    final externalIdIndex = _findColumnIndex(headers, const <String>[
      'external_id',
      'external id',
      'source_id',
      'id',
    ]);

    final parsed = <BusinessCsvImportRow>[];
    for (var index = 1; index < rows.length; index++) {
      final row = rows[index];
      if (row.every((cell) => cell.trim().isEmpty)) {
        continue;
      }
      final tags = _readCell(row, tagsIndex)
          .split(RegExp(r'[,;]'))
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();
      parsed.add(
        BusinessCsvImportRow(
          rowNumber: index + 1,
          rawText: row.map(_escapeCsv).join(','),
          title: _readCell(row, titleIndex).trim(),
          content: _readCell(row, contentIndex).trim(),
          tags: tags,
          externalId: _readCell(row, externalIdIndex).trim(),
        ),
      );
    }
    return parsed;
  }

  BusinessCsvDryRunResult dryRunRows({
    required String fileName,
    required List<BusinessCsvImportRow> rows,
    List<String> warnings = const <String>[],
  }) {
    final valid = <BusinessCsvImportRow>[];
    final errors = <BusinessCsvErrorRow>[];
    final seenExternalIds = <String>{};
    final seenTitles = <String>{};

    for (final row in rows) {
      final reasons = <String>[];
      final title = row.title.trim();
      final content = row.content.trim();
      final externalId = row.externalId.trim().toLowerCase();
      final titleKey = title.toLowerCase();

      if (title.isEmpty) {
        reasons.add('required title missing');
      }
      if (content.isEmpty) {
        reasons.add('required content missing');
      }
      if (title.length > 160) {
        reasons.add('title exceeds 160 characters');
      }
      if (content.length > 20000) {
        reasons.add('content exceeds 20000 characters');
      }
      if (externalId.isNotEmpty && !seenExternalIds.add(externalId)) {
        reasons.add('duplicate external_id within file');
      }
      if (titleKey.isNotEmpty && !seenTitles.add(titleKey)) {
        reasons.add('duplicate title within file');
      }

      if (reasons.isEmpty) {
        valid.add(row);
      } else {
        errors.add(
          BusinessCsvErrorRow(
            rowNumber: row.rowNumber,
            rawText: row.rawText,
            title: row.title,
            reasons: reasons,
          ),
        );
      }
    }

    return BusinessCsvDryRunResult(
      fileName: fileName,
      totalRows: rows.length,
      rows: rows,
      validRows: valid,
      errorRows: errors,
      warnings: warnings,
      checkedBy: 'local',
    );
  }

  int _findColumnIndex(List<String> header, List<String> candidates) {
    for (final candidate in candidates) {
      final index = header.indexOf(candidate);
      if (index != -1) {
        return index;
      }
    }
    return -1;
  }

  String _readCell(List<String> row, int index) {
    if (index < 0 || index >= row.length) {
      return '';
    }
    return row[index];
  }

  List<List<String>> _parseCsv(String input) {
    final rows = <List<String>>[];
    final currentRow = <String>[];
    final currentCell = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < input.length; i++) {
      final char = input[i];
      final next = i + 1 < input.length ? input[i + 1] : null;
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
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return <String, dynamic>{};
}

List<String> _stringList(dynamic raw) {
  if (raw is List) {
    return raw
        .map((value) => value.toString())
        .where((value) => value.trim().isNotEmpty)
        .toList();
  }
  return const <String>[];
}

List<BusinessCsvImportRow> _rowList(dynamic raw) {
  if (raw is! List) {
    return const <BusinessCsvImportRow>[];
  }
  return raw
      .whereType<Map>()
      .map(
        (row) => BusinessCsvImportRow.fromJson(Map<String, dynamic>.from(row)),
      )
      .toList();
}

List<BusinessCsvErrorRow> _errorList(dynamic raw) {
  if (raw is! List) {
    return const <BusinessCsvErrorRow>[];
  }
  return raw
      .whereType<Map>()
      .map(
        (row) => BusinessCsvErrorRow.fromJson(Map<String, dynamic>.from(row)),
      )
      .toList();
}

int _toInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? 0;
  }
  return 0;
}

String _escapeCsv(String value) {
  final safeValue = _neutralizeSpreadsheetFormula(value);
  if (!safeValue.contains(',') &&
      !safeValue.contains('"') &&
      !safeValue.contains('\n') &&
      !safeValue.contains('\r')) {
    return safeValue;
  }
  return '"${safeValue.replaceAll('"', '""')}"';
}

String _neutralizeSpreadsheetFormula(String value) {
  final trimmedLeft = value.trimLeft();
  if (trimmedLeft.isEmpty) {
    return value;
  }
  if ('=+-@'.contains(trimmedLeft[0]) ||
      value.startsWith('\t') ||
      value.startsWith('\r')) {
    return "'$value";
  }
  return value;
}
