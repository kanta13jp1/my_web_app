import 'package:my_web_app/models/asset_obsidian_vault_import.dart';

class AssetObsidianVaultImportService {
  const AssetObsidianVaultImportService();

  AssetObsidianImportPreview preview({
    required List<AssetObsidianVaultFile> files,
    required List<AssetObsidianExistingBalance> existingBalances,
  }) {
    final parsed = <_ParsedBalance>[];
    final recognizedPaths = <String>{};
    final warnings = <String>[];

    for (final file in files) {
      final result = _parseFile(file);
      if (result.recognized) {
        recognizedPaths.add(file.relativePath);
      }
      parsed.addAll(result.balances);
      warnings.addAll(result.warnings);
    }

    final existingByKey = <String, AssetObsidianExistingBalance>{};
    for (final existing in existingBalances) {
      existingByKey[_accountKey(existing.accountName)] = existing;
    }

    final grouped = <String, List<_ParsedBalance>>{};
    for (final balance in parsed) {
      grouped
          .putIfAbsent(
            _accountKey(balance.accountName),
            () => <_ParsedBalance>[],
          )
          .add(balance);
    }

    final candidates = <AssetObsidianImportCandidate>[];
    for (final entry in grouped.entries) {
      final records = entry.value;
      records.sort((a, b) => b.observedDate.compareTo(a.observedDate));
      final latestDate = records.first.observedDate;
      final latestRecords = records
          .where((record) => _sameDate(record.observedDate, latestDate))
          .toList(growable: false);
      final uniqueAmounts =
          latestRecords.map((record) => record.amount).toSet();
      final first = latestRecords.first;
      final existing = existingByKey[entry.key];
      final resolvedName = existing?.accountName ?? first.accountName;
      final sourcePaths = latestRecords
          .map((record) => record.sourcePath)
          .toSet()
          .toList(growable: false)
        ..sort();

      if (uniqueAmounts.length > 1) {
        final amounts = uniqueAmounts.toList()..sort();
        candidates.add(
          AssetObsidianImportCandidate(
            accountName: resolvedName,
            sourceAccountName: first.sourceAccountName,
            observedDate: latestDate,
            amount: first.amount,
            status: AssetObsidianImportStatus.conflict,
            sourcePaths: sourcePaths,
            existingAmount: existing?.amount,
            existingObservedDate: existing?.observedDate,
            conflictingAmounts: amounts,
          ),
        );
        continue;
      }

      final amount = uniqueAmounts.single;
      final status = _statusFor(
        observedDate: latestDate,
        amount: amount,
        existing: existing,
      );
      candidates.add(
        AssetObsidianImportCandidate(
          accountName: resolvedName,
          sourceAccountName: first.sourceAccountName,
          observedDate: latestDate,
          amount: amount,
          status: status,
          sourcePaths: sourcePaths,
          existingAmount: existing?.amount,
          existingObservedDate: existing?.observedDate,
        ),
      );
    }

    candidates.sort((a, b) {
      final statusCompare = a.status.index.compareTo(b.status.index);
      return statusCompare != 0
          ? statusCompare
          : a.accountName.compareTo(b.accountName);
    });
    if (recognizedPaths.isEmpty) {
      warnings.add('対応する残高表が見つかりませんでした。');
    }

    return AssetObsidianImportPreview(
      scannedFileCount: files.length,
      recognizedFileCount: recognizedPaths.length,
      candidates: candidates,
      warnings: warnings.toSet().toList(growable: false),
    );
  }

  AssetObsidianImportStatus _statusFor({
    required DateTime observedDate,
    required double amount,
    required AssetObsidianExistingBalance? existing,
  }) {
    if (existing == null) return AssetObsidianImportStatus.newAccount;
    if (observedDate.isBefore(existing.observedDate)) {
      return AssetObsidianImportStatus.stale;
    }
    if (amount == existing.amount) {
      return observedDate.isAfter(existing.observedDate)
          ? AssetObsidianImportStatus.update
          : AssetObsidianImportStatus.unchanged;
    }
    return AssetObsidianImportStatus.update;
  }

