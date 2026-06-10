import 'package:intl/intl.dart';

import '../models/asset_liability_workbook.dart';

class AssetLiabilityCardStatementImportService {
  const AssetLiabilityCardStatementImportService();

  AssetLiabilityCardStatementImportResult parse({
    required String rawText,
    String? defaultBillingAccountId,
    String? defaultBillingAccountName,
  }) {
    final accepted = <AssetLiabilityCardStatementLine>[];
    final rejected = <AssetLiabilityCardStatementRejectedRow>[];
    final rows = rawText.split(RegExp(r'\r?\n'));
    var hasHeader = false;

    for (var i = 0; i < rows.length; i++) {
      final rawRow = rows[i].trim();
      if (rawRow.isEmpty) {
        continue;
      }
      final cells = _splitCsvRow(rawRow).map((cell) => cell.trim()).toList();
      if (cells.isEmpty) {
        continue;
      }
      if (!hasHeader && _looksLikeHeader(cells)) {
        hasHeader = true;
        continue;
      }

      final parsed = _parseRow(
        cells: cells,
        rowNumber: i + 1,
        rawRow: rawRow,
        defaultBillingAccountId: defaultBillingAccountId,
        defaultBillingAccountName: defaultBillingAccountName,
      );
      if (parsed.line != null) {
        accepted.add(parsed.line!);
      } else {
        rejected.add(parsed.rejected);
      }
    }

    return AssetLiabilityCardStatementImportResult(
      lines: accepted,
      rejectedRows: rejected,
    );
  }

  _ParsedCardStatementRow _parseRow({
    required List<String> cells,
    required int rowNumber,
    required String rawRow,
    required String? defaultBillingAccountId,
    required String? defaultBillingAccountName,
  }) {
    String? billingAccountId = defaultBillingAccountId?.trim();
    String? billingAccountName = defaultBillingAccountName?.trim();
    String? description;
    String? amountText;
    String? dateText;

    if (cells.length >= 4) {
      billingAccountId = cells[0];
      description = cells[1];
      amountText = cells[2];
      dateText = cells[3];
    } else if (cells.length == 3) {
      if (defaultBillingAccountId == null ||
          defaultBillingAccountId.trim().isEmpty) {
        billingAccountId = cells[0];
        description = cells[1];
        amountText = cells[2];
      } else {
        description = cells[0];
        amountText = cells[1];
        dateText = cells[2];
      }
    } else if (cells.length == 2) {
      description = cells[0];
      amountText = cells[1];
    } else {
      return _ParsedCardStatementRow.rejected(
        rowNumber: rowNumber,
        rawText: rawRow,
        reason: '摘要と金額が必要です',
      );
    }

    billingAccountId = billingAccountId?.trim();
    billingAccountName = billingAccountName?.trim();
    description = description.trim();
    final amount = _parseAmount(amountText);
    final postedAt = _parseDate(dateText);

    if (billingAccountId == null || billingAccountId.isEmpty) {
      return _ParsedCardStatementRow.rejected(
        rowNumber: rowNumber,
        rawText: rawRow,
        reason: '請求先IDが必要です',
      );
    }
    if (description.isEmpty) {
      return _ParsedCardStatementRow.rejected(
        rowNumber: rowNumber,
        rawText: rawRow,
        reason: '摘要が必要です',
      );
    }
    if (amount == null) {
      return _ParsedCardStatementRow.rejected(
        rowNumber: rowNumber,
        rawText: rawRow,
        reason: '金額が不正です',
      );
    }

    return _ParsedCardStatementRow.accepted(
      AssetLiabilityCardStatementLine(
        id: _stableLineId(
          billingAccountId: billingAccountId,
          description: description,
          amount: amount,
          postedAt: postedAt,
          rowNumber: rowNumber,
        ),
        billingAccountId: billingAccountId,
        billingAccountName:
            billingAccountName?.isEmpty ?? true ? null : billingAccountName,
        postedAt: postedAt,
        description: description,
        amount: amount,
      ),
    );
  }

  bool _looksLikeHeader(List<String> cells) {
    final normalized = cells.map((cell) => cell.toLowerCase()).join(',');
    return normalized.contains('amount') ||
        normalized.contains('billing_account') ||
        normalized.contains('description') ||
        normalized.contains('posted_at');
  }

  List<String> _splitCsvRow(String row) {
    final cells = <String>[];
    final current = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < row.length; i++) {
      final char = row[i];
      if (char == '"') {
        if (inQuotes && i + 1 < row.length && row[i + 1] == '"') {
          current.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        cells.add(current.toString());
        current.clear();
      } else {
        current.write(char);
      }
    }
    cells.add(current.toString());
    return cells;
  }

  double? _parseAmount(String? raw) {
    if (raw == null) {
      return null;
    }
    final normalized = raw
        .replaceAll(',', '')
        .replaceAll('\u5186', '')
        .replaceAll('\u00a5', '')
        .trim();
    if (normalized.isEmpty) {
      return null;
    }
    return double.tryParse(normalized);
  }

  DateTime? _parseDate(String? raw) {
    final text = raw?.trim();
    if (text == null || text.isEmpty) {
      return null;
    }
    final iso = DateTime.tryParse(text);
    if (iso != null) {
      return iso;
    }
    for (final format in <DateFormat>[
      DateFormat('yyyy/M/d'),
      DateFormat('M/d/yyyy'),
      DateFormat('M/d'),
    ]) {
      try {
        final parsed = format.parseStrict(text);
        return parsed.year == 1970
            ? DateTime(DateTime.now().year, parsed.month, parsed.day)
            : parsed;
      } catch (_) {
        // Try the next common export format.
      }
    }
    return null;
  }

  String _stableLineId({
    required String billingAccountId,
    required String description,
    required double amount,
    required DateTime? postedAt,
    required int rowNumber,
  }) {
    final dateKey =
        postedAt == null ? 'nodate' : DateFormat('yyyyMMdd').format(postedAt);
    final slug = '$billingAccountId-$dateKey-$description-$amount-$rowNumber'
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return slug.isEmpty ? 'card_statement_$rowNumber' : slug;
  }
}

class _ParsedCardStatementRow {
  final AssetLiabilityCardStatementLine? line;
  final AssetLiabilityCardStatementRejectedRow rejected;

  const _ParsedCardStatementRow._({required this.line, required this.rejected});

  factory _ParsedCardStatementRow.accepted(
    AssetLiabilityCardStatementLine line,
  ) {
    return _ParsedCardStatementRow._(
      line: line,
      rejected: const AssetLiabilityCardStatementRejectedRow(
        rowNumber: 0,
        rawText: '',
        reason: '',
      ),
    );
  }

  factory _ParsedCardStatementRow.rejected({
    required int rowNumber,
    required String rawText,
    required String reason,
  }) {
    return _ParsedCardStatementRow._(
      line: null,
      rejected: AssetLiabilityCardStatementRejectedRow(
        rowNumber: rowNumber,
        rawText: rawText,
        reason: reason,
      ),
    );
  }
}
