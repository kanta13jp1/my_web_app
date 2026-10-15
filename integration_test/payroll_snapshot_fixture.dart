import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_payroll_snapshot_store.dart';
import 'package:my_web_app/widgets/asset_payroll_snapshot_section.dart';

class SyntheticSnapshotStore implements PayrollSnapshotStore {
  int writes = 0;
  bool failAfterCommit = false;
  bool failReads = false;
  PayrollSnapshotDraft? saved;

  @override
  Future<List<PayrollSnapshotAccount>> accounts() async =>
      [const PayrollSnapshotAccount('synthetic-account', '給与口座A')];
  @override
  Future<void> createAccount(String label) async {}
  @override
  Future<PayrollSnapshotRecord?> selected(String accountId, DateTime month) async {
    if (failReads) throw StateError('synthetic unavailable');
    return month.month == 1 && saved != null ? _record() : null;
  }
  PayrollSnapshotRecord _record() => PayrollSnapshotRecord(
        id: 'synthetic-observation',
        balanceYen: saved!.balanceYen,
        depositDate: saved!.depositDate,
        note: saved!.note,
      );
  @override
  Future<PayrollSnapshotRecord?> byRequest(PayrollSnapshotDraft draft) async =>
      saved?.requestId == draft.requestId ? _record() : null;
  @override
  Future<void> confirm(PayrollSnapshotDraft draft) async {
    writes++;
    saved = draft;
    if (failAfterCommit) throw StateError('synthetic response lost');
  }
}

Future<void> showSnapshot(
  WidgetTester tester,
  SyntheticSnapshotStore store, {
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          child: AssetPayrollSnapshotSection(
            store: store,
            initialMonth: DateTime(2020),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> showForm(
  WidgetTester tester,
  SyntheticSnapshotStore store, {
  double textScale = 1,
}) async {
  await showSnapshot(tester, store, textScale: textScale);
  await tester.enterText(find.byType(TextFormField).at(0), '2020-01-25');
  await tester.enterText(find.byType(TextFormField).at(1), '120000');
  await tester.enterText(find.byType(TextFormField).at(2), '合成銀行明細の給与行を本人確認');
  await tester.ensureVisible(find.text('保存前の確認へ'));
  await tester.tap(find.text('保存前の確認へ'));
  await tester.pumpAndSettle();
}
