import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/asset_payroll_snapshot_connection.dart';
import '../../integration_test/payroll_snapshot_fixture.dart';

void main() {
  testWidgets('signed out page connection never constructs a store',
      (tester) async {
    var created = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AssetPayrollSnapshotConnection(
          ownerId: null,
          initialMonth: DateTime(2030, 1),
          createStore: (_) {
            created++;
            throw StateError('No store may be created while signed out');
          },
        ),
      ),
    );
    await tester.pump();
    expect(created, 0);
    expect(find.text('給与入金直後の残高を記録するにはログインしてください。'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('owner change discards the previous owners unsaved input',
      (tester) async {
    final stores = <String, SyntheticSnapshotStore>{};
    Future<void> open(String owner) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AssetPayrollSnapshotConnection(
                ownerId: owner,
                initialMonth: DateTime(2020),
                createStore: (id) =>
                    stores.putIfAbsent(id, SyntheticSnapshotStore.new),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await open('owner-a');
    await tester.enterText(
      find.byType(TextFormField).at(2),
      'owner-a private draft',
    );
    await open('owner-b');
    expect(find.text('owner-a private draft'), findsNothing);
    expect(stores.keys, containsAll(['owner-a', 'owner-b']));
    expect(stores.values.every((store) => store.writes == 0), isTrue);
  });

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
  testWidgets(
      'recreating after uncertain save reloads selection without another write',
      (tester) async {
    final store = SyntheticSnapshotStore()..failAfterCommit = true;
    await showForm(tester, store);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('確認して保存'));
    await tester.pumpAndSettle();
    expect(store.writes, 1);
    await tester.pumpWidget(const SizedBox());
    await showSnapshot(tester, store);
    expect(find.text('本人確認の直後残高：120000円'), findsOneWidget);
    expect(find.text('訂正理由（旧記録は履歴に残ります）'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).at(1))
          .controller!
          .text,
      isEmpty,
    );
    expect(store.writes, 1);
  });
  testWidgets('month load failure clears old values and disables saving',
      (tester) async {
    final store = SyntheticSnapshotStore();
    await showSnapshot(tester, store);
    store.failReads = true;
    await tester.tap(find.text('翌月'));
    await tester.pumpAndSettle();
    expect(find.text('取得できませんでした。再読込してください。'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '保存前の確認へ'))
          .onPressed,
      isNull,
    );
    expect(store.writes, 0);
    expect(tester.takeException(), isNull);
  });
}
