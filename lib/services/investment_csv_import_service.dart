import '../models/investment_asset.dart';

enum InvestmentCsvBroker {
  rakuten('楽天証券'),
  sbi('SBI証券');

  const InvestmentCsvBroker(this.label);

  final String label;
}

enum InvestmentCsvDuplicatePolicy { skip, update }

class InvestmentCsvIssue {
  const InvestmentCsvIssue({required this.lineNumber, required this.message});

  final int lineNumber;
  final String message;
}

class InvestmentCsvRow {
  const InvestmentCsvRow({
    required this.lineNumber,
    required this.draft,
    this.mergedRowCount = 1,
  });

  final int lineNumber;
  final InvestmentAssetDraft draft;
  final int mergedRowCount;
}

class InvestmentCsvParseResult {
  const InvestmentCsvParseResult({
    required this.broker,
    required this.rows,
    required this.issues,
    required this.inputRowCount,
  });

  final InvestmentCsvBroker broker;
  final List<InvestmentCsvRow> rows;
  final List<InvestmentCsvIssue> issues;
  final int inputRowCount;
}

class InvestmentCsvUpdate {
  const InvestmentCsvUpdate({required this.asset, required this.draft});

  final InvestmentAsset asset;
  final InvestmentAssetDraft draft;
}

class InvestmentCsvImportPlan {
  const InvestmentCsvImportPlan({
    required this.creates,
    required this.updates,
    required this.skippedDuplicates,
    required this.invalidRows,
  });

  final List<InvestmentAssetDraft> creates;
  final List<InvestmentCsvUpdate> updates;
  final int skippedDuplicates;
  final int invalidRows;

  int get writeCount => creates.length + updates.length;
}

/// Parses holdings snapshots exported by Rakuten Securities and SBI
/// Securities, then creates a deterministic import plan keyed by ticker.
class InvestmentCsvImportService {
  const InvestmentCsvImportService();

  static const _tickerHeaders = <String>[
    '銘柄コード',
    'コード',
    'ティッカー',
    'ticker',
    'symbol',
    '銘柄',
  ];
  static const _quantityHeaders = <String>['保有数量', '数量', '保有数', '株数', '口数'];
  static const _buyPriceHeaders = <String>[
    '平均取得価額',
    '平均取得単価',
    '取得単価',
    '取得価額',
    '買付単価',
  ];
  static const _currentPriceHeaders = <String>[
    '現在値',
    '現在価格',
    '時価単価',
    '評価単価',
    '株価',
  ];
  static const _typeHeaders = <String>[
    '商品種別',
    '商品種類',
    '資産タイプ',
    '商品分類',
    '種別',
    '市場',
  ];
  static const _dateHeaders = <String>['取得日', '買付日', '約定日'];

  static bool looksLikeCsv(String text) {
    try {
      final rows = _nonEmptyRows(text);
      if (rows.isEmpty) return false;
      final header = rows.first.map(_normalizeHeader).toList();
      _detectBroker(header);
      _requiredIndex(header, _tickerHeaders, '銘柄コード');
      _requiredIndex(header, _quantityHeaders, '保有数量/数量');
      _requiredIndex(header, _buyPriceHeaders, '平均取得価額/取得単価');
      return true;
    } on FormatException {
      return false;
    }
  }

  InvestmentCsvParseResult parse(String csvText) {
    final rows = _nonEmptyRows(csvText);
    if (rows.isEmpty) {
      throw const FormatException('CSVに明細行がありません');
    }

    final header = rows.first.map(_normalizeHeader).toList();
    final broker = _detectBroker(header);
    final tickerIndex = _requiredIndex(header, _tickerHeaders, '銘柄コード');
    final quantityIndex = _requiredIndex(header, _quantityHeaders, '保有数量/数量');
    final buyPriceIndex = _requiredIndex(
      header,
      _buyPriceHeaders,
      '平均取得価額/取得単価',
    );
    final currentPriceIndex = _optionalIndex(header, _currentPriceHeaders);
    final typeIndex = _optionalIndex(header, _typeHeaders);
    final dateIndex = _optionalIndex(header, _dateHeaders);

    final parsedByTicker = <String, InvestmentCsvRow>{};
    final issues = <InvestmentCsvIssue>[];
    for (var index = 1; index < rows.length; index += 1) {
      final row = rows[index];
      final lineNumber = index + 1;
      try {
        final ticker = _parseTicker(_cell(row, tickerIndex));
        final quantity = _requiredNumber(_cell(row, quantityIndex), '保有数量/数量');
        final buyPrice = _requiredNumber(
          _cell(row, buyPriceIndex),
          '平均取得価額/取得単価',
        );
        final currentPrice = currentPriceIndex == null
            ? null
            : _optionalNumber(_cell(row, currentPriceIndex));
        if (quantity <= 0) {
          throw const FormatException('保有数量/数量は0より大きい必要があります');
        }
        if (buyPrice < 0 || (currentPrice != null && currentPrice < 0)) {
          throw const FormatException('価格は0以上である必要があります');
        }

        final typeText = typeIndex == null ? '' : _cell(row, typeIndex);
        final draft = InvestmentAssetDraft(
          assetType: _assetType(typeText),
          ticker: ticker,
          quantity: quantity,
          buyPriceJpy: buyPrice,
          buyDate: dateIndex == null ? null : _parseDate(_cell(row, dateIndex)),
          currentPriceJpy: currentPrice,
        );
        final existing = parsedByTicker[draft.normalizedTicker];
        parsedByTicker[draft.normalizedTicker] = existing == null
            ? InvestmentCsvRow(lineNumber: lineNumber, draft: draft)
            : InvestmentCsvRow(
                lineNumber: existing.lineNumber,
                draft: _mergeDrafts(existing.draft, draft),
                mergedRowCount: existing.mergedRowCount + 1,
              );
      } on FormatException catch (error) {
        issues.add(
          InvestmentCsvIssue(
            lineNumber: lineNumber,
            message: error.message.toString(),
          ),
        );
      } on ArgumentError catch (error) {
        issues.add(
          InvestmentCsvIssue(
            lineNumber: lineNumber,
            message: error.message?.toString() ?? '値が不正です',
          ),
        );
      }
    }

    final parsedRows = parsedByTicker.values.toList()
      ..sort(
        (left, right) =>
            left.draft.normalizedTicker.compareTo(right.draft.normalizedTicker),
      );
    return InvestmentCsvParseResult(
      broker: broker,
      rows: List<InvestmentCsvRow>.unmodifiable(parsedRows),
      issues: List<InvestmentCsvIssue>.unmodifiable(issues),
      inputRowCount: rows.length - 1,
    );
  }

