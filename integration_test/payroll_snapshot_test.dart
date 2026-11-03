import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:my_web_app/services/asset_payroll_snapshot_store.dart';
import 'package:my_web_app/widgets/asset_payroll_snapshot_connection.dart';
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

class _OtherOwnerStore extends SyntheticSnapshotStore {
  @override
  String get ownerId => 'synthetic-owner-b';

  @override
  Future<List<PayrollSnapshotAccount>> accounts() async => [
        const PayrollSnapshotAccount('synthetic-account-b', '給与口座B'),
      ];
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
  final confirmationReference =
      find.byKey(const ValueKey('payroll-confirmation-reference'));
  await tester.ensureVisible(confirmationReference);
  await tester.pumpAndSettle();
  expect(confirmationReference.hitTestable(), findsOneWidget);
  final reference = tester
      .widget<SelectableText>(
        find.byKey(const ValueKey('payroll-confirmation-reference')),
      )
      .data!;
  await tester.ensureVisible(find.byType(CheckboxListTile));
  await tester.tap(find.byType(CheckboxListTile));
  await tester.pumpAndSettle();
  debugPrint('payroll-phase: submit');
  await _tapVisible(tester, '確認して保存');
  expect(store.writes, 1);
  expect(store.submittedRequests, hasLength(1));
  expect(store.submittedRequests.single, reference);
  expect(find.textContaining('保存結果が未確認'), findsOneWidget);
  final pendingReference =
      find.byKey(const ValueKey('payroll-pending-reference'));
  await tester.ensureVisible(pendingReference);
  await tester.pumpAndSettle();
  expect(pendingReference.hitTestable(), findsOneWidget);
  expect(
    tester
        .widget<SelectableText>(
          find.byKey(const ValueKey('payroll-pending-reference')),
        )
        .data,
    reference,
  );
  final notice = find.textContaining('再開後に自動照合できません');
  await tester.ensureVisible(notice);
  await tester.pumpAndSettle();
  expect(notice.hitTestable(), findsOneWidget);
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
      final confirmationReference =
          find.byKey(const ValueKey('payroll-confirmation-reference'));
      await tester.ensureVisible(confirmationReference);
      await tester.pumpAndSettle();
      expect(confirmationReference.hitTestable(), findsOneWidget);
      final unavailableNotice = find.textContaining('アプリに再入力できず');
      await tester.ensureVisible(unavailableNotice);
      await tester.pumpAndSettle();
      expect(unavailableNotice.hitTestable(), findsOneWidget);
      final reference = tester
          .widget<SelectableText>(
            find.byKey(const ValueKey('payroll-confirmation-reference')),
          )
          .data!;
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '確認して保存'))
            .onPressed,
        isNull,
      );
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
      expect(store.saved?.requestId, reference);
      expect(find.text('本人確認の直後残高：120000円'), findsOneWidget);
      final notice = find.textContaining('再開後に自動照合できません');
      await tester.ensureVisible(notice);
      await tester.pumpAndSettle();
      expect(notice.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'uncertain save shows the warning after screen recreation',
    (tester) async {
      final store = _DelayedSnapshotStore();
      await _submitUncertain(tester, store, mobile ? 2 : 1);
      await tester.pumpWidget(const SizedBox());
      await showSnapshot(tester, store, textScale: mobile ? 2 : 1);
      final notice = find.textContaining('再開後に自動照合できません');
      await tester.ensureVisible(notice);
      await tester.pumpAndSettle();
      expect(notice.hitTestable(), findsOneWidget);
      expect(
        find.textContaining('表示されなくても保存中または保存済みの可能性'),
        findsOneWidget,
      );
      expect(find.text('保存結果を照合'), findsNothing);
      expect(store.checkedRequests, isEmpty);
      expect(store.saved, isNull);
      expect(store.writes, 1);
      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 2)),
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

  testWidgets(
    'owner change hides a pending confirmation without saving',
    (tester) async {
      final owner = ValueNotifier<String?>('synthetic-owner');
      addTearDown(owner.dispose);
      final storeA = SyntheticSnapshotStore();
      final storeB = _OtherOwnerStore();
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(mobile ? 2 : 1),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ValueListenableBuilder<String?>(
                valueListenable: owner,
                builder: (context, value, _) => AssetPayrollSnapshotConnection(
                  ownerId: value,
                  initialMonth: DateTime(2020),
                  createStore: (id) =>
                      id == 'synthetic-owner' ? storeA : storeB,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), '2020-01-25');
      await tester.enterText(find.byType(TextFormField).at(1), '120000');
      await tester.enterText(find.byType(TextFormField).at(2), '架空の資料');
      await _tapVisible(tester, '保存前の確認へ');
      expect(find.text('入金直後残高：120000円'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('payroll-confirmation-reference')),
        findsOneWidget,
      );
      owner.value = storeB.ownerId;
      await tester.pump();
      expect(
        find.byKey(
          const ValueKey('payroll-confirmed-snapshot-synthetic-owner-b'),
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('payroll-confirmed-snapshot-synthetic-owner'),
          skipOffstage: false,
        ),
        findsNothing,
      );
      expect(find.text('入金直後残高：120000円', skipOffstage: false), findsNothing);
      expect(
        find.byKey(
          const ValueKey('payroll-confirmation-reference'),
          skipOffstage: false,
        ),
        findsNothing,
      );
      await tester.pumpAndSettle();
      final ownerBLabel = find.text('給与口座B');
      await tester.ensureVisible(ownerBLabel);
      await tester.pumpAndSettle();
      expect(ownerBLabel.hitTestable(), findsOneWidget);
      expect(storeA.writes, 0);
      expect(storeB.writes, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
