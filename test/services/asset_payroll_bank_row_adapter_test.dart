import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/smbc_csv_import_service.dart';
import 'package:my_web_app/services/asset_payroll_bank_row_adapter.dart';

void main() {
  const header = '年月日,お引出し,お預入れ,お取り扱い内容,残高\n';

  test('balance remains signed without changing withdrawal absolute semantics',
      () {
    final rows = const SmbcCsvImportService()
        .parse(
          '${header}2030/2/20,-80,,ATM,-300\n',
        )
        .transactions;
    expect(rows.single.amount, 80);
    expect(rows.single.balance, -300);
    expect(PayrollBankRowCandidate.fromTransaction(rows.single), isNull);
  });
  test('invalid date is skipped instead of silently becoming March', () {
    final result = const SmbcCsvImportService().parse(
      '${header}2030/2/31,,800,給与,400\n',
    );
    expect(result.transactions, isEmpty);
    expect(result.skippedRows, 1);
  });
  test('row balance is retained even when a later withdrawal changed balance',
      () {
    final rows = const SmbcCsvImportService()
        .parse(
          '${header}2030/2/20,,800,給与,500\n2030/2/21,100,,ATM,400\n',
        )
        .transactions;
    final candidate = PayrollBankRowCandidate.fromTransaction(rows.first)!;
    expect(candidate.immediateBalanceYen, 500);
    expect(candidate.datePrecision, PayrollDepositDatePrecision.day);
    expect(candidate.hasPayrollLabel, isTrue);
    expect(
        AssetPayrollBankRowAdapter.confirm(
          ownerId: 'owner-a',
          accountId: 'account-a',
          payrollMonth: DateTime(2030, 2),
          sourceImportReference: 'synthetic-import',
          candidate: candidate,
          ownerConfirmedPayrollAndImmediateBalance: false,
        ),
        isNull,
    );
  });
  test(
      'explicit confirmation binds owner/account/month/source without new flow',
      () {
    final rows = const SmbcCsvImportService()
        .parse(
          '${header}2030/2/20,,800,給与,500\n',
        )
        .transactions;
    final candidate = PayrollBankRowCandidate.fromTransaction(rows.single)!;
    final confirmation = AssetPayrollBankRowAdapter.confirm(
      ownerId: 'owner-a',
      accountId: 'account-a',
      payrollMonth: DateTime(2030, 2),
      sourceImportReference: 'synthetic-import',
      candidate: candidate,
      ownerConfirmedPayrollAndImmediateBalance: true,
    )!;
    expect(confirmation.ownerId, 'owner-a');
    expect(confirmation.accountId, 'account-a');
    expect(confirmation.candidate.immediateBalanceYen, 500);
    expect(rows, hasLength(1));
  });
  test('missing balance cannot become a snapshot; explicit zero can', () {
    final rows = const SmbcCsvImportService()
        .parse(
          '${header}2030/2/20,,800,給与,\n2030/2/21,,800,給与,0\n',
        )
        .transactions;
    expect(PayrollBankRowCandidate.fromTransaction(rows.first), isNull);
    expect(
        PayrollBankRowCandidate.fromTransaction(rows.last)!.immediateBalanceYen,
        0,
    );
  });
  test('payroll label is only a hint and stable row keys survive repeat parse',
      () {
    const csv = '${header}2030/2/20,,800,振込,500\n';
    final first = const SmbcCsvImportService().parse(csv).transactions.single;
    final repeated =
        const SmbcCsvImportService().parse(csv).transactions.single;
    final candidate = PayrollBankRowCandidate.fromTransaction(first)!;
    expect(candidate.hasPayrollLabel, isFalse);
    expect(first.importKey, repeated.importKey);
  });
}
