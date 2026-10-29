import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_payroll_snapshot_store.dart';

import '../../integration_test/payroll_snapshot_fixture.dart';

/// Simulates a lost response while the server transaction is still pending.
class _DelayedCommitStore extends SyntheticSnapshotStore {
  final List<String> submittedRequests = [];
  final List<String> checkedRequests = [];
  PayrollSnapshotDraft? pendingCommit;

  @override
  Future<void> confirm(PayrollSnapshotDraft draft) async {
    writes++;
    submittedRequests.add(draft.requestId);
    pendingCommit = draft;
    throw TimeoutException('synthetic response lost before commit');
  }

  @override
  Future<PayrollSnapshotRecord?> byRequest(PayrollSnapshotDraft draft) async {
    checkedRequests.add(draft.requestId);
    return super.byRequest(draft);
  }

  void releaseCommit() {
    final draft = pendingCommit;
    if (draft == null) throw StateError('no synthetic commit pending');
    saved = draft;
    pendingCommit = null;
  }
}

void main() {
  testWidgets(
    'an absent reconciliation keeps the request locked until a delayed commit',
    (tester) async {
      final store = _DelayedCommitStore();

      debugPrint('payroll-late-phase: form');
      await showForm(tester, store);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text('確認して保存'));
      await tester.pumpAndSettle();

      expect(store.submittedRequests, hasLength(1));
      final originalRequest = store.submittedRequests.single;
      expect(store.saved, isNull);
      expect(find.textContaining('保存結果が未確認'), findsOneWidget);

      debugPrint('payroll-late-phase: reconcile');
      await tester.ensureVisible(find.text('保存結果を照合'));
      await tester.tap(find.text('保存結果を照合'));
      await tester.pumpAndSettle();

      expect(store.checkedRequests, [originalRequest]);
      expect(store.saved, isNull);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, '再読込'))
            .onPressed,
        isNull,
        reason: 'A read before commit cannot prove that the request failed.',
      );
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '保存前の確認へ'))
            .onPressed,
        isNull,
      );
      expect(store.submittedRequests, [originalRequest]);

      debugPrint('payroll-late-phase: commit');
      store.releaseCommit();
      await tester.ensureVisible(find.text('保存結果を照合'));
      await tester.tap(find.text('保存結果を照合'));
      await tester.pumpAndSettle();

      expect(store.checkedRequests, [originalRequest, originalRequest]);
      expect(store.submittedRequests, [originalRequest]);
      expect(store.writes, 1);
      expect(find.text('本人確認の直後残高：120000円'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
