import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_payroll_snapshot_store.dart';
import 'package:my_web_app/widgets/asset_payroll_snapshot_connection.dart';

import '../../integration_test/payroll_snapshot_fixture.dart';

class _OwnerB extends SyntheticSnapshotStore {
  @override
  String get ownerId => 'synthetic-owner-b';
}

class _DelayedStore extends SyntheticSnapshotStore {
  final release = Completer<void>();
  @override
  Future<void> confirm(PayrollSnapshotDraft draft) async {
    writes++;
    await release.future;
    saved = draft;
  }
}

class _DelayedReloadStore extends SyntheticSnapshotStore {
  bool hold = false;
  final release = Completer<void>();
  @override
  Future<List<PayrollSnapshotAccount>> accounts() async {
    if (hold) {
      await release.future;
    }
    return super.accounts();
  }
}

Future<void> _openReview(
  WidgetTester tester,
  ValueNotifier<String?> owner,
  SyntheticSnapshotStore storeA,
  SyntheticSnapshotStore storeB, {
  GlobalKey<NavigatorState>? navigatorKey,
  double textScale = 1,
  VoidCallback? onExternalTap,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigatorKey,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        floatingActionButton: onExternalTap == null
            ? null
            : FloatingActionButton(
                onPressed: onExternalTap,
                child: const Text('別操作'),
              ),
        body: SingleChildScrollView(
          child: ValueListenableBuilder<String?>(
            valueListenable: owner,
            builder: (context, value, _) => AssetPayrollSnapshotConnection(
              ownerId: value,
              initialMonth: DateTime(2020),
              createStore: (id) => id == 'synthetic-owner' ? storeA : storeB,
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
  await tester.ensureVisible(find.text('保存前の確認へ'));
  await tester.tap(find.text('保存前の確認へ'));
  await tester.pumpAndSettle();
  expect(find.text('入金直後残高：120000円'), findsOneWidget);
}

void main() {
  testWidgets('an in-flight reload disables entry to confirmation',
      (tester) async {
    final store = _DelayedReloadStore();
    await showSnapshot(tester, store);
    store.hold = true;
    await tester.tap(find.text('再読込'));
    await tester.pump();
    final save = find.widgetWithText(FilledButton, '保存前の確認へ');
    expect(save, findsNothing);
    expect(find.text('給与入金直後の残高を確認'), findsNothing);
    store.release.complete();
    await tester.pumpAndSettle();
    expect(save, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('owner switch removes review content on first and next frames',
      (tester) async {
    final owner = ValueNotifier<String?>('synthetic-owner');
    addTearDown(owner.dispose);
    final a = SyntheticSnapshotStore();
    final b = _OwnerB();
    await _openReview(tester, owner, a, b);
    owner.value = b.ownerId;
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
    await tester.pump();
    expect(find.text('確認資料メモ：架空の資料', skipOffstage: false), findsNothing);
    expect(a.writes, 0);
    expect(b.writes, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('owner switch does not close an unrelated dialog',
      (tester) async {
    final owner = ValueNotifier<String?>('synthetic-owner');
    addTearDown(owner.dispose);
    final navigator = GlobalKey<NavigatorState>();
    final a = SyntheticSnapshotStore();
    final b = _OwnerB();
    await _openReview(tester, owner, a, b, navigatorKey: navigator);
    unawaited(
      showDialog<void>(
        context: navigator.currentContext!,
        builder: (_) => const AlertDialog(title: Text('無関係の画面')),
      ),
    );
    await tester.pumpAndSettle();
    owner.value = b.ownerId;
    await tester.pump();
    expect(find.text('無関係の画面'), findsOneWidget);
    expect(find.text('入金直後残高：120000円', skipOffstage: false), findsNothing);
    expect(a.writes + b.writes, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opening review does not steal focus from a later route',
      (tester) async {
    final store = SyntheticSnapshotStore();
    await showSnapshot(tester, store);
    await tester.enterText(find.byType(TextFormField).at(0), '2020-01-25');
    await tester.enterText(find.byType(TextFormField).at(1), '120000');
    await tester.enterText(find.byType(TextFormField).at(2), '架空の資料');
    await tester.ensureVisible(find.text('保存前の確認へ'));
    await tester.tap(find.text('保存前の確認へ'));
    final focus = FocusNode();
    addTearDown(focus.dispose);
    unawaited(
      showDialog<void>(
        context: tester.element(find.byType(Scaffold)),
        builder: (_) =>
            AlertDialog(content: TextField(focusNode: focus, autofocus: true)),
      ),
    );
    await tester.pumpAndSettle();
    expect(focus.hasFocus, isTrue);
    expect(store.writes, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sign out removes review without submitting', (tester) async {
    final owner = ValueNotifier<String?>('synthetic-owner');
    addTearDown(owner.dispose);
    final a = SyntheticSnapshotStore();
    await _openReview(tester, owner, a, _OwnerB());
    owner.value = null;
    await tester.pump();
    expect(find.text('入金直後残高：120000円', skipOffstage: false), findsNothing);
    expect(find.text('給与入金直後の残高を記録するにはログインしてください。'), findsOneWidget);
    expect(a.writes, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('barrier cancels review without activating background operations',
      (tester) async {
    final owner = ValueNotifier<String?>('synthetic-owner');
    addTearDown(owner.dispose);
    var externalTaps = 0;
    await _openReview(
      tester,
      owner,
      SyntheticSnapshotStore(),
      _OwnerB(),
      onExternalTap: () => externalTaps++,
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '再読込'))
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('別操作'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(externalTaps, 0);
    expect(find.text('給与入金直後の残高を確認'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('escape and back cancel without losing inputs or writing',
      (tester) async {
    final owner = ValueNotifier<String?>('synthetic-owner');
    addTearDown(owner.dispose);
    final a = SyntheticSnapshotStore();
    await _openReview(tester, owner, a, _OwnerB());
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('給与入金直後の残高を確認'), findsNothing);
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).at(1))
          .controller!
          .text,
      '120000',
    );
    await tester.ensureVisible(find.text('保存前の確認へ'));
    await tester.tap(find.text('保存前の確認へ'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('給与入金直後の残高を確認'), findsNothing);
    expect(a.writes, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('owner switch during delayed save never writes the other owner',
      (tester) async {
    final owner = ValueNotifier<String?>('synthetic-owner');
    addTearDown(owner.dispose);
    final a = _DelayedStore();
    final b = _OwnerB();
    await _openReview(tester, owner, a, b);
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.ensureVisible(find.text('確認して保存'));
    await tester.tap(find.text('確認して保存'));
    await tester.tap(find.text('確認して保存'), warnIfMissed: false);
    await tester.pump();
    expect(a.writes, 1);
    owner.value = b.ownerId;
    await tester.pump();
    a.release.complete();
    await tester.pumpAndSettle();
    expect(b.writes, 0);
    expect(find.text('入金直後残高：120000円', skipOffstage: false), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('review remains accessible on a narrow enlarged screen',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    try {
      final owner = ValueNotifier<String?>('synthetic-owner');
      addTearDown(owner.dispose);
      await _openReview(
        tester,
        owner,
        SyntheticSnapshotStore(),
        _OwnerB(),
        textScale: 1.5,
      );
      expect(find.bySemanticsLabel(RegExp('給与入金直後の残高を確認')), findsWidgets);
      await tester.ensureVisible(
        find.byKey(const ValueKey('payroll-confirmation-reference')),
      );
      expect(
        find.byKey(const ValueKey('payroll-confirmation-reference')),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('保留する'));
      await tester.tap(find.text('保留する'));
      await tester.pumpAndSettle();
      expect(find.text('給与入金直後の残高を確認'), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });
}