  _ParseResult _parseFile(AssetObsidianVaultFile file) {
    final lines = file.content.split(RegExp(r'\r?\n'));
    final balances = <_ParsedBalance>[];
    final warnings = <String>[];
    var recognized = false;

    for (var index = 0; index < lines.length; index++) {
      final header = _tableCells(lines[index]);
      if (header == null) continue;

      final confirmedDateIndex = _columnIndex(header, '確認日');
      final accountIndex = _columnIndex(header, '口座・サービス名');
      final latestBalanceIndex = _columnIndex(header, '最新確認残高');
      if (confirmedDateIndex >= 0 &&
          accountIndex >= 0 &&
          latestBalanceIndex >= 0) {
        recognized = true;
        index = _parseAccountTable(
          lines: lines,
          headerIndex: index,
          dateIndex: confirmedDateIndex,
          accountIndex: accountIndex,
          amountIndex: latestBalanceIndex,
          sourcePath: file.relativePath,
          balances: balances,
          warnings: warnings,
        );
        continue;
      }

      final debtNameIndex = _columnIndex(header, '借入・カード名');
      final debtBalanceIndex = header.indexWhere(
        (cell) => cell.startsWith('残高（') || cell.startsWith('残高('),
      );
      if (debtNameIndex >= 0 && debtBalanceIndex >= 0) {
        final headerDate = _parseDate(header[debtBalanceIndex]);
        if (headerDate == null) {
          warnings.add('${file.relativePath}: 負債残高列の日付を読み取れませんでした。');
          continue;
        }
        recognized = true;
        index = _parseDebtTable(
          lines: lines,
          headerIndex: index,
          observedDate: headerDate,
          accountIndex: debtNameIndex,
          amountIndex: debtBalanceIndex,
          sourcePath: file.relativePath,
          balances: balances,
          warnings: warnings,
        );
      }
    }

    return _ParseResult(
      recognized: recognized,
      balances: balances,
      warnings: warnings,
    );
  }

  int _parseAccountTable({
    required List<String> lines,
    required int headerIndex,
    required int dateIndex,
    required int accountIndex,
    required int amountIndex,
    required String sourcePath,
    required List<_ParsedBalance> balances,
    required List<String> warnings,
  }) {
    var index = headerIndex + 1;
    if (index < lines.length && _isSeparatorRow(lines[index])) index++;
    for (; index < lines.length; index++) {
      final cells = _tableCells(lines[index]);
      if (cells == null) break;
      final maxIndex = [
        dateIndex,
        accountIndex,
        amountIndex,
      ].reduce((a, b) => a > b ? a : b);
      if (cells.length <= maxIndex) continue;
      final date = _parseDate(cells[dateIndex]);
      final amount = _parseAmount(cells[amountIndex]);
      final sourceName = _cleanCell(cells[accountIndex]);
      if (date == null || amount == null || sourceName.isEmpty) {
        warnings.add('$sourcePath:${index + 1}: 残高行を読み飛ばしました。');
        continue;
      }
      balances.add(
        _ParsedBalance(
          accountName: _canonicalAccountName(sourceName),
          sourceAccountName: sourceName,
          observedDate: date,
          amount: amount,
          sourcePath: sourcePath,
        ),
      );
    }
    return index - 1;
  }

