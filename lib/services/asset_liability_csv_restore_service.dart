import 'package:intl/intl.dart';

import '../models/asset_liability_workbook.dart';
import 'asset_liability_monthly_state_store.dart';

enum AssetLiabilityCsvRestoreApplyPolicy {
  appendOnly,
  overwriteImportedFields,
  skipExistingMonths,
}

enum AssetLiabilityCsvRestoreSection {
  monthlyHistory,
  paymentSchedule,
  cardStatement,
  incomePlans,
  accountCashflow,
  unknown,
}

class AssetLiabilityCsvRestoreRejectedRow {
  final AssetLiabilityCsvRestoreSection section;
  final int rowNumber;
  final String rawText;
  final String reason;

  const AssetLiabilityCsvRestoreRejectedRow({
    required this.section,
    required this.rowNumber,
    required this.rawText,
    required this.reason,
  });
}

class AssetLiabilityCsvRestorePreview {
  final Map<String, AssetLiabilityMonthlyState> monthlyStates;
  final List<AssetLiabilityMonthlySnapshot> monthlySnapshots;
  final List<AssetLiabilityCsvRestoreRejectedRow> rejectedRows;
  final Set<AssetLiabilityCsvRestoreSection> detectedSections;

  const AssetLiabilityCsvRestorePreview({
    this.monthlyStates = const <String, AssetLiabilityMonthlyState>{},
    this.monthlySnapshots = const <AssetLiabilityMonthlySnapshot>[],
    this.rejectedRows = const <AssetLiabilityCsvRestoreRejectedRow>[],
    this.detectedSections = const <AssetLiabilityCsvRestoreSection>{},
  });

  bool get hasRestorableRows =>
      monthlyStates.isNotEmpty || monthlySnapshots.isNotEmpty;

  int get restoredPaymentCount => monthlyStates.values.fold<int>(
        0,
        (sum, state) => sum + state.paymentOverrides.length,
      );

  int get restoredIncomeCount => monthlyStates.values.fold<int>(
        0,
        (sum, state) => sum + state.incomePlans.length,
      );

  int get restoredCardStatementLineCount => monthlyStates.values.fold<int>(
        0,
        (sum, state) => sum + state.cardStatementLines.length,
      );

  List<String> get affectedMonthKeys {
    final keys = <String>{
      ...monthlyStates.keys,
      for (final snapshot in monthlySnapshots) snapshot.monthKey,
    }.toList()
      ..sort();
    return keys;
  }
}

class AssetLiabilityCsvRestoreMergeResult {
  final Map<String, AssetLiabilityMonthlyState> monthlyStates;
  final List<AssetLiabilityMonthlySnapshot> monthlySnapshots;
  final List<String> warnings;

  const AssetLiabilityCsvRestoreMergeResult({
    required this.monthlyStates,
    required this.monthlySnapshots,
    this.warnings = const <String>[],
  });
}

class AssetLiabilityCsvRestoreService {
  const AssetLiabilityCsvRestoreService();

  AssetLiabilityCsvRestorePreview previewCsvText(String rawText) {
    final rows = _parseCsv(rawText);
    if (rows.isEmpty) {
      return const AssetLiabilityCsvRestorePreview(
        rejectedRows: <AssetLiabilityCsvRestoreRejectedRow>[
          AssetLiabilityCsvRestoreRejectedRow(
            section: AssetLiabilityCsvRestoreSection.unknown,
            rowNumber: 0,
            rawText: '',
            reason: 'CSV is empty',
          ),
        ],
      );
    }
    final header = rows.first;
    final section = _detectSection(header);
    return previewCsvSections(<AssetLiabilityCsvRestoreSection, String>{
      section: rawText,
    });
  }

