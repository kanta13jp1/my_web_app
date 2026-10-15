import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../integration_test/payroll_snapshot_fixture.dart';

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