  int _parseDebtTable({
    required List<String> lines,
    required int headerIndex,
    required DateTime observedDate,
    required int accountIndex,
    required int amountIndex,
    required String sourcePath,
    required List<_ParsedBalance> balances,
    required List<String> warnings,
  }) {
    var index = headerIndex + 1;
    if (index < lines.length && _isSeparatorRow(lines[index])) index++;
    for (; index < lines.length; index++) {
      final cells = _tableCells(lines[index]);
      if (cells == null) break;
      final maxIndex = accountIndex > amountIndex ? accountIndex : amountIndex;
      if (cells.length <= maxIndex) continue;
      final sourceName = _cleanCell(cells[accountIndex]);
      if (sourceName.contains('全') || sourceName == '合計') continue;
      final amount = _parseAmount(cells[amountIndex]);
      if (amount == null || sourceName.isEmpty) {
        warnings.add('$sourcePath:${index + 1}: 負債残高行を読み飛ばしました。');
        continue;
      }
      balances.add(
        _ParsedBalance(
          accountName: _canonicalAccountName(sourceName),
          sourceAccountName: sourceName,
          observedDate: observedDate,
          amount: amount,
          sourcePath: sourcePath,
        ),
      );
    }
    return index - 1;
  }

  List<String>? _tableCells(String line) {
    final trimmed = line.trim();
    if (!trimmed.startsWith('|') || !trimmed.endsWith('|')) return null;
    final pieces = trimmed.substring(1, trimmed.length - 1).split('|');
    return pieces.map(_cleanCell).toList(growable: false);
  }

  bool _isSeparatorRow(String line) {
    final cells = _tableCells(line);
    return cells != null &&
        cells.isNotEmpty &&
        cells.every((cell) => RegExp(r'^:?-{3,}:?$').hasMatch(cell));
  }

  int _columnIndex(List<String> header, String name) =>
      header.indexWhere((cell) => cell == name);

  String _cleanCell(String value) => value
      .trim()
      .replaceAll('**', '')
      .replaceAll('__', '')
      .replaceAll('`', '')
      .trim();

  DateTime? _parseDate(String value) {
    final match = RegExp(
      r'(\d{4})[-/](\d{1,2})[-/](\d{1,2})',
    ).firstMatch(value);
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

  double? _parseAmount(String value) {
    final normalized = _cleanCell(value)
        .replaceAll(',', '')
        .replaceAll('¥', '')
        .replaceAll('￥', '')
        .replaceAll('円', '')
        .replaceAll('−', '-')
        .replaceAll('–', '-')
        .replaceAll(RegExp(r'\s+'), '');
    final match = RegExp(r'[-+]?\d+(?:\.\d+)?').firstMatch(normalized);
    return match == null ? null : double.tryParse(match.group(0)!);
  }

  String _canonicalAccountName(String sourceName) {
    final key = _accountKey(sourceName);
    const aliases = <String, String>{
      '三井住友銀行大塚支店普通預金': '三井住友銀行大塚支店',
      '三井住友銀行大塚支店': '三井住友銀行大塚支店',
      '三井住友銀行大塚支店cl普通': '三井住友銀行大塚支店CL口座',
      '三井住友銀行大塚支店cl口座': '三井住友銀行大塚支店CL口座',
      'auじぶん銀行普通預金': 'じぶん銀行',
      'auじぶん銀行': 'じぶん銀行',
      '財布現金管理': '現金',
      '三井住友銀行神田支店普通預金': '三井住友銀行神田支店',
      'じぶんローン': 'じぶん銀行カードローン',
      'aupayカード': 'au PAYカード',
    };
    return aliases[key] ?? sourceName;
  }

  String _accountKey(String value) => _cleanCell(value)
      .toLowerCase()
      .replaceAll('（', '(')
      .replaceAll('）', ')')
      .replaceAll(RegExp(r'[\s()・]'), '');

  bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _ParsedBalance {
  const _ParsedBalance({
    required this.accountName,
    required this.sourceAccountName,
    required this.observedDate,
    required this.amount,
    required this.sourcePath,
  });

  final String accountName;
  final String sourceAccountName;
  final DateTime observedDate;
  final double amount;
  final String sourcePath;
}

class _ParseResult {
  const _ParseResult({
    required this.recognized,
    required this.balances,
    required this.warnings,
  });

  final bool recognized;
  final List<_ParsedBalance> balances;
  final List<String> warnings;
}
