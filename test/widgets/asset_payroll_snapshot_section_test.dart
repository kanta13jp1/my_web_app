import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_payroll_snapshot_store.dart';
import 'package:my_web_app/widgets/asset_payroll_snapshot_section.dart';

class SyntheticSnapshotStore implements PayrollSnapshotStore {
  int writes = 0;
  bool failAfterCommit = false;
  PayrollSnapshotDraft? saved;

  @override
  Future<List<PayrollSnapshotAccount>> accounts() async =>
      [const PayrollSnapshotAccount('synthetic-account', '給与口座A')];
  @override
  Future<void> createAccount(String label) async {}
  @override
  Future<PayrollSnapshotRecord?> selected(
    String accountId,
    DateTime month,
  ) async =>
      month.month == 1 && saved != null ? _record() : null;
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

Future<void> showForm(WidgetTester tester, SyntheticSnapshotStore store, {double textScale = 1}) async {
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
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
  await tester.enterText(find.byType(TextFormField).at(0), '2020-01-25');
  await tester.enterText(find.byType(TextFormField).at(1), '120000');
  await tester.enterText(find.byType(TextFormField).at(2), '合成銀行明細の給与行を本人確認');
  await tester.ensureVisible(find.text('保存前の確認へ'));
  await tester.tap(find.text('保存前の確認へ'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('preview requires immediate-balance acknowledgement before save',
      (tester) async {
    final store = SyntheticSnapshotStore();
    await showForm(tester, store);
    expect(store.writes, 0);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '確認して保存'))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('確認して保存'));
    await tester.pumpAndSettle();
    expect(store.writes, 1);
    expect(store.saved!.toRpc()['p_date_precision'], 'day');
    expect(store.saved!.toRpc()['p_deposited_at'], isNull);
    expect(find.text('本人確認の直後残高：120000円'), findsOneWidget);
    expect(find.text('前月との差：比較対象未取得'), findsOneWidget);
  });

  testWidgets('lost response reconciles the same request without another write',
      (tester) async {
    final store = SyntheticSnapshotStore()..failAfterCommit = true;
    await showForm(tester, store);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('確認して保存'));
    await tester.pumpAndSettle();
    expect(store.writes, 1);
    expect(find.textContaining('保存結果が未確認'), findsOneWidget);
    await tester.ensureVisible(find.text('保存結果を照合'));
    await tester.tap(find.text('保存結果を照合'));
    await tester.pumpAndSettle();
    expect(store.writes, 1);
    expect(find.text('本人確認の直後残高：120000円'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
