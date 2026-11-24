import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_payroll_snapshot_store.dart';

import '../../integration_test/payroll_snapshot_fixture.dart';

class _CorrectedSelectionStore extends SyntheticSnapshotStore {
  PayrollSnapshotRecord? currentSelection;
  bool failCurrentSelection = false;

  @override
  Future<PayrollSnapshotRecord?> selected(
    String accountId,
    DateTime month,
  ) async {
    if (month.year == 2020 && month.month == 1) {
      if (failCurrentSelection) {
        throw StateError('synthetic selection read failed');
      }
      if (currentSelection != null) return currentSelection;
    }
    return super.selected(accountId, month);
  }
}

PayrollSnapshotRecord _selection(
  _CorrectedSelectionStore store,
  String id,
  int balance,
) =>
    PayrollSnapshotRecord(
      id: id,
      ownerId: store.ownerId,
      accountId: 'synthetic-account',
      month: DateTime(2020),
      balanceYen: balance,
      depositDate: DateTime(2020, 1, 25),
      note: 'synthetic correction',
    );

Future<void> _submitWithLostResponse(
  WidgetTester tester,
  _CorrectedSelectionStore store,
) async {
  store.failAfterCommit = true;
  await showForm(tester, store);
  await tester.tap(find.byType(CheckboxListTile));
  await tester.pumpAndSettle();
  await tester.tap(find.text('確認して保存'));
  await tester.pumpAndSettle();
  expect(store.writes, 1);
  expect(find.textContaining('保存結果が未確認'), findsOneWidget);
}

Future<void> _tapVisible(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'a corrected selection stays locked until explicitly acknowledged',
    (tester) async {
      final store = _CorrectedSelectionStore();
      await _submitWithLostResponse(tester, store);
      store.currentSelection = _selection(store, 'synthetic-b', 130000);

      await _tapVisible(tester, '保存結果を照合');

      expect(find.textContaining('照合時点の選択は別の記録'), findsOneWidget);
      expect(find.text('本人確認の直後残高：130000円'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '保存前の確認へ'))
            .onPressed,
        isNull,
      );
      expect(store.writes, 1);

      // Another correction arrives before the user acknowledges B.
      store.currentSelection = _selection(store, 'synthetic-c', 140000);
      await _tapVisible(tester, '現在の選択を確認して保留解除');

      expect(find.text('本人確認の直後残高：140000円'), findsOneWidget);
      expect(find.textContaining('照合時点の選択は別の記録'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '保存前の確認へ'))
            .onPressed,
        isNull,
      );
      expect(store.writes, 1);

      await _tapVisible(tester, '現在の選択を確認して保留解除');
      expect(find.text('保存結果を照合'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '保存前の確認へ'))
            .onPressed,
        isNotNull,
      );
      expect(store.writes, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('selection read failure keeps the request pending',
      (tester) async {
    final store = _CorrectedSelectionStore();
    await _submitWithLostResponse(tester, store);
    store.failCurrentSelection = true;

    await _tapVisible(tester, '保存結果を照合');

    expect(find.textContaining('現在の選択を確認できません'), findsOneWidget);
    expect(find.text('保存結果を照合'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '再読込'))
          .onPressed,
      isNull,
    );
    expect(store.writes, 1);

    store.failCurrentSelection = false;
    store.currentSelection = _selection(store, 'synthetic-b', 130000);
    await _tapVisible(tester, '保存結果を照合');
    expect(find.textContaining('照合時点の選択は別の記録'), findsOneWidget);
    expect(store.writes, 1);
    expect(tester.takeException(), isNull);
  });
}