  InvestmentCsvImportPlan buildPlan({
    required InvestmentCsvParseResult parsed,
    required Iterable<InvestmentAsset> existingAssets,
    required InvestmentCsvDuplicatePolicy duplicatePolicy,
  }) {
    final existingByTicker = <String, InvestmentAsset>{};
    final sortedExisting = existingAssets.toList()
      ..sort((left, right) => left.id.compareTo(right.id));
    for (final asset in sortedExisting) {
      existingByTicker.putIfAbsent(
        asset.ticker.trim().toUpperCase(),
        () => asset,
      );
    }

    final creates = <InvestmentAssetDraft>[];
    final updates = <InvestmentCsvUpdate>[];
    var skippedDuplicates = 0;
    for (final row in parsed.rows) {
      final existing = existingByTicker[row.draft.normalizedTicker];
      if (existing == null) {
        creates.add(row.draft);
      } else if (duplicatePolicy == InvestmentCsvDuplicatePolicy.update) {
        updates.add(
          InvestmentCsvUpdate(
            asset: existing,
            draft: _mergeForUpdate(existing, row.draft),
          ),
        );
      } else {
        skippedDuplicates += 1;
      }
    }

    return InvestmentCsvImportPlan(
      creates: List<InvestmentAssetDraft>.unmodifiable(creates),
      updates: List<InvestmentCsvUpdate>.unmodifiable(updates),
      skippedDuplicates: skippedDuplicates,
      invalidRows: parsed.issues.length,
    );
  }

  static InvestmentAssetDraft _mergeForUpdate(
    InvestmentAsset existing,
    InvestmentAssetDraft imported,
  ) {
    final importedCurrentPrice = imported.currentPriceJpy;
    return InvestmentAssetDraft(
      assetType: imported.assetType == InvestmentAssetType.stock
          ? existing.assetType
          : imported.assetType,
      ticker: imported.normalizedTicker,
      quantity: imported.quantity,
      buyPriceJpy: imported.buyPriceJpy,
      buyDate: imported.buyDate ?? existing.buyDate,
      currentPriceJpy: importedCurrentPrice ?? existing.currentPriceJpy,
      lastPricedAt: importedCurrentPrice == null ? existing.lastPricedAt : null,
    );
  }

  static InvestmentAssetDraft _mergeDrafts(
    InvestmentAssetDraft left,
    InvestmentAssetDraft right,
  ) {
    final quantity = left.quantity + right.quantity;
    final acquisitionCost =
        left.quantity * left.buyPriceJpy + right.quantity * right.buyPriceJpy;
    return InvestmentAssetDraft(
      assetType: left.assetType == InvestmentAssetType.stock
          ? right.assetType
          : left.assetType,
      ticker: left.normalizedTicker,
      quantity: quantity,
      buyPriceJpy: acquisitionCost / quantity,
      buyDate: _earlier(left.buyDate, right.buyDate),
      currentPriceJpy: right.currentPriceJpy ?? left.currentPriceJpy,
    );
  }

  static DateTime? _earlier(DateTime? left, DateTime? right) {
    if (left == null) return right;
    if (right == null) return left;
    return left.isBefore(right) ? left : right;
  }

  static InvestmentCsvBroker _detectBroker(List<String> header) {
    if (header.contains('平均取得価額') || header.contains('保有数量')) {
      return InvestmentCsvBroker.rakuten;
    }
    if (header.contains('取得単価') || header.contains('数量')) {
      return InvestmentCsvBroker.sbi;
    }
    throw const FormatException('楽天証券/SBI証券のCSV列を判定できません');
  }

