class SmbcCsvImportResult {
  const SmbcCsvImportResult({
    required this.transactions,
    required this.skippedRows,
  });

  final List<SmbcCsvTransaction> transactions;
  final int skippedRows;

  int get withdrawalCount =>
      transactions.where((item) => item.isWithdrawal).length;

  int get depositCount => transactions.where((item) => item.isDeposit).length;

  DateTime? get latestDate {
    DateTime? latest;
    for (final item in transactions) {
      if (latest == null || item.date.isAfter(latest)) {
        latest = item.date;
      }
    }
    return latest;
  }

  int? get latestBalance {
    DateTime? latest;
    int? balance;
    for (final item in transactions) {
      final itemBalance = item.balance;
      if (itemBalance == null) continue;
      if (latest == null || item.date.isAfter(latest)) {
        latest = item.date;
        balance = itemBalance;
      }
    }
    return balance;
  }
}

class SmbcCsvTransaction {
  const SmbcCsvTransaction({
    required this.date,
    required this.amount,
    required this.content,
    required this.importKey,
    this.isDeposit = false,
    this.balance,
    this.memo,
    this.label,
  });

  final DateTime date;
  final int amount;
  final String content;
  final String importKey;
  final bool isDeposit;
  final int? balance;
  final String? memo;
  final String? label;

  bool get isWithdrawal => !isDeposit;

  String get actionType => isDeposit ? 'conquer' : 'expense';

  String get displayMemo {
    final parts = <String>[
      content.trim(),
      if ((memo ?? '').trim().isNotEmpty) (memo ?? '').trim(),
      if ((label ?? '').trim().isNotEmpty) (label ?? '').trim(),
    ].where((part) => part.isNotEmpty).toList();
    return parts.isEmpty ? '三井住友銀行CSV取込' : parts.join(' / ');
  }
}

class SmbcCsvImportService {
  const SmbcCsvImportService();

  static const _dateHeader = '年月日';
  static const _withdrawalHeader = 'お引出し';
  static const _depositHeader = 'お預入れ';
  static const _contentHeader = 'お取り扱い内容';
  static const _balanceHeader = '残高';
  static const _memoHeader = 'メモ';
  static const _labelHeader = 'ラベル';

  static bool looksLikeCsv(String text) {
    final rows = _parseCsvRows(
      text,
    ).where((row) => row.any((cell) => cell.trim().isNotEmpty)).toList();
    if (rows.isEmpty) return false;
    final header = rows.first.map(_normalizeHeader).toList();
    return <String>[
      _dateHeader,
      _withdrawalHeader,
      _depositHeader,
      _contentHeader,
    ].every(header.contains);
  }

