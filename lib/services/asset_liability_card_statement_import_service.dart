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
    _CardStatementColumnMap? columnMap;

    for (var i = 0; i < rows.length; i++) {
      final rawRow = rows[i].trim();
      if (rawRow.isEmpty) {
        continue;
      }
      final cells = _splitRow(rawRow).map((cell) => cell.trim()).toList();
      if (cells.isEmpty) {
        continue;
      }
      if (!hasHeader && _looksLikeHeader(cells)) {
        hasHeader = true;
        // 各社 CSV/TSV のヘッダ列名から「日付・摘要・金額」の位置を学習し、
        // 以降の行をその位置で読む (auPAY 等の列順差異を吸収)。
        columnMap = _buildColumnMap(cells);
        continue;
      }

      final parsed = _parseRow(
        cells: cells,
        columnMap: columnMap,
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
    required _CardStatementColumnMap? columnMap,
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

    String? cellAt(int? index) =>
        (index != null && index >= 0 && index < cells.length)
            ? cells[index]
            : null;

    if (columnMap != null) {
      // ヘッダ学習済み: 列名から得た位置で読む (auPAY 等の列順に対応)。
      description = cellAt(columnMap.description);
      amountText = cellAt(columnMap.amount);
      dateText = cellAt(columnMap.date);
      final billingFromColumn = cellAt(columnMap.billing);
      if (billingFromColumn != null && billingFromColumn.trim().isNotEmpty) {
        billingAccountId = billingFromColumn;
      }
    } else if (cells.length >= 4) {
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
    description = (description ?? '').trim();
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
        normalized.contains('posted_at') ||
        // 日本語ヘッダ (auPAY / 各社カード明細 CSV/TSV)。データ行には現れない
        // 列見出しの語で判定する。
        normalized.contains('利用金額') ||
        normalized.contains('利用日') ||
        normalized.contains('利用店名') ||
        normalized.contains('ご利用者') ||
        normalized.contains('ご利用日') ||
        normalized.contains('請求額') ||
        normalized.contains('支払区分');
  }

  /// ヘッダ行から「日付・摘要・金額・請求先ID」の列位置を学習する。
  /// 金額と摘要が特定できなければ null を返し、位置ベースの推定へ委ねる。
  _CardStatementColumnMap? _buildColumnMap(List<String> headerCells) {
    int? dateIndex;
    int? descriptionIndex;
    int? amountIndex;
    int? billingIndex;
    for (var i = 0; i < headerCells.length; i++) {
      final header = headerCells[i].toLowerCase().trim();
      if (amountIndex == null &&
          (header.contains('利用金額') ||
              header.contains('請求額') ||
              header == '金額' ||
              header.contains('amount'))) {
        amountIndex = i;
      } else if (dateIndex == null &&
          (header.contains('利用日') ||
              header.contains('ご利用日') ||
              header.contains('日付') ||
              header.contains('date') ||
              header.contains('posted_at'))) {
        dateIndex = i;
      } else if (descriptionIndex == null &&
          (header.contains('利用店名') ||
              header.contains('店名') ||
              header.contains('利用内容') ||
              header.contains('ご利用先') ||
              header.contains('description'))) {
        descriptionIndex = i;
      } else if (billingIndex == null &&
          (header.contains('請求先id') || header.contains('billing_account'))) {
        billingIndex = i;
      }
    }
    // 店名列が無い明細は摘要列を摘要(=説明)として使う。
    if (descriptionIndex == null) {
      for (var i = 0; i < headerCells.length; i++) {
        if (headerCells[i].toLowerCase().contains('摘要')) {
          descriptionIndex = i;
          break;
        }
      }
    }
    if (amountIndex == null || descriptionIndex == null) {
      return null;
    }
    return _CardStatementColumnMap(
      date: dateIndex,
      description: descriptionIndex,
      amount: amountIndex,
      billing: billingIndex,
    );
  }

  /// タブ区切り (表計算/明細サイトからの貼り付け) はタブで、それ以外は
  /// カンマで分割する。
  List<String> _splitRow(String row) {
    if (row.contains('\t')) {
      return row.split('\t');
    }
    return _splitCsvRow(row);
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
    final normalized = _normalizeFullWidthDigits(raw)
        .replaceAll(',', '')
        .replaceAll('\uff0c', '') // \u5168\u89d2\u30ab\u30f3\u30de
        .replaceAll('\u5186', '')
        .replaceAll('\u00a5', '')
        .trim();
    if (normalized.isEmpty) {
      return null;
    }
    return double.tryParse(normalized);
  }

  /// \u5168\u89d2\u6570\u5b57 (\uff10-\uff19) \u3092\u534a\u89d2\u3078\u5909\u63db\u3059\u308b\u3002\u660e\u7d30\u30b5\u30a4\u30c8\u306e\u30b3\u30d4\u30fc\u306f\u5168\u89d2\u6df7\u3058\u308a\u304c\u591a\u3044\u3002
  String _normalizeFullWidthDigits(String input) {
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      if (rune >= 0xFF10 && rune <= 0xFF19) {
        buffer.writeCharCode(rune - 0xFF10 + 0x30);
      } else {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString();
  }

  DateTime? _parseDate(String? raw) {
    final text = raw == null ? null : _normalizeFullWidthDigits(raw).trim();
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

/// ヘッダから学習したカード明細の列位置 (0始まり)。date/billing は任意。
class _CardStatementColumnMap {
  final int? date;
  final int description;
  final int amount;
  final int? billing;

  const _CardStatementColumnMap({
    required this.date,
    required this.description,
    required this.amount,
    required this.billing,
  });
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
