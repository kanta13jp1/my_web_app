import 'dart:ui' show SemanticsAction;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/business_execution.dart';
import 'package:my_web_app/services/business_execution_store.dart';
import 'package:my_web_app/widgets/business_execution_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/business_execution_test.dart' as fixtures;
import '../view_models/business_execution_controller_test.dart' as fakes;

Future<void> reveal(WidgetTester tester, Finder finder) async {
  // Text editing schedules layout and caret scrolling after enterText returns.
  // Settle that work before calculating the next target's scroll position.
  await tester.pumpAndSettle();
  final scrollable = find
      .descendant(
        of: find.byType(BusinessExecutionPanel),
        matching: find.byType(Scrollable),
      )
      .first;
  if (finder.evaluate().isEmpty) {
    tester.state<ScrollableState>(scrollable).position.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(finder, 250, scrollable: scrollable);
  }
  expect(finder, findsOneWidget);
  await tester.ensureVisible(finder);
  // ensureVisible may change scroll offset before the frame is laid out.
  await tester.pumpAndSettle();
}

Future<void> enter(WidgetTester tester, String label, String value) async {
  final field = find.widgetWithText(TextField, label);
  await reveal(tester, field);
  await tester.enterText(field, value);
  await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await reveal(tester, finder);
  expect(
    finder.hitTestable(),
    findsOneWidget,
    reason: 'The visible control must receive the tap: $text',
  );
  await tester.tap(finder.hitTestable());
  await tester.pumpAndSettle();
}

Future<void> scrollPanelToTop(WidgetTester tester) async {
  // Use the panel padding, outside the nested editable scrollables.
  final bounds = tester.getRect(find.byType(BusinessExecutionPanel));
  await tester.sendEventToBinding(
    PointerScrollEvent(
      position: bounds.topLeft + const Offset(4, 4),
      scrollDelta: const Offset(0, -10000),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> scrollPanelAwayFromField(WidgetTester tester, String label) async {
  final scrollable = find
      .descendant(
        of: find.byType(BusinessExecutionPanel),
        matching: find.byType(Scrollable),
      )
      .first;
  final position = tester.state<ScrollableState>(scrollable).position;
  final before = position.pixels;
  expect(before - position.minScrollExtent, greaterThan(500));
  await scrollPanelToTop(tester);
  expect(position.pixels, closeTo(position.minScrollExtent, 0.1));
  expect(find.widgetWithText(TextField, label).hitTestable(), findsNothing);
}

Future<void> revealPanelFieldByWheel(WidgetTester tester, String label) async {
  final visibleField = find.widgetWithText(TextField, label).hitTestable();
  await scrollPanelToTop(tester);
  for (var i = 0; i < 60 && visibleField.evaluate().isEmpty; i++) {
    final bounds = tester.getRect(find.byType(BusinessExecutionPanel));
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: bounds.topLeft + const Offset(4, 4),
        scrollDelta: const Offset(0, 250),
      ),
    );
    await tester.pumpAndSettle();
  }
  expect(visibleField, findsOneWidget);
}

Widget app(
  BusinessExecutionStore store, {
  String user = 'a',
  double scale = 1,
}) =>
    MaterialApp(
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: BusinessExecutionPanel(
            key: ValueKey(user),
            userId: user,
            currentUserId: () => user,
            store: store,
            now: () => DateTime(2026, 10, 30),
          ),
        ),
      ),
    );

Future<void> expectReadableLatest(WidgetTester tester, String value) async {
  final parent = find.byWidgetPredicate(
    (widget) => widget is Semantics && widget.properties.label == value,
  );
  await reveal(tester, parent);
  expect(find.bySemanticsLabel(value), findsOneWidget);
  final selectable = find.descendant(
    of: parent,
    matching: find.byWidgetPredicate(
      (widget) => widget is SelectableText && widget.data == value,
    ),
  );
  expect(selectable, findsOneWidget);
  await tester.tap(selectable);
  await tester.pumpAndSettle();
  final editable = find.descendant(
    of: selectable,
    matching: find.byType(EditableText),
  );
  expect(editable, findsOneWidget);
  final editableSemantics = tester.getSemantics(editable).getSemanticsData();
  expect(editableSemantics.hasAction(SemanticsAction.setSelection), isTrue);
}