  SmbcCsvImportResult parse(final String csvText) {
    final rows = _parseCsvRows(
      csvText,
    ).where((row) => row.any((cell) => cell.trim().isNotEmpty)).toList();
    if (rows.isEmpty) {
      throw const FormatException('CSVに明細行がありません');
    }

    final header = rows.first.map(_normalizeHeader).toList();
    final dateIndex = _requiredIndex(header, _dateHeader);
    final withdrawalIndex = _requiredIndex(header, _withdrawalHeader);
    final depositIndex = _requiredIndex(header, _depositHeader);
    final contentIndex = _requiredIndex(header, _contentHeader);
    final balanceIndex = _optionalIndex(header, _balanceHeader);
    final memoIndex = _optionalIndex(header, _memoHeader);
    final labelIndex = _optionalIndex(header, _labelHeader);

    final duplicateOrdinals = <String, int>{};
    final transactions = <SmbcCsvTransaction>[];
    var skippedRows = 0;

    for (final row in rows.skip(1)) {
      final date = _parseDate(_cell(row, dateIndex));
      final withdrawal = _parseAmount(_cell(row, withdrawalIndex));
      final deposit = _parseAmount(_cell(row, depositIndex));
      final content = _cell(row, contentIndex).trim();
      final balance =
          balanceIndex == null ? null : _parseAmount(_cell(row, balanceIndex));
      final memo = memoIndex == null ? '' : _cell(row, memoIndex).trim();
      final label = labelIndex == null ? '' : _cell(row, labelIndex).trim();

      if (date == null || ((withdrawal ?? 0) <= 0 && (deposit ?? 0) <= 0)) {
        skippedRows += 1;
        continue;
      }

      void addTransaction({
        required final int amount,
        required final bool isDeposit,
      }) {
        final base = [
          _dateKey(date),
          amount.toString(),
          isDeposit ? 'deposit' : 'withdrawal',
          content,
          balance?.toString() ?? '',
          memo,
          label,
        ].join('|');
        final ordinal = (duplicateOrdinals[base] ?? 0) + 1;
        duplicateOrdinals[base] = ordinal;
        transactions.add(
          SmbcCsvTransaction(
            date: date,
            amount: amount,
            content: content.isEmpty ? '三井住友銀行CSV取込' : content,
            importKey: 'smbc:${_dateKey(date)}:${_shortHash(base)}:$ordinal',
            isDeposit: isDeposit,
            balance: balance,
            memo: memo.isEmpty ? null : memo,
            label: label.isEmpty ? null : label,
          ),
        );
      }

      if ((withdrawal ?? 0) > 0) {
        addTransaction(amount: withdrawal!, isDeposit: false);
      }
      if ((deposit ?? 0) > 0) {
        addTransaction(amount: deposit!, isDeposit: true);
      }
    }

    return SmbcCsvImportResult(
      transactions: transactions,
      skippedRows: skippedRows,
    );
  }

  static List<List<String>> _parseCsvRows(final String input) {
    final rows = <List<String>>[];
    var row = <String>[];
    final cell = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < input.length; i += 1) {
      final char = input[i];
      if (char == '"') {
        if (inQuotes && i + 1 < input.length && input[i + 1] == '"') {
          cell.write('"');
          i += 1;
        } else {
          inQuotes = !inQuotes;
        }
        continue;
      }
      if (!inQuotes && char == ',') {
        row.add(cell.toString());
        cell.clear();
        continue;
      }
      if (!inQuotes && (char == '\n' || char == '\r')) {
        if (char == '\r' && i + 1 < input.length && input[i + 1] == '\n') {
          i += 1;
        }
        row.add(cell.toString());
        cell.clear();
        rows.add(row);
        row = <String>[];
        continue;
      }
      cell.write(char);
    }

    if (cell.isNotEmpty || row.isNotEmpty) {
      row.add(cell.toString());
      rows.add(row);
    }
    return rows;
  }

  static int _requiredIndex(final List<String> header, final String name) {
    final index = _optionalIndex(header, name);
    if (index == null) {
      throw FormatException('CSVに「$name」列がありません');
    }
    return index;
  }

  static int? _optionalIndex(final List<String> header, final String name) {
    final normalizedName = _normalizeHeader(name);
    final index = header.indexOf(normalizedName);
    return index < 0 ? null : index;
  }

  static String _cell(final List<String> row, final int index) {
    if (index < 0 || index >= row.length) return '';
    return row[index];
  }

  static String _normalizeHeader(final String value) =>
      value.replaceFirst('\ufeff', '').trim();

  static DateTime? _parseDate(final String value) {
    final parts = value.trim().split(RegExp(r'[/\-]'));
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    return DateTime(year, month, day);
  }

  static int? _parseAmount(final String value) {
    final normalized = value
        .replaceAll(',', '')
        .replaceAll('￥', '')
        .replaceAll('¥', '')
        .trim();
    if (normalized.isEmpty) return null;
    final parsed = int.tryParse(normalized);
    if (parsed == null) return null;
    return parsed.abs();
  }

  static String _dateKey(final DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}'
      '${date.month.toString().padLeft(2, '0')}'
      '${date.day.toString().padLeft(2, '0')}';

  static String _shortHash(final String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}