  AssetLiabilityCsvRestorePreview previewCsvSections(
    Map<AssetLiabilityCsvRestoreSection, String> csvBySection,
  ) {
    final stateByMonth = <String, AssetLiabilityMonthlyState>{};
    final snapshotsByMonth = <String, AssetLiabilityMonthlySnapshot>{};
    final rejected = <AssetLiabilityCsvRestoreRejectedRow>[];
    final detectedSections = <AssetLiabilityCsvRestoreSection>{};

    void mergeState(String monthKey, AssetLiabilityMonthlyState patch) {
      stateByMonth[monthKey] = _mergeStateAppendOnly(
        stateByMonth[monthKey] ?? const AssetLiabilityMonthlyState(),
        patch,
      );
    }

    for (final entry in csvBySection.entries) {
      final rows = _parseCsv(entry.value);
      if (rows.isEmpty) {
        rejected.add(
          AssetLiabilityCsvRestoreRejectedRow(
            section: entry.key,
            rowNumber: 0,
            rawText: '',
            reason: 'CSV is empty',
          ),
        );
        continue;
      }
      final detected = entry.key == AssetLiabilityCsvRestoreSection.unknown
          ? _detectSection(rows.first)
          : entry.key;
      detectedSections.add(detected);
      switch (detected) {
        case AssetLiabilityCsvRestoreSection.monthlyHistory:
          for (final parsed in _parseMonthlyHistory(rows, rejected)) {
            snapshotsByMonth[parsed.monthKey] = parsed;
          }
          break;
        case AssetLiabilityCsvRestoreSection.paymentSchedule:
          for (final parsed in _parsePaymentSchedule(rows, rejected)) {
            mergeState(parsed.monthKey, parsed.state);
          }
          break;
        case AssetLiabilityCsvRestoreSection.cardStatement:
          for (final parsed in _parseCardStatements(rows, rejected)) {
            mergeState(parsed.monthKey, parsed.state);
          }
          break;
        case AssetLiabilityCsvRestoreSection.incomePlans:
          for (final parsed in _parseIncomePlans(rows, rejected)) {
            mergeState(parsed.monthKey, parsed.state);
          }
          break;
        case AssetLiabilityCsvRestoreSection.accountCashflow:
          // Account cashflow exports are derived summaries; they are useful for
          // human audit but do not restore mutable state.
          break;
        case AssetLiabilityCsvRestoreSection.unknown:
          rejected.add(
            AssetLiabilityCsvRestoreRejectedRow(
              section: detected,
              rowNumber: 1,
              rawText: rows.first.join(','),
              reason: 'CSV section could not be detected',
            ),
          );
          break;
      }
    }

    return AssetLiabilityCsvRestorePreview(
      monthlyStates: Map<String, AssetLiabilityMonthlyState>.from(stateByMonth),
      monthlySnapshots: snapshotsByMonth.values.toList(growable: false)
        ..sort((a, b) => a.monthKey.compareTo(b.monthKey)),
      rejectedRows: rejected,
      detectedSections: detectedSections,
    );
  }

  AssetLiabilityCsvRestoreMergeResult mergePreview({
    required AssetLiabilityCsvRestorePreview preview,
    required Map<String, AssetLiabilityMonthlyState> existingStates,
    required List<AssetLiabilityMonthlySnapshot> existingSnapshots,
    required AssetLiabilityCsvRestoreApplyPolicy policy,
  }) {
    if (!preview.hasRestorableRows) {
      return AssetLiabilityCsvRestoreMergeResult(
        monthlyStates: Map<String, AssetLiabilityMonthlyState>.from(
          existingStates,
        ),
        monthlySnapshots: List<AssetLiabilityMonthlySnapshot>.from(
          existingSnapshots,
        ),
        warnings: const <String>['No restorable rows were found.'],
      );
    }

    final states = Map<String, AssetLiabilityMonthlyState>.from(existingStates);
    final snapshotsByMonth = <String, AssetLiabilityMonthlySnapshot>{
      for (final snapshot in existingSnapshots) snapshot.monthKey: snapshot,
    };
    final warnings = <String>[];

    for (final entry in preview.monthlyStates.entries) {
      final existing = states[entry.key];
      if (policy == AssetLiabilityCsvRestoreApplyPolicy.skipExistingMonths &&
          existing != null &&
          !existing.isEmpty) {
        warnings.add(
          'Skipped ${entry.key}: existing monthly state is present.',
        );
        continue;
      }
      states[entry.key] = switch (policy) {
        AssetLiabilityCsvRestoreApplyPolicy.appendOnly => _mergeStateAppendOnly(
            existing ?? const AssetLiabilityMonthlyState(),
            entry.value,
          ),
        AssetLiabilityCsvRestoreApplyPolicy.overwriteImportedFields =>
          _mergeStateOverwriteImportedFields(
            existing ?? const AssetLiabilityMonthlyState(),
            entry.value,
          ),
        AssetLiabilityCsvRestoreApplyPolicy.skipExistingMonths => entry.value,
      };
    }

    for (final snapshot in preview.monthlySnapshots) {
      final existing = snapshotsByMonth[snapshot.monthKey];
      if (policy == AssetLiabilityCsvRestoreApplyPolicy.skipExistingMonths &&
          existing != null) {
        warnings.add('Skipped ${snapshot.monthKey}: snapshot already exists.');
        continue;
      }
      if (policy == AssetLiabilityCsvRestoreApplyPolicy.appendOnly &&
          existing != null) {
        warnings.add(
          'Kept existing ${snapshot.monthKey}: append-only does not overwrite.',
        );
        continue;
      }
      snapshotsByMonth[snapshot.monthKey] = snapshot;
    }

    return AssetLiabilityCsvRestoreMergeResult(
      monthlyStates: states,
      monthlySnapshots: snapshotsByMonth.values.toList(growable: false)
        ..sort((a, b) => a.monthKey.compareTo(b.monthKey)),
      warnings: warnings,
    );
  }