void main() {
  testWidgets('create plan, save zero and reflection, then restore on reopen', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const store = LocalBusinessExecutionStore(
      withLock: fakes.testExecutionLock,
    );
    await tester.pumpWidget(app(store));
    await tester.pumpAndSettle();
    await tapText(tester, '月の実行計画を作る');
    await enter(tester, '解決したい課題', '提案が相談につながらない');
    await enter(tester, '成果指標（KPI）例：月内の相談申込数', '相談申込数');
    await enter(tester, '成果の単位 例：件', '件');
    await enter(tester, '期間終了時の成果目標', '3');
    await enter(tester, '行動指標（KDI）例：顧客へのヒアリング', 'ヒアリング');
    await enter(tester, '行動の単位 例：回', '回');
    await enter(tester, '1日あたりの行動目標', '2');
    await tapText(tester, '計画を端末に保存');
    expect(find.text('未入力: 1日（今日を含む対象日のみ）'), findsOneWidget);
    await enter(tester, 'この日の行動実績（回）', '0');
    await enter(tester, 'この日時点の成果実績（任意・件）', '1');
    await enter(tester, '日次の振り返り・次の一手', '明日は質問を変える');
    await tapText(tester, 'この日の記録を保存');
    expect(find.text('未入力: 0日（今日を含む対象日のみ）'), findsOneWidget);
    await enter(tester, '月次の振り返り（続けること・変えること・次月の行動）', '次月は紹介経路を試す');
    await tapText(tester, '月次の振り返りを保存');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app(store));
    await tester.pumpAndSettle();
    await tapText(tester, '相談申込数');
    final raw = await store.read('a');
    final restored = BusinessExecutionCodec.decode(raw).single;
    expect(restored.reports['2026-10-30']!.actual, 0);
    expect(restored.reports['2026-10-30']!.note, '明日は質問を変える');
    expect(restored.reflection, '次月は紹介経路を試す');
    expect(find.text('未入力: 0日（今日を含む対象日のみ）'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('save failure keeps typed input and retry restores the record', (
    tester,
  ) async {
    final store = fakes.MemoryExecutionStore()
      ..data['a'] = BusinessExecutionCodec.encode([fixtures.plan()]);
    await tester.pumpWidget(app(store));
    await tester.pumpAndSettle();
    await tapText(tester, '相談申込数');
    await enter(tester, 'この日の行動実績（回）', '2');
    await enter(tester, '日次の振り返り・次の一手', '保存前の文章');
    store.failWrite = true;
    await tapText(tester, 'この日の記録を保存');
    expect(find.text('保存前の文章'), findsOneWidget);
    expect(
      BusinessExecutionCodec.decode(store.data['a']).single.reports,
      isEmpty,
    );
    await tapText(tester, '保存結果を再読み込み');
    expect(find.text('保存前の文章'), findsOneWidget);
    store.failWrite = false;
    await tapText(tester, 'この日の記録を保存');
    expect(
      BusinessExecutionCodec.decode(
        store.data['a'],
      ).single.reports['2026-10-30']!.note,
      '保存前の文章',
    );
  });

  testWidgets('account switch removes the previous account and its draft', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = fakes.MemoryExecutionStore()
      ..data['a'] = BusinessExecutionCodec.encode([fixtures.plan()]);
    await tester.pumpWidget(app(store, scale: 2));
    await tester.pumpAndSettle();
    await tapText(tester, '相談申込数');
    await enter(tester, '日次の振り返り・次の一手', '前のアカウントの未保存入力');
    await scrollPanelAwayFromField(tester, '日次の振り返り・次の一手');
    await tester.pumpWidget(app(store, user: 'b', scale: 2));
    await tester.pumpAndSettle();
    expect(find.text('前のアカウントの未保存入力'), findsNothing);
    expect(find.text('相談申込数'), findsNothing);
    expect(store.data['b'], isNull);
    final empty = find.text('まだ計画がありません。解決したい課題から始めましょう。');
    await reveal(tester, empty);
    expect(empty, findsOneWidget);
    await tester.pumpWidget(app(store, scale: 2));
    await tester.pumpAndSettle();
    await tapText(tester, '相談申込数');
    final note = find.widgetWithText(TextField, '日次の振り返り・次の一手');
    await reveal(tester, note);
    expect(tester.widget<TextField>(note).controller!.text, isEmpty);
    expect(store.data['b'], isNull);
  });

  testWidgets('320px at double text size can reach and save the report', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = fakes.MemoryExecutionStore()
      ..data['a'] = BusinessExecutionCodec.encode([fixtures.plan()]);
    await tester.pumpWidget(app(store, scale: 2));
    await tester.pumpAndSettle();
    await tapText(tester, '相談申込数');
    await enter(tester, 'この日の行動実績（回）', '0');
    await tapText(tester, 'この日の記録を保存');
    expect(
      BusinessExecutionCodec.decode(
        store.data['a'],
      ).single.reports['2026-10-30']!.actual,
      0,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('unsupported locking refuses save and keeps the plan draft', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalBusinessExecutionStore(
      withLock: (name, action) async => throw UnsupportedError('no locks'),
    );
    final raw = BusinessExecutionCodec.encode([fixtures.plan()]);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(LocalBusinessExecutionStore.keyFor('a'), raw);
    await tester.pumpWidget(app(store));
    await tester.pumpAndSettle();
    await tapText(tester, '相談申込数');
    await enter(tester, 'この日の行動実績（回）', '1');
    await enter(tester, '日次の振り返り・次の一手', '未対応でも残す');
    await tapText(tester, 'この日の記録を保存');
    expect(find.text('未対応でも残す'), findsOneWidget);
    expect(await store.read('a'), raw);
    final error = find.textContaining('この環境では安全に保存できません。');
    // The notice is a separate lazy ListView child above the long detail form.
    await reveal(tester, error);
    expect(error, findsOneWidget);
  });

  testWidgets('starting date becomes selectable on a later rebuild', (
    tester,
  ) async {
    var now = DateTime(2026, 10, 28);
    final store = fakes.MemoryExecutionStore()
      ..data['a'] = BusinessExecutionCodec.encode([fixtures.plan()]);
    Widget build() => MaterialApp(
          home: Scaffold(
            body: BusinessExecutionPanel(
              userId: 'a',
              currentUserId: () => 'a',
              store: store,
              now: () => now,
            ),
          ),
        );
    await tester.pumpWidget(build());
    await tester.pumpAndSettle();
    await tapText(tester, '相談申込数');
    expect(find.text('計画の開始日を迎えると実績を入力できます。'), findsOneWidget);
    now = DateTime(2026, 10, 29);
    await tester.pumpWidget(build());
    await tester.pumpAndSettle();
    await enter(tester, 'この日の行動実績（回）', '0');
    await tapText(tester, 'この日の記録を保存');
    expect(
      BusinessExecutionCodec.decode(
        store.data['a'],
      ).single.reports['2026-10-29']!.actual,
      0,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'remote archive conflict retains drafts through reload and reopen',
    (tester) async {
      final original = fixtures.plan();
      final store = fakes.MemoryExecutionStore()
        ..data['a'] = BusinessExecutionCodec.encode([original]);
      await tester.pumpWidget(app(store));
      await tester.pumpAndSettle();
      await tapText(tester, '相談申込数');
      await enter(tester, 'この日の行動実績（回）', '2');
      await enter(tester, '日次の振り返り・次の一手', '競合後にも残す日次');
      await enter(tester, '月次の振り返り（続けること・変えること・次月の行動）', '競合後にも残す月次');
      store.data['a'] = BusinessExecutionCodec.encode([
        original.withArchived(true),
      ]);
      await tapText(tester, 'この日の記録を保存');
      await tapText(tester, '保存結果を再読み込み');
      expect(find.textContaining('競合後にも残す日次'), findsOneWidget);
      expect(find.textContaining('競合後にも残す月次'), findsOneWidget);
      await tapText(tester, 'この計画を再開');
      expect(find.text('競合後にも残す日次'), findsOneWidget);
      expect(find.text('競合後にも残す月次'), findsOneWidget);
      await tapText(tester, 'この日の記録を保存');
      await tapText(tester, '月次の振り返りを保存');
      final restored = BusinessExecutionCodec.decode(store.data['a']).single;
      expect(restored.reports['2026-10-30']!.note, '競合後にも残す日次');
      expect(restored.reflection, '競合後にも残す月次');
    },
  );

  testWidgets(
    'same-day and monthly remote changes require explicit overwrite',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final original = fixtures
            .plan()
            .withReport(
              '2026-10-30',
              BusinessDailyReport(actual: 1, note: '元の記録'),
            )
            .withReflection('元の月次');
        final store = fakes.MemoryExecutionStore()
          ..data['a'] = BusinessExecutionCodec.encode([original]);
        await tester.pumpWidget(app(store));
        await tester.pumpAndSettle();
        await tapText(tester, '相談申込数');
        await enter(tester, 'この日の行動実績（回）', '2');
        await enter(tester, '日次の振り返り・次の一手', '手元の日次下書き');
        await enter(tester, '月次の振り返り（続けること・変えること・次月の行動）', '手元の月次下書き');
        final remote = original
            .withReport(
              '2026-10-30',
              BusinessDailyReport(actual: 3, note: '別タブの日次'),
            )
            .withReflection('別タブの月次');
        store.data['a'] = BusinessExecutionCodec.encode([remote]);
        await tapText(tester, 'この日の記録を更新');
        await tapText(tester, '保存結果を再読み込み');
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'この日の記録を更新'),
              )
              .onPressed,
          isNull,
        );
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, '月次の振り返りを保存'),
              )
              .onPressed,
          isNull,
        );
        expect(find.text('手元の日次下書き'), findsOneWidget);
        expect(find.textContaining('最新の日次振り返り: 別タブの日次'), findsOneWidget);
        await expectReadableLatest(
          tester,
          '最新の行動実績: 3.0\n'
          '最新の成果実績: 未入力\n'
          '最新の日次振り返り: 別タブの日次',
        );
        await expectReadableLatest(tester, '最新の月次振り返り: 別タブの月次');
        expect(
          BusinessExecutionCodec.decode(
            store.data['a'],
          ).single.reports['2026-10-30']!.actual,
          3,
        );
        await tapText(tester, '最新記録を確認し、この日次入力で上書きする');
        final changedAgain = remote.withReport(
          '2026-10-30',
          BusinessDailyReport(actual: 4, note: '確認後に別タブが再更新'),
        );
        store.data['a'] = BusinessExecutionCodec.encode([changedAgain]);
        await tapText(tester, 'この日の記録を更新');
        await tapText(tester, '保存結果を再読み込み');
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'この日の記録を更新'),
              )
              .onPressed,
          isNull,
        );
        expect(
          BusinessExecutionCodec.decode(
            store.data['a'],
          ).single.reports['2026-10-30']!.actual,
          4,
        );
        expect(
          find.bySemanticsLabel(
            '最新の行動実績: 3.0\n'
            '最新の成果実績: 未入力\n'
            '最新の日次振り返り: 別タブの日次',
            skipOffstage: false,
          ),
          findsNothing,
        );
        await expectReadableLatest(
          tester,
          '最新の行動実績: 4.0\n'
          '最新の成果実績: 未入力\n'
          '最新の日次振り返り: 確認後に別タブが再更新',
        );
        await tapText(tester, '最新記録を確認し、この日次入力で上書きする');
        await tapText(tester, 'この日の記録を更新');
        await tapText(tester, '最新記録を確認し、この月次入力で上書きする');
        await tapText(tester, '月次の振り返りを保存');
        final saved = BusinessExecutionCodec.decode(store.data['a']).single;
        expect(saved.reports['2026-10-30']!.note, '手元の日次下書き');
        expect(saved.reflection, '手元の月次下書き');
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('empty latest conflict text remains available to semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final original = fixtures
          .plan()
          .withReport(
            '2026-10-30',
            BusinessDailyReport(actual: 1, note: '元の日次'),
          )
          .withReflection('元の月次');
      final store = fakes.MemoryExecutionStore()
        ..data['a'] = BusinessExecutionCodec.encode([original]);
      await tester.pumpWidget(app(store));
      await tester.pumpAndSettle();
      await tapText(tester, '相談申込数');
      await enter(tester, 'この日の行動実績（回）', '2');
      await enter(tester, '日次の振り返り・次の一手', '手元の日次');
      await enter(tester, '月次の振り返り（続けること・変えること・次月の行動）', '手元の月次');
      final remote = original
          .withReport(
            '2026-10-30',
            BusinessDailyReport(actual: 3, note: ''),
          )
          .withReflection('');
      store.data['a'] = BusinessExecutionCodec.encode([remote]);
      await tapText(tester, 'この日の記録を更新');
      await tapText(tester, '保存結果を再読み込み');
      await expectReadableLatest(
        tester,
        '最新の行動実績: 3.0\n'
        '最新の成果実績: 未入力\n'
        '最新の日次振り返り: ',
      );
      await expectReadableLatest(tester, '最新の月次振り返り: ');
      expect(find.text('手元の日次'), findsOneWidget);
      expect(find.text('手元の月次'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('account switch removes old conflict values from semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final original = fixtures
          .plan()
          .withReport(
            '2026-10-30',
            BusinessDailyReport(actual: 1, note: '元の日次'),
          )
          .withReflection('元の月次');
      final bPayload = fixtures.plan(id: 'b-plan').toJson()
        ..['outcome'] = 'B専用の成果指標';
      final bPlan = BusinessExecutionPlan.fromJson(bPayload);
      final store = fakes.MemoryExecutionStore()
        ..data['a'] = BusinessExecutionCodec.encode([original])
        ..data['b'] = BusinessExecutionCodec.encode([bPlan]);
      await tester.pumpWidget(app(store));
      await tester.pumpAndSettle();
      await tapText(tester, '相談申込数');
      await enter(tester, 'この日の行動実績（回）', '2');
      await enter(tester, '日次の振り返り・次の一手', '手元の下書き');
      await enter(tester, '月次の振り返り（続けること・変えること・次月の行動）', '手元の月次');
      final remote = original
          .withReport(
            '2026-10-30',
            BusinessDailyReport(actual: 3, note: '旧アカウントの最新日次'),
          )
          .withReflection('旧アカウントの最新月次');
      store.data['a'] = BusinessExecutionCodec.encode([remote]);
      await tapText(tester, 'この日の記録を更新');
      await tapText(tester, '保存結果を再読み込み');
      const oldDay = '最新の行動実績: 3.0\n'
          '最新の成果実績: 未入力\n'
          '最新の日次振り返り: 旧アカウントの最新日次';
      const oldMonth = '最新の月次振り返り: 旧アカウントの最新月次';
      await expectReadableLatest(tester, oldDay);
      await expectReadableLatest(tester, oldMonth);
      expect(find.text(oldDay, skipOffstage: false), findsOneWidget);
      expect(find.text(oldMonth, skipOffstage: false), findsOneWidget);
      expect(find.text('手元の下書き', skipOffstage: false), findsOneWidget);
      expect(find.text('手元の月次', skipOffstage: false), findsOneWidget);
      await tester.pumpWidget(app(store, user: 'b'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(oldDay, skipOffstage: false), findsNothing);
      expect(
          find.bySemanticsLabel(oldMonth, skipOffstage: false), findsNothing);
      expect(find.text(oldDay, skipOffstage: false), findsNothing);
      expect(find.text(oldMonth, skipOffstage: false), findsNothing);
      expect(find.text('手元の下書き', skipOffstage: false), findsNothing);
      expect(find.text('手元の月次', skipOffstage: false), findsNothing);
      expect(
        find.bySemanticsLabel(RegExp('手元の下書き|手元の月次'), skipOffstage: false),
        findsNothing,
      );
      await reveal(tester, find.text('B専用の成果指標'));
      expect(find.text('B専用の成果指標'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('B専用の成果指標')), findsWidgets);
      expect(
          BusinessExecutionCodec.decode(store.data['b']).single.id, 'b-plan');
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('new plan draft survives insertion of a save-error notice', (
    tester,
  ) async {
    final store = fakes.MemoryExecutionStore()..failWrite = true;
    await tester.pumpWidget(app(store));
    await tester.pumpAndSettle();
    await tapText(tester, '月の実行計画を作る');
    await enter(tester, '解決したい課題', '作成中の課題を残す');
    await enter(tester, '成果指標（KPI）例：月内の相談申込数', '相談申込数');
    await enter(tester, '成果の単位 例：件', '件');
    await enter(tester, '期間終了時の成果目標', '3');
    await enter(tester, '行動指標（KDI）例：顧客へのヒアリング', 'ヒアリング');
    await enter(tester, '行動の単位 例：回', '回');
    await enter(tester, '1日あたりの行動目標', '2');
    await tapText(tester, '計画を端末に保存');
    expect(find.text('作成中の課題を残す'), findsOneWidget);
    await tapText(tester, '保存結果を再読み込み');
    expect(find.text('作成中の課題を残す'), findsOneWidget);
    store.failWrite = false;
    await tapText(tester, '計画を端末に保存');
    expect(
      BusinessExecutionCodec.decode(store.data['a']).single.issue,
      '作成中の課題を残す',
    );
  });

  testWidgets('unedited report and reflection adopt latest values on reload', (
    tester,
  ) async {
    final original = fixtures
        .plan()
        .withReport(
          '2026-10-30',
          BusinessDailyReport(actual: 1, note: '読込時の日次'),
        )
        .withReflection('読込時の月次');
    final store = fakes.MemoryExecutionStore()
      ..data['a'] = BusinessExecutionCodec.encode([original]);
    await tester.pumpWidget(app(store));
    await tester.pumpAndSettle();
    await tapText(tester, '相談申込数');
    store.data['a'] = BusinessExecutionCodec.encode([
      original
          .withReport(
            '2026-10-30',
            BusinessDailyReport(actual: 3, note: '最新の日次へ同期'),
          )
          .withReflection('最新の月次へ同期'),
    ]);
    await tapText(tester, 'この日の記録を更新');
    await tapText(tester, '保存結果を再読み込み');
    expect(find.text('最新の日次へ同期'), findsWidgets);
    expect(find.text('最新の月次へ同期'), findsOneWidget);
    expect(find.text('最新記録を確認し、この日次入力で上書きする'), findsNothing);
    expect(find.text('最新記録を確認し、この月次入力で上書きする'), findsNothing);
  });
  for (final detail in [false, true]) {
    final screen = detail ? 'detail' : 'plan';
    testWidgets('user scroll keeps $screen drafts and dismisses editing', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = fakes.MemoryExecutionStore();
      if (detail) {
        store.data['a'] = BusinessExecutionCodec.encode([fixtures.plan()]);
      }
      final storedBefore = store.data['a'];
      await tester.pumpWidget(app(store, scale: 2));
      await tester.pumpAndSettle();
      await tapText(tester, detail ? '相談申込数' : '月の実行計画を作る');
      final firstLabel = detail ? '日次の振り返り・次の一手' : '解決したい課題';
      final lastLabel = detail ? '月次の振り返り（続けること・変えること・次月の行動）' : '行動の単位 例：回';
      await enter(tester, firstLabel, 'スクロール前の未保存入力');
      final firstField = find.widgetWithText(
        TextField,
        firstLabel,
        skipOffstage: false,
      );
      final firstController = tester.widget<TextField>(firstField).controller!;
      await enter(tester, lastLabel, '回');
      final lastField = find.widgetWithText(
        TextField,
        lastLabel,
        skipOffstage: false,
      );
      final lastController = tester.widget<TextField>(lastField).controller!;
      final editingFocus = FocusManager.instance.primaryFocus!;
      expect(editingFocus.hasFocus, isTrue);

      // A real pointer wheel causes a user-scroll notification, unlike jumpTo.
      await scrollPanelAwayFromField(tester, firstLabel);
      expect(editingFocus.hasFocus, isFalse);
      expect(tester.testTextInput.isVisible, isFalse);
      final panelScope = editingFocus.enclosingScope!;
      expect(FocusManager.instance.primaryFocus, same(panelScope));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      final traversed = FocusManager.instance.primaryFocus!;
      expect(traversed, isNot(same(panelScope)));
      expect(traversed.enclosingScope, same(panelScope));

      await revealPanelFieldByWheel(tester, firstLabel);
      expect(
        tester.widget<TextField>(firstField).controller,
        same(firstController),
      );
      expect(firstController.text, 'スクロール前の未保存入力');
      await revealPanelFieldByWheel(tester, lastLabel);
      expect(
        tester.widget<TextField>(lastField).controller,
        same(lastController),
      );
      expect(lastController.text, '回');
      expect(store.data['a'], storedBefore);

      await tester.tap(lastField);
      await tester.pumpAndSettle();
      expect(editingFocus.hasFocus, isTrue);
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '回数',
          selection: TextSelection.collapsed(offset: 2),
        ),
      );
      await tester.pumpAndSettle();
      expect(lastController.text, '回数');
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(editingFocus.hasFocus, isFalse);
      if (detail) {
        await enter(tester, 'この日の行動実績（回）', '0');
        await tapText(tester, 'この日の記録を保存');
        await tapText(tester, '月次の振り返りを保存');
      } else {
        final next = find.widgetWithText(TextField, '1日あたりの行動目標');
        final editable = tester.widget<EditableText>(
          find.descendant(of: next, matching: find.byType(EditableText)),
        );
        expect(editable.focusNode.hasFocus, isTrue);
        await enter(tester, '成果指標（KPI）例：月内の相談申込数', '相談申込数');
        await enter(tester, '成果の単位 例：件', '件');
        await enter(tester, '期間終了時の成果目標', '3');
        await enter(tester, '行動指標（KDI）例：顧客へのヒアリング', 'ヒアリング');
        await enter(tester, '1日あたりの行動目標', '2');
        await tapText(tester, '計画を端末に保存');
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(app(store));
      await tester.pumpAndSettle();
      await tapText(tester, '相談申込数');
      final saved = BusinessExecutionCodec.decode(store.data['a']).single;
      if (detail) {
        expect(saved.reports['2026-10-30']!.note, 'スクロール前の未保存入力');
        expect(saved.reflection, '回数');
      } else {
        expect(saved.issue, 'スクロール前の未保存入力');
        expect(saved.actionUnit, '回数');
      }
      final restoredLabel = detail ? lastLabel : 'この日の行動実績（回数）';
      await reveal(tester, find.widgetWithText(TextField, restoredLabel));
      if (detail) {
        final restoredField = find.widgetWithText(TextField, restoredLabel);
        final restoredController =
            tester.widget<TextField>(restoredField).controller!;
        expect(restoredController.text, '回数');
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('caret selection and keyboard focus scrolling keep editing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app(fakes.MemoryExecutionStore()));
    await tester.pumpAndSettle();
    await tapText(tester, '月の実行計画を作る');
    await enter(tester, '行動の単位 例：回', '回数');
    final field = find.widgetWithText(TextField, '行動の単位 例：回');
    final controller = tester.widget<TextField>(field).controller!;
    final editingFocus = FocusManager.instance.primaryFocus!;

    // Programmatic visibility changes must not be treated as user scrolling.
    await tester.ensureVisible(
      find.widgetWithText(TextField, '開始日 YYYY-MM-DD'),
    );
    await tester.pumpAndSettle();
    expect(editingFocus.hasFocus, isTrue);
    await reveal(tester, field);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(editingFocus.hasFocus, isTrue);
    expect(controller.text, '回数');
    expect(controller.selection.baseOffset, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus, isNot(same(editingFocus)));
    expect(tester.testTextInput.hasAnyClients, isTrue);
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '4',
        selection: TextSelection.collapsed(offset: 1),
      ),
    );
    await tester.pumpAndSettle();
    final next = find.widgetWithText(TextField, '1日あたりの行動目標');
    expect(tester.widget<TextField>(next).controller!.text, '4');
    expect(controller.text, '回数');
    expect(tester.takeException(), isNull);
  });

  testWidgets('scrolling inside a multiline field keeps its editing focus', (
    tester,
  ) async {
    final store = fakes.MemoryExecutionStore()
      ..data['a'] = BusinessExecutionCodec.encode([fixtures.plan()]);
    await tester.pumpWidget(app(store));
    await tester.pumpAndSettle();
    await tapText(tester, '相談申込数');
    final draft = List.filled(20, '段落').join('\n');
    await enter(tester, '日次の振り返り・次の一手', draft);
    final field = find.widgetWithText(TextField, '日次の振り返り・次の一手');
    final editingFocus = FocusManager.instance.primaryFocus!;
    final inner = tester.state<ScrollableState>(
      find.descendant(of: field, matching: find.byType(Scrollable)),
    );
    final before = inner.position.pixels;
    expect(before, greaterThan(0));
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(field),
        scrollDelta: const Offset(0, -60),
      ),
    );
    await tester.pumpAndSettle();
    expect(inner.position.pixels, lessThan(before));
    expect(editingFocus.hasFocus, isTrue);
    expect(tester.widget<TextField>(field).controller!.text, draft);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'user scroll preserves composing text and selection until commit',
    (tester) async {
      tester.view.physicalSize = const Size(320, 500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = fakes.MemoryExecutionStore();
      await tester.pumpWidget(app(store, scale: 2));
      await tester.pumpAndSettle();
      await tapText(tester, '月の実行計画を作る');
      await enter(tester, '行動の単位 例：回', '');
      final field = find.widgetWithText(TextField, '行動の単位 例：回');
      final controller = tester.widget<TextField>(field).controller!;
      final editingFocus = FocusManager.instance.primaryFocus!;
      // A synthetic IME update checks widget policy, not the web IME bridge.
      const composing = TextEditingValue(
        text: 'にほん',
        selection: TextSelection(baseOffset: 1, extentOffset: 3),
        composing: TextRange(start: 0, end: 3),
      );
      tester.testTextInput.updateEditingValue(composing);
      await tester.pumpAndSettle();
      await scrollPanelToTop(tester);
      expect(editingFocus.hasFocus, isTrue);
      expect(controller.value, composing);
      expect(tester.testTextInput.hasAnyClients, isTrue);

      await reveal(tester, field);
      const committed = TextEditingValue(
        text: '日本',
        selection: TextSelection.collapsed(offset: 2),
      );
      tester.testTextInput.updateEditingValue(committed);
      await tester.pumpAndSettle();
      await scrollPanelToTop(tester);
      expect(editingFocus.hasFocus, isFalse);
      expect(controller.value, committed);
      await reveal(tester, field);
      await tester.tap(field);
      await tester.pumpAndSettle();
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '日本語',
          selection: TextSelection.collapsed(offset: 3),
        ),
      );
      await tester.pumpAndSettle();
      expect(controller.text, '日本語');
      expect(controller.value.composing, TextRange.empty);
      expect(store.data['a'], isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'panel scrolling leaves external focus selection and Tab intact',
    (tester) async {
      final firstFocus = FocusNode();
      final secondFocus = FocusNode();
      final outside = TextEditingController();
      addTearDown(firstFocus.dispose);
      addTearDown(secondFocus.dispose);
      addTearDown(outside.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                TextField(
                  focusNode: firstFocus,
                  controller: outside,
                  decoration: const InputDecoration(labelText: '外側の入力'),
                ),
                TextField(
                  focusNode: secondFocus,
                  decoration: const InputDecoration(labelText: '外側の次の入力'),
                ),
                Expanded(
                  child: BusinessExecutionPanel(
                    userId: 'a',
                    currentUserId: () => 'a',
                    store: fakes.MemoryExecutionStore(),
                    now: () => DateTime(2026, 10, 30),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tapText(tester, '月の実行計画を作る');
      await enter(tester, '行動の単位 例：回', '回');
      final field = find.widgetWithText(TextField, '外側の入力');
      await tester.enterText(field, '外部入力');
      await tester.pumpAndSettle();
      const value = TextEditingValue(
        text: '外部入力',
        selection: TextSelection(baseOffset: 1, extentOffset: 3),
      );
      tester.testTextInput.updateEditingValue(value);
      await tester.pumpAndSettle();
      await scrollPanelToTop(tester);
      expect(firstFocus.hasFocus, isTrue);
      expect(outside.value, value);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(secondFocus.hasFocus, isTrue);
      expect(outside.value, value);
      expect(tester.takeException(), isNull);
    },
  );
}
