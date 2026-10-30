import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:my_web_app/services/asset_payroll_snapshot_store.dart';
import 'payroll_snapshot_fixture.dart'
    show SyntheticSnapshotStore, showForm, showSnapshot;

class _DelayedSnapshotStore extends SyntheticSnapshotStore {
  final List<String> submittedRequests = [];
  final List<String> checkedRequests = [];
  PayrollSnapshotDraft? pendingCommit;
  PayrollSnapshotRecord? currentSelection;

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

  @override
  Future<PayrollSnapshotRecord?> selected(
    String accountId,
    DateTime month,
  ) async {
    if (accountId == 'synthetic-account' &&
        month.year == 2020 &&
        month.month == 1 &&
        currentSelection != null) {
      return currentSelection;
    }
    return super.selected(accountId, month);
  }

  void releaseCommit() {
    final draft = pendingCommit;
    if (draft == null) throw StateError('no synthetic commit pending');
    saved = draft;
    pendingCommit = null;
  }
}

Future<void> _tapVisible(WidgetTester tester, String label) async {
  final finder = find.text(label);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void _expectInputPreserved(WidgetTester tester) {
  expect(
    tester
        .widget<TextFormField>(find.byType(TextFormField).at(0))
        .controller!
        .text,
    '2020-01-25',
  );
  expect(
    tester
        .widget<TextFormField>(find.byType(TextFormField).at(1))
        .controller!
        .text,
    '120000',
  );
  expect(
    tester
        .widget<TextFormField>(find.byType(TextFormField).at(2))
        .controller!
        .text,
    '合成銀行明細の給与行を本人確認',
  );
}

Future<void> _submitUncertain(
  WidgetTester tester,
  _DelayedSnapshotStore store,
  double textScale,
) async {
  debugPrint('payroll-phase: form');
  await showForm(tester, store, textScale: textScale);
  await tester.ensureVisible(find.byType(CheckboxListTile));
  await tester.tap(find.byType(CheckboxListTile));
  await tester.pumpAndSettle();
  debugPrint('payroll-phase: submit');
  await _tapVisible(tester, '確認して保存');
  expect(store.writes, 1);
  expect(store.submittedRequests, hasLength(1));
  expect(find.textContaining('保存結果が未確認'), findsOneWidget);
  expect(tester.takeException(), isNull);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const mobile = bool.fromEnvironment('PAYROLL_MOBILE');
  testWidgets('explicit target save and unknown response never post a balance',
      (
    tester,
  ) async {
    debugPrint('payroll-phase: goal start');
    final store = SyntheticSnapshotStore()..failTargetAfterCommit = true;
    await showSnapshot(tester, store, textScale: mobile ? 2 : 1);
    // Let Japanese fallback fonts settle before editing an active text painter.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(seconds: 2));
    });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'initial goal layout');
    expect(find.text('前月比の増加目標：未設定'), findsOneWidget);
    final field = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.hintText == '例：10000',
    );
    await tester.enterText(field, '10000');
    expect(tester.takeException(), isNull, reason: 'goal input');
    await tester.ensureVisible(find.text('目標を保存・解除'));
    await tester.tap(find.text('目標を保存・解除'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'uncertain target response');
    expect(store.targetWrites, 1);
    expect(store.writes, 0);
    await tester.ensureVisible(find.text('目標の現在値を照合'));
    await tester.tap(find.text('目標の現在値を照合'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'target reconciliation');
    expect(find.text('前月比の増加目標：10000円'), findsOneWidget);
    expect(find.textContaining('今回の更新の成否は確定できません'), findsOneWidget);
    expect(store.targetWrites, 1);
    expect(store.writes, 0);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(seconds: 2));
    });
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('前月比の増加目標：10000円'));
    expect(tester.takeException(), isNull);
    debugPrint('payroll-phase: goal screenshot');
    await binding.takeScreenshot(
      mobile ? 'payroll-goal-mobile' : 'payroll-goal-desktop',
      {
        'width': tester.view.physicalSize.width / tester.view.devicePixelRatio,
        'height':
            tester.view.physicalSize.height / tester.view.devicePixelRatio,
        'devicePixelRatio': tester.view.devicePixelRatio,
      },
    );
  });
  testWidgets(
    'explicit preview and owner assertion save use synthetic storage only',
    (tester) async {
      debugPrint('payroll-phase: preview start');
      final store = SyntheticSnapshotStore();
      await showForm(tester, store, textScale: mobile ? 2 : 1);
      expect(store.writes, 0);
      expect(find.text('給与入金直後の残高を確認'), findsOneWidget);
      expect(tester.takeException(), isNull);
      // CanvasKit can settle before asynchronous Japanese fallback fonts arrive.
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(seconds: 2));
      });
      await tester.pumpAndSettle();
      debugPrint('payroll-phase: preview screenshot');
      await binding.takeScreenshot(
        mobile
            ? 'payroll-snapshot-preview-mobile'
            : 'payroll-snapshot-preview-desktop',
        {
          'width':
              tester.view.physicalSize.width / tester.view.devicePixelRatio,
          'height':
              tester.view.physicalSize.height / tester.view.devicePixelRatio,
          'devicePixelRatio': tester.view.devicePixelRatio,
        },
      );
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text('確認して保存'));
      await tester.pumpAndSettle();
      expect(store.writes, 1);
      expect(find.text('本人確認の直後残高：120000円'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'late commit remains locked and reconciles the same request',
    (
      tester,
    ) async {
      debugPrint('payroll-phase: late start');
      final store = _DelayedSnapshotStore();
      await _submitUncertain(tester, store, mobile ? 2 : 1);
      final request = store.submittedRequests.single;
      _expectInputPreserved(tester);

      debugPrint('payroll-phase: reconcile');
      await _tapVisible(tester, '保存結果を照合');
      expect(store.saved, isNull);
      expect(store.checkedRequests, [request]);
      expect(find.textContaining('保存結果はまだ確認できません'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, '再読込'))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '保存前の確認へ'))
            .onPressed,
        isNull,
      );
      _expectInputPreserved(tester);
      expect(store.writes, 1);
      expect(tester.takeException(), isNull);

      debugPrint('payroll-phase: commit');
      store.releaseCommit();
      debugPrint('payroll-phase: late reconcile after commit');
      await _tapVisible(tester, '保存結果を照合');
      expect(store.checkedRequests, [request, request]);
      expect(store.submittedRequests, [request]);
      expect(store.writes, 1);
      expect(find.text('本人確認の直後残高：120000円'), findsOneWidget);
      expect(tester.takeException(), isNull);
      debugPrint('payroll-phase: late done');
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  testWidgets(
    'a changed selection requires explicit acknowledgement',
    (
      tester,
    ) async {
      debugPrint('payroll-phase: selection start');
      final store = _DelayedSnapshotStore();
      await _submitUncertain(tester, store, mobile ? 2 : 1);
      final request = store.submittedRequests.single;
      debugPrint('payroll-phase: selection commit');
      store.releaseCommit();
      store.currentSelection = PayrollSnapshotRecord(
        id: 'synthetic-correction',
        ownerId: store.ownerId,
        accountId: 'synthetic-account',
        month: DateTime(2020),
        balanceYen: 130000,
        depositDate: DateTime(2020, 1, 25),
        note: 'synthetic correction',
      );

      debugPrint('payroll-phase: selection reconcile');
      await _tapVisible(tester, '保存結果を照合');
      expect(store.checkedRequests, [request]);
      expect(find.textContaining('照合時点の選択は別の記録'), findsOneWidget);
      expect(find.text('本人確認の直後残高：130000円'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '保存前の確認へ'))
            .onPressed,
        isNull,
      );
      _expectInputPreserved(tester);
      expect(store.writes, 1);
      expect(tester.takeException(), isNull);
      debugPrint('payroll-phase: acknowledge');
      await _tapVisible(tester, '現在の選択を確認して保留解除');
      expect(find.text('保存結果を照合'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '保存前の確認へ'))
            .onPressed,
        isNotNull,
      );
      expect(store.submittedRequests, [request]);
      expect(store.writes, 1);
      expect(tester.takeException(), isNull);
      debugPrint('payroll-phase: selection done');
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