  AssetLiabilityCsvRestoreSection _detectSection(List<String> header) {
    final normalized = header.map((cell) => cell.toLowerCase()).join(',');
    if (normalized.contains('actual_paid_payment_total') ||
        normalized.contains('payment_difference_total')) {
      return AssetLiabilityCsvRestoreSection.monthlyHistory;
    }
    if (normalized.contains('payment_difference_reason') ||
        normalized.contains('actual_payment_amount')) {
      return AssetLiabilityCsvRestoreSection.paymentSchedule;
    }
    if (normalized.contains('statement_difference') ||
        normalized.contains('billing_account_id')) {
      return AssetLiabilityCsvRestoreSection.cardStatement;
    }
    if (normalized.contains('amount') && normalized.contains('received')) {
      return AssetLiabilityCsvRestoreSection.incomePlans;
    }
    if (header.length == 5) {
      return AssetLiabilityCsvRestoreSection.incomePlans;
    }
    if (header.length == 6) {
      return AssetLiabilityCsvRestoreSection.accountCashflow;
    }
    return AssetLiabilityCsvRestoreSection.unknown;
  }

  List<AssetLiabilityMonthlySnapshot> _parseMonthlyHistory(
    List<List<String>> rows,
    List<AssetLiabilityCsvRestoreRejectedRow> rejected,
  ) {
    final snapshots = <AssetLiabilityMonthlySnapshot>[];
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.every((cell) => cell.trim().isEmpty)) {
        continue;
      }
      final monthKey = _cell(row, 0);
      final savedAt = DateTime.tryParse(_cell(row, 1));
      final positiveAssetTotal = _parseDouble(_cell(row, 2));
      final liabilityTotal = _parseDouble(_cell(row, 3));
      final netWorth = _parseDouble(_cell(row, 4));
      final cashLikeTotal = _parseDouble(_cell(row, 5));
      final scheduled = _parseDouble(_cell(row, 6));
      final paid = _parseDouble(_cell(row, 7));
      final unpaid = _parseDouble(_cell(row, 8));
      final overdue = _parseInt(_cell(row, 9));
      if (!_isMonthKey(monthKey) ||
          savedAt == null ||
          positiveAssetTotal == null ||
          liabilityTotal == null ||
          netWorth == null ||
          cashLikeTotal == null ||
          scheduled == null ||
          paid == null ||
          unpaid == null ||
          overdue == null) {
        rejected.add(
          _rejected(
            AssetLiabilityCsvRestoreSection.monthlyHistory,
            i + 1,
            row,
            'monthly snapshot columns are invalid',
          ),
        );
        continue;
      }
      snapshots.add(
        AssetLiabilityMonthlySnapshot(
          monthKey: monthKey,
          savedAt: savedAt,
          positiveAssetTotal: positiveAssetTotal,
          liabilityTotal: liabilityTotal,
          netWorth: netWorth,
          cashLikeTotal: cashLikeTotal,
          monthlyScheduledPaymentTotal: scheduled,
          monthlyPaidPaymentTotal: paid,
          monthlyUnpaidPaymentTotal: unpaid,
          monthlyActualPaymentTotal: _parseDouble(_cell(row, 10)) ?? paid,
          monthlyPaymentDifferenceTotal: _parseDouble(_cell(row, 11)) ?? 0,
          overduePaymentCount: overdue,
        ),
      );
    }
    return snapshots;
  }

  List<_MonthlyStatePatch> _parsePaymentSchedule(
    List<List<String>> rows,
    List<AssetLiabilityCsvRestoreRejectedRow> rejected,
  ) {
    final patches = <_MonthlyStatePatch>[];
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      final date = DateTime.tryParse(_cell(row, 5));
      final accountName = _cell(row, 6);
      final amount = _parseDouble(_cell(row, 11));
      if (date == null || accountName.isEmpty || amount == null || amount < 0) {
        rejected.add(
          _rejected(
            AssetLiabilityCsvRestoreSection.paymentSchedule,
            i + 1,
            row,
            'payment date, account, or amount is invalid',
          ),
        );
        continue;
      }
      final actual = _parseDouble(_cell(row, 16));
      final differenceReason = _cell(row, 18);
      final paid = actual != null || _looksPaid(_cell(row, 13));
      patches.add(
        _MonthlyStatePatch(
          monthKey: AssetLiabilityMonthlyStateStore.formatMonthKey(date),
          state: AssetLiabilityMonthlyState(
            paymentOverrides: <String, double>{accountName: amount},
            actualPaymentAmounts: actual == null
                ? const <String, double>{}
                : <String, double>{accountName: actual},
            paymentDifferenceReasons: differenceReason.isEmpty
                ? const <String, String>{}
                : <String, String>{accountName: differenceReason},
            paidAccountNames: paid ? <String>{accountName} : const <String>{},
          ),
        ),
      );
    }
    return patches;
  }

  List<_MonthlyStatePatch> _parseIncomePlans(
    List<List<String>> rows,
    List<AssetLiabilityCsvRestoreRejectedRow> rejected,
  ) {
    final patches = <_MonthlyStatePatch>[];
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      final date = DateTime.tryParse(_cell(row, 0));
      final name = _cell(row, 1);
      final amount = _parseDouble(_cell(row, 2));
      if (date == null || name.isEmpty || amount == null || amount <= 0) {
        rejected.add(
          _rejected(
            AssetLiabilityCsvRestoreSection.incomePlans,
            i + 1,
            row,
            'income date, name, or amount is invalid',
          ),
        );
        continue;
      }
      final monthKey = AssetLiabilityMonthlyStateStore.formatMonthKey(date);
      patches.add(
        _MonthlyStatePatch(
          monthKey: monthKey,
          state: AssetLiabilityMonthlyState(
            incomePlans: <AssetLiabilityIncomePlan>[
              AssetLiabilityIncomePlan(
                id: _stableId('income', monthKey, name, i),
                date: date,
                name: name,
                amount: amount,
                destinationAccountId: null,
                destinationAccountName: _emptyToNull(_cell(row, 3)),
                received: _looksPaid(_cell(row, 4)),
              ),
            ],
          ),
        ),
      );
    }
    return patches;
  }

  List<_MonthlyStatePatch> _parseCardStatements(
    List<List<String>> rows,
    List<AssetLiabilityCsvRestoreRejectedRow> rejected,
  ) {
    final header = rows.first.map((cell) => cell.toLowerCase()).toList();
    final billingIndex = _indexOf(header, 'billing_account_id', fallback: 0);
    final billingNameIndex = _indexOf(
      header,
      'billing_account_name',
      fallback: 1,
    );
    final postedAtIndex = _indexOf(header, 'posted_at', fallback: 2);
    final descriptionIndex = _indexOf(header, 'description', fallback: 3);
    final amountIndex = _indexOf(header, 'amount', fallback: 4);
    final patches = <_MonthlyStatePatch>[];
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      final billingAccountId = _cell(row, billingIndex);
      final description = _cell(row, descriptionIndex);
      final amount = _parseDouble(_cell(row, amountIndex));
      final postedAt = DateTime.tryParse(_cell(row, postedAtIndex));
      if (billingAccountId.isEmpty || description.isEmpty || amount == null) {
        rejected.add(
          _rejected(
            AssetLiabilityCsvRestoreSection.cardStatement,
            i + 1,
            row,
            'card statement billing account, description, or amount is invalid',
          ),
        );
        continue;
      }
      final month = postedAt ?? DateTime.now();
      final monthKey = AssetLiabilityMonthlyStateStore.formatMonthKey(month);
      patches.add(
        _MonthlyStatePatch(
          monthKey: monthKey,
          state: AssetLiabilityMonthlyState(
            cardStatementLines: <AssetLiabilityCardStatementLine>[
              AssetLiabilityCardStatementLine(
                id: _stableId(
                  'card',
                  billingAccountId,
                  '$description-${amount.toStringAsFixed(2)}',
                  i,
                ),
                billingAccountId: billingAccountId,
                billingAccountName: _emptyToNull(_cell(row, billingNameIndex)),
                postedAt: postedAt,
                description: description,
                amount: amount,
              ),
            ],
          ),
        ),
      );
    }
    return patches;
  }

  AssetLiabilityMonthlyState _mergeStateAppendOnly(
    AssetLiabilityMonthlyState existing,
    AssetLiabilityMonthlyState patch,
  ) {
    return AssetLiabilityMonthlyState(
      paymentOverrides: _appendMap(
        existing.paymentOverrides,
        patch.paymentOverrides,
      ),
      actualPaymentAmounts: _appendMap(
        existing.actualPaymentAmounts,
        patch.actualPaymentAmounts,
      ),
      paymentDifferenceReasons: _appendMap(
        existing.paymentDifferenceReasons,
        patch.paymentDifferenceReasons,
      ),
      annualRateOverrides: Map<String, double>.from(
        existing.annualRateOverrides,
      ),
      annualRateEvidences: Map<String, AssetLiabilityAnnualRateEvidence>.from(
        existing.annualRateEvidences,
      ),
      paidAccountNames: <String>{
        ...existing.paidAccountNames,
        ...patch.paidAccountNames,
      },
      paymentSourceAccountIds: Map<String, String>.from(
        existing.paymentSourceAccountIds,
      ),
      cardBillingAccountIds: Map<String, String>.from(
        existing.cardBillingAccountIds,
      ),
      cardStatementLines: _appendById(
        existing.cardStatementLines,
        patch.cardStatementLines,
      ),
      incomePlans: _appendById(existing.incomePlans, patch.incomePlans),
      transferTasks: List<AssetLiabilityTransferTask>.from(
        existing.transferTasks,
      ),
    );
  }

  AssetLiabilityMonthlyState _mergeStateOverwriteImportedFields(
    AssetLiabilityMonthlyState existing,
    AssetLiabilityMonthlyState patch,
  ) {
    return AssetLiabilityMonthlyState(
      paymentOverrides: patch.paymentOverrides.isEmpty
          ? Map<String, double>.from(existing.paymentOverrides)
          : Map<String, double>.from(patch.paymentOverrides),
      actualPaymentAmounts: patch.actualPaymentAmounts.isEmpty
          ? Map<String, double>.from(existing.actualPaymentAmounts)
          : Map<String, double>.from(patch.actualPaymentAmounts),
      paymentDifferenceReasons: patch.paymentDifferenceReasons.isEmpty
          ? Map<String, String>.from(existing.paymentDifferenceReasons)
          : Map<String, String>.from(patch.paymentDifferenceReasons),
      annualRateOverrides: Map<String, double>.from(
        existing.annualRateOverrides,
      ),
      annualRateEvidences: Map<String, AssetLiabilityAnnualRateEvidence>.from(
        existing.annualRateEvidences,
      ),
      paidAccountNames: patch.paidAccountNames.isEmpty
          ? Set<String>.from(existing.paidAccountNames)
          : Set<String>.from(patch.paidAccountNames),
      paymentSourceAccountIds: Map<String, String>.from(
        existing.paymentSourceAccountIds,
      ),
      cardBillingAccountIds: Map<String, String>.from(
        existing.cardBillingAccountIds,
      ),
      cardStatementLines: patch.cardStatementLines.isEmpty
          ? List<AssetLiabilityCardStatementLine>.from(
              existing.cardStatementLines,
            )
          : List<AssetLiabilityCardStatementLine>.from(
              patch.cardStatementLines,
            ),
      incomePlans: patch.incomePlans.isEmpty
          ? List<AssetLiabilityIncomePlan>.from(existing.incomePlans)
          : List<AssetLiabilityIncomePlan>.from(patch.incomePlans),
      transferTasks: List<AssetLiabilityTransferTask>.from(
        existing.transferTasks,
      ),
    );
  }

  Map<K, V> _appendMap<K, V>(Map<K, V> existing, Map<K, V> patch) {
    return <K, V>{...patch, ...existing};
  }

  List<T> _appendById<T extends Object>(List<T> existing, List<T> patch) {
    final result = <String, T>{};
    for (final item in patch) {
      result[_itemId(item)] = item;
    }
    for (final item in existing) {
      result[_itemId(item)] = item;
    }
    return result.values.toList(growable: false);
  }

  String _itemId(Object item) {
    if (item is AssetLiabilityIncomePlan) {
      return item.id;
    }
    if (item is AssetLiabilityCardStatementLine) {
      return item.id;
    }
    return item.hashCode.toString();
  }

  List<List<String>> _parseCsv(String rawText) {
    final rows = <List<String>>[];
    final currentRow = <String>[];
    final currentCell = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < rawText.length; i++) {
      final char = rawText[i];
      if (char == '"') {
        if (inQuotes && i + 1 < rawText.length && rawText[i + 1] == '"') {
          currentCell.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        currentRow.add(currentCell.toString().trim());
        currentCell.clear();
      } else if ((char == '\n' || char == '\r') && !inQuotes) {
        if (char == '\r' && i + 1 < rawText.length && rawText[i + 1] == '\n') {
          i++;
        }
        currentRow.add(currentCell.toString().trim());
        currentCell.clear();
        if (currentRow.any((cell) => cell.isNotEmpty)) {
          rows.add(List<String>.from(currentRow));
        }
        currentRow.clear();
      } else {
        currentCell.write(char);
      }
    }
    currentRow.add(currentCell.toString().trim());
    if (currentRow.any((cell) => cell.isNotEmpty)) {
      rows.add(List<String>.from(currentRow));
    }
    return rows;
  }

  int _indexOf(List<String> header, String name, {required int fallback}) {
    final index = header.indexOf(name);
    return index < 0 ? fallback : index;
  }

  AssetLiabilityCsvRestoreRejectedRow _rejected(
    AssetLiabilityCsvRestoreSection section,
    int rowNumber,
    List<String> row,
    String reason,
  ) {
    return AssetLiabilityCsvRestoreRejectedRow(
      section: section,
      rowNumber: rowNumber,
      rawText: row.map(_escapeCsvCell).join(','),
      reason: reason,
    );
  }

  String _cell(List<String> row, int index) {
    if (index < 0 || index >= row.length) {
      return '';
    }
    return row[index].trim();
  }

  bool _isMonthKey(String value) => RegExp(r'^\d{4}-\d{2}$').hasMatch(value);

  double? _parseDouble(String raw) {
    final normalized = raw
        .replaceAll(',', '')
        .replaceAll('\u00a5', '')
        .replaceAll('\u5186', '')
        .trim();
    if (normalized.isEmpty) {
      return null;
    }
    return double.tryParse(normalized);
  }

  int? _parseInt(String raw) {
    final normalized = raw.replaceAll(',', '').trim();
    if (normalized.isEmpty) {
      return null;
    }
    return int.tryParse(normalized);
  }

  bool _looksPaid(String raw) {
    final normalized = raw.toLowerCase().trim();
    if (normalized.isEmpty) {
      return false;
    }
    return normalized == 'true' ||
        normalized == 'yes' ||
        normalized == 'received' ||
        normalized == 'paid' ||
        normalized.contains('\u6e08') ||
        normalized.contains('\u8c82');
  }

  String? _emptyToNull(String raw) {
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String _stableId(String prefix, String monthKey, String name, int rowNumber) {
    final slug = '$prefix-$monthKey-$name-$rowNumber'
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return slug.isEmpty
        ? '${prefix}_${DateFormat('yyyyMMddHHmmss').format(DateTime(1970))}_$rowNumber'
        : slug;
  }

  String _escapeCsvCell(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}

class _MonthlyStatePatch {
  final String monthKey;
  final AssetLiabilityMonthlyState state;

  const _MonthlyStatePatch({required this.monthKey, required this.state});
}
