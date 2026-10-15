import 'smbc_csv_import_service.dart';

enum PayrollDepositDatePrecision { day }

/// A row balance attached to an imported deposit, not a current/latest balance.
/// Importing a bank CSV is not proof of payroll until the owner confirms it.
class PayrollBankRowCandidate {
  const PayrollBankRowCandidate._(this.transaction);
  final SmbcCsvTransaction transaction;
  int get immediateBalanceYen => transaction.balance!;
  DateTime get depositDate => transaction.date;
  PayrollDepositDatePrecision get datePrecision =>
      PayrollDepositDatePrecision.day;

  /// Discovery hint only. Never used to set a confirmed state automatically.
  bool get hasPayrollLabel => RegExp(r'給与|給料|salary', caseSensitive: false)
      .hasMatch(transaction.content);

  static PayrollBankRowCandidate? fromTransaction(SmbcCsvTransaction row) {
    if (!row.isDeposit || row.amount <= 0 || row.balance == null) return null;
    return PayrollBankRowCandidate._(row);
  }
}

class OwnerConfirmedPayrollBankRow {
  const OwnerConfirmedPayrollBankRow._({
    required this.ownerId,
    required this.accountId,
    required this.payrollMonth,
    required this.sourceImportReference,
    required this.candidate,
  });

  final String ownerId;
  final String accountId;
  final DateTime payrollMonth;

  /// Reference to the owner's already-authorized import; no raw CSV is copied.
  final String sourceImportReference;
  final PayrollBankRowCandidate candidate;

  /// Import keys assist lookup, but their short hash is not globally unique.
  /// Storage must additionally bind source import, row, owner and account.
  String get rowImportKey => candidate.transaction.importKey;
}

class AssetPayrollBankRowAdapter {
  const AssetPayrollBankRowAdapter._();

  /// Does not save, post income, alter current balances or claim an exact time.
  static OwnerConfirmedPayrollBankRow? confirm({
    required String ownerId,
    required String accountId,
    required DateTime payrollMonth,
    required String sourceImportReference,
    required PayrollBankRowCandidate candidate,
    required bool ownerConfirmedPayrollAndImmediateBalance,
  }) {
    if (!ownerConfirmedPayrollAndImmediateBalance) return null;
    if (ownerId.trim().isEmpty ||
        accountId.trim().isEmpty ||
        sourceImportReference.trim().isEmpty ||
        candidate.transaction.importKey.trim().isEmpty) {
      throw ArgumentError(
          'Owner, account, source import and row are required.',
      );
    }
    return OwnerConfirmedPayrollBankRow._(
      ownerId: ownerId,
      accountId: accountId,
      payrollMonth: DateTime(payrollMonth.year, payrollMonth.month),
      sourceImportReference: sourceImportReference,
      candidate: candidate,
    );
  }
}