  static int _requiredIndex(
    List<String> header,
    List<String> aliases,
    String label,
  ) {
    final index = _optionalIndex(header, aliases);
    if (index == null) throw FormatException('CSVに「$label」列がありません');
    return index;
  }

  static int? _optionalIndex(List<String> header, List<String> aliases) {
    for (final alias in aliases) {
      final index = header.indexOf(_normalizeHeader(alias));
      if (index >= 0) return index;
    }
    return null;
  }

  static String _cell(List<String> row, int index) =>
      index < row.length ? row[index].trim() : '';

  static String _parseTicker(String value) {
    final normalized = _toHalfWidth(value).trim().toUpperCase();
    if (normalized.isEmpty) {
      throw const FormatException('銘柄コードが空です');
    }
    final candidates = RegExp(r'[A-Z0-9.\^=_-]{1,15}')
        .allMatches(normalized)
        .map((match) => match.group(0) ?? '')
        .where((candidate) => candidate.isNotEmpty)
        .toList();
    if (candidates.isEmpty) {
      throw const FormatException('銘柄コードを判定できません');
    }
    final domesticCode = candidates.where(
      (candidate) => RegExp(r'^\d{4}[A-Z]?$').hasMatch(candidate),
    );
    return (domesticCode.isNotEmpty ? domesticCode.first : candidates.first)
        .toUpperCase();
  }

  static double _requiredNumber(String value, String label) {
    final parsed = _optionalNumber(value);
    if (parsed == null) throw FormatException('$labelを数値として読めません');
    return parsed;
  }

  static double? _optionalNumber(String value) {
    var normalized = _toHalfWidth(value)
        .replaceAll(',', '')
        .replaceAll('¥', '')
        .replaceAll('￥', '')
        .replaceAll('円', '')
        .replaceAll('株', '')
        .replaceAll('口', '')
        .replaceAll(RegExp(r'\s'), '')
        .trim();
    if (normalized.isEmpty || normalized == '-') return null;
    if (normalized.startsWith('(') && normalized.endsWith(')')) {
      normalized = '-${normalized.substring(1, normalized.length - 1)}';
    }
    return double.tryParse(normalized);
  }

  static DateTime? _parseDate(String value) {
    final match = RegExp(
      r'^(\d{4})[/\-.年](\d{1,2})[/\-.月](\d{1,2})日?$',
    ).firstMatch(_toHalfWidth(value).trim());
    if (match == null) return null;
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final parsed = DateTime(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      return null;
    }
    return parsed;
  }

  static InvestmentAssetType _assetType(String value) {
    final normalized = _toHalfWidth(value).toUpperCase();
    if (normalized.contains('REIT') || normalized.contains('リート')) {
      return InvestmentAssetType.reit;
    }
    if (normalized.contains('ETF') || normalized.contains('上場投信')) {
      return InvestmentAssetType.etf;
    }
    if (normalized.contains('暗号') || normalized.contains('CRYPTO')) {
      return InvestmentAssetType.crypto;
    }
    return InvestmentAssetType.stock;
  }

  static String _normalizeHeader(String value) => _toHalfWidth(value)
      .replaceFirst('\ufeff', '')
      .replaceAll(RegExp(r'[\[［(（][^\]］)）]*[\]］)）]'), '')
      .replaceAll(RegExp(r'\s'), '')
      .replaceAll('・', '')
      .trim()
      .toLowerCase();

  static String _toHalfWidth(String value) {
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      if (rune >= 0xff10 && rune <= 0xff19) {
        buffer.writeCharCode(rune - 0xfee0);
      } else if (rune >= 0xff21 && rune <= 0xff3a) {
        buffer.writeCharCode(rune - 0xfee0);
      } else if (rune >= 0xff41 && rune <= 0xff5a) {
        buffer.writeCharCode(rune - 0xfee0);
      } else {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString();
  }

  static List<List<String>> _nonEmptyRows(String input) => _parseCsvRows(input)
      .where((row) => row.any((cell) => cell.trim().isNotEmpty))
      .toList(growable: false);

  static List<List<String>> _parseCsvRows(String input) {
    final rows = <List<String>>[];
    var row = <String>[];
    final cell = StringBuffer();
    var inQuotes = false;
    for (var index = 0; index < input.length; index += 1) {
      final character = input[index];
      if (character == '"') {
        if (inQuotes && index + 1 < input.length && input[index + 1] == '"') {
          cell.write('"');
          index += 1;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (!inQuotes && character == ',') {
        row.add(cell.toString());
        cell.clear();
      } else if (!inQuotes && (character == '\n' || character == '\r')) {
        if (character == '\r' &&
            index + 1 < input.length &&
            input[index + 1] == '\n') {
          index += 1;
        }
        row.add(cell.toString());
        cell.clear();
        rows.add(row);
        row = <String>[];
      } else {
        cell.write(character);
      }
    }
    if (cell.isNotEmpty || row.isNotEmpty) {
      row.add(cell.toString());
      rows.add(row);
    }
    return rows;
  }
}
