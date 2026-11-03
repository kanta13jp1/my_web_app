import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_payroll_snapshot_store.dart';
import 'package:my_web_app/widgets/asset_payroll_snapshot_connection.dart';

import '../../integration_test/payroll_snapshot_fixture.dart';

class _UnknownStore extends SyntheticSnapshotStore {
  PayrollSnapshotDraft? attempted;

  @override
  Future<void> confirm(PayrollSnapshotDraft draft) async {
    writes++;
    attempted = draft;
    throw TimeoutException('synthetic response lost');
  }
}

class _OtherOwnerStore extends SyntheticSnapshotStore {
  @override
  String get ownerId => 'synthetic-other-owner';
}

void main() {
  testWidgets(
    'same reference is visible before saving and while result is unknown',
    (tester) async {
      final store = _UnknownStore();
      await showForm(tester, store);
      final preSave = find.byKey(
        const ValueKey('payroll-confirmation-reference'),
      );
      await tester.ensureVisible(preSave);
      final reference = tester.widget<SelectableText>(preSave).data!;
      expect(
        reference,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
      expect(find.textContaining('アプリに再入力できず'), findsOneWidget);

      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text('確認して保存'));
      await tester.pumpAndSettle();

      expect(store.writes, 1);
      expect(store.attempted?.requestId, reference);
      final pending = find.byKey(const ValueKey('payroll-pending-reference'));
      expect(tester.widget<SelectableText>(pending).data, reference);
      expect(find.textContaining('保存結果が未確認'), findsOneWidget);
      expect(find.textContaining('アプリに再入力できず'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
      'a recreated screen for another owner does not restore the reference', (
    tester,
  ) async {
    final store = _UnknownStore();
    final other = _OtherOwnerStore();
    Future<void> showOwner(String owner) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AssetPayrollSnapshotConnection(
                ownerId: owner,
                initialMonth: DateTime(2020),
                createStore: (id) => id == 'synthetic-owner' ? store : other,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await showOwner('synthetic-owner');
    await tester.enterText(find.byType(TextFormField).at(0), '2020-01-25');
    await tester.enterText(find.byType(TextFormField).at(1), '120000');
    await tester.enterText(find.byType(TextFormField).at(2), '合成銀行明細の給与行を本人確認');
    await tester.ensureVisible(find.text('保存前の確認へ'));
    await tester.tap(find.text('保存前の確認へ'));
    await tester.pumpAndSettle();
    final reference = tester
        .widget<SelectableText>(
          find.byKey(const ValueKey('payroll-confirmation-reference')),
        )
        .data!;
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('確認して保存'));
    await tester.pumpAndSettle();
    await showOwner('synthetic-other-owner');

    expect(
      find.byKey(const ValueKey('payroll-pending-reference')),
      findsNothing,
    );
    expect(find.text(reference), findsNothing);
    expect(find.textContaining('再開後に自動照合できません'), findsOneWidget);
    expect(store.writes, 1);
    expect(tester.takeException(), isNull);
  });
}
