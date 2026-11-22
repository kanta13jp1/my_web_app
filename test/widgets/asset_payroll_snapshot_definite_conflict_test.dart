import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_payroll_snapshot_store.dart';

import '../../integration_test/payroll_snapshot_fixture.dart';

class _RejectedConflictStore extends SyntheticSnapshotStore {
  bool failRefresh = false;
  bool replaceAccountAfterConflict = false;

  @override
  Future<List<PayrollSnapshotAccount>> accounts() async {
    if (writes > 0 && replaceAccountAfterConflict) {
      return [const PayrollSnapshotAccount('synthetic-other', '別の合成口座')];
    }
    return super.accounts();
  }

  @override
  Future<void> confirm(PayrollSnapshotDraft draft) async {
    writes++;
    throw const PayrollSnapshotConflict();
  }

  @override
  Future<PayrollSnapshotRecord?> selected(
    String accountId,
    DateTime month,
  ) async {
    if (writes > 0 && failRefresh) {
      throw StateError('synthetic refresh failure');
    }
    if (writes > 0 && month.year == 2020 && month.month == 1) {
      return PayrollSnapshotRecord(
        id: 'synthetic-current-b',
        ownerId: ownerId,
        accountId: accountId,
        month: DateTime(2020),
        balanceYen: 130000,
        depositDate: DateTime(2020, 1, 25),
        note: 'synthetic current record',
      );
    }
    return super.selected(accountId, month);
  }
}

Future<void> _submit(WidgetTester tester, _RejectedConflictStore store) async {
  await showForm(tester, store);
  await tester.tap(find.byType(CheckboxListTile));
  await tester.pumpAndSettle();
  await tester.tap(find.text('確認して保存'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a definite conflict reloads selection and retains input',
      (tester) async {
    final store = _RejectedConflictStore();
    await _submit(tester, store);

    expect(find.textContaining('競合により今回の記録は保存されませんでした'), findsOneWidget);
    expect(find.text('本人確認の直後残高：130000円'), findsOneWidget);
    expect(find.text('保存結果を照合'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '保存前の確認へ'))
          .onPressed,
      isNotNull,
    );
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).at(1))
          .controller!
          .text,
      '120000',
    );
    expect(store.writes, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a missing conflict account never switches to another account',
      (tester) async {
    final store = _RejectedConflictStore()..replaceAccountAfterConflict = true;
    await _submit(tester, store);

    expect(find.textContaining('現在の選択を取得できません'), findsOneWidget);
    expect(find.text('保存前の確認へ'), findsNothing);
    await tester.ensureVisible(find.text('再読込'));
    await tester.tap(find.text('再読込'));
    await tester.pumpAndSettle();
    expect(find.textContaining('対象の給与口座を確認できません'), findsOneWidget);
    expect(find.text('保存前の確認へ'), findsNothing);
    expect(store.writes, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed refresh stays locked until reloaded', (tester) async {
    final store = _RejectedConflictStore()..failRefresh = true;
    await _submit(tester, store);

    expect(find.textContaining('現在の選択を取得できません'), findsOneWidget);
    expect(find.text('保存前の確認へ'), findsNothing);
    expect(find.text('保存結果を照合'), findsNothing);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '再読込'))
          .onPressed,
      isNotNull,
    );
    expect(store.writes, 1);

    store.failRefresh = false;
    await tester.ensureVisible(find.text('再読込'));
    await tester.tap(find.text('再読込'));
    await tester.pumpAndSettle();
    expect(find.text('本人確認の直後残高：130000円'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '保存前の確認へ'))
          .onPressed,
      isNotNull,
    );
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).at(1))
          .controller!
          .text,
      '120000',
    );
    expect(store.writes, 1);
    expect(tester.takeException(), isNull);
  });
}
