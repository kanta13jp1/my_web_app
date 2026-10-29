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
    await tester.scrollUntilVisible(
      finder,
      250,
      scrollable: scrollable,
    );
  }
  expect(finder, findsOneWidget);
  await tester.ensureVisible(finder);
  // ensureVisible may change scroll offset before the frame is laid out.
  await tester.pumpAndSettle();
}

Future<void> enter(
  WidgetTester tester,
  String label,
  String value,
) async {
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

void main() {
  testWidgets('create plan, save zero and reflection, then restore on reopen',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    const store =
        LocalBusinessExecutionStore(withLock: fakes.testExecutionLock);
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
    await enter(
      tester,
      '月次の振り返り（続けること・変えること・次月の行動）',
      '次月は紹介経路を試す',
    );
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

  testWidgets('save failure keeps typed input and retry restores the record',
      (tester) async {
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
      BusinessExecutionCodec.decode(store.data['a'])
          .single
          .reports['2026-10-30']!
          .note,
      '保存前の文章',
    );
  });

  testWidgets('account switch removes the previous account and its draft',
      (tester) async {
    final store = fakes.MemoryExecutionStore()
      ..data['a'] = BusinessExecutionCodec.encode([fixtures.plan()]);
    await tester.pumpWidget(app(store));
    await tester.pumpAndSettle();
    await tapText(tester, '相談申込数');
    await enter(tester, '日次の振り返り・次の一手', '前のアカウントの未保存入力');
    await tester.pumpWidget(app(store, user: 'b'));
    await tester.pumpAndSettle();
    expect(find.text('前のアカウントの未保存入力'), findsNothing);
    expect(find.text('相談申込数'), findsNothing);
    expect(store.data['b'], isNull);
    expect(
      find.text('まだ計画がありません。解決したい課題から始めましょう。'),
      findsOneWidget,
    );
  });

  testWidgets('320px at double text size can reach and save the report',
      (tester) async {
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
      BusinessExecutionCodec.decode(store.data['a'])
          .single
          .reports['2026-10-30']!
          .actual,
      0,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('unsupported locking refuses save and keeps the plan draft',
      (tester) async {
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

  testWidgets('starting date becomes selectable on a later rebuild',
      (tester) async {
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
      BusinessExecutionCodec.decode(store.data['a'])
          .single
          .reports['2026-10-29']!
          .actual,
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
    await enter(
      tester,
      '月次の振り返り（続けること・変えること・次月の行動）',
      '競合後にも残す月次',
    );
    store.data['a'] =
        BusinessExecutionCodec.encode([original.withArchived(true)]);
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
  });

  testWidgets('same-day and monthly remote changes require explicit overwrite',
      (tester) async {
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
    await enter(
      tester,
      '月次の振り返り（続けること・変えること・次月の行動）',
      '手元の月次下書き',
    );
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
    expect(
      BusinessExecutionCodec.decode(store.data['a'])
          .single
          .reports['2026-10-30']!
          .actual,
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
      BusinessExecutionCodec.decode(store.data['a'])
          .single
          .reports['2026-10-30']!
          .actual,
      4,
    );
    await tapText(tester, '最新記録を確認し、この日次入力で上書きする');
    await tapText(tester, 'この日の記録を更新');
    await tapText(tester, '最新記録を確認し、この月次入力で上書きする');
    await tapText(tester, '月次の振り返りを保存');
    final saved = BusinessExecutionCodec.decode(store.data['a']).single;
    expect(saved.reports['2026-10-30']!.note, '手元の日次下書き');
    expect(saved.reflection, '手元の月次下書き');
  });

  testWidgets('new plan draft survives insertion of a save-error notice',
      (tester) async {
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

  testWidgets('unedited report and reflection adopt latest values on reload',
      (tester) async {
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
    expect(
      find.text('最新記録を確認し、この日次入力で上書きする'),
      findsNothing,
    );
    expect(
      find.text('最新記録を確認し、この月次入力で上書きする'),
      findsNothing,
    );
  });
  for (final detail in [false, true]) {
    final screen = detail ? 'detail' : 'plan';
    testWidgets('user scroll keeps $screen drafts and dismisses editing',
        (tester) async {
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
      final lastLabel = detail
          ? '月次の振り返り（続けること・変えること・次月の行動）'
          : '行動の単位 例：回';
      await enter(tester, firstLabel, 'スクロール前の未保存入力');
      final firstField = find.widgetWithText(
        TextField,
        firstLabel,
        skipOffstage: false,
      );
      final firstController =
          tester.widget<TextField>(firstField).controller!;
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
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: tester.getCenter(find.byType(BusinessExecutionPanel)),
          scrollDelta: const Offset(0, -10000),
        ),
      );
      await tester.pumpAndSettle();
      expect(editingFocus.hasFocus, isFalse);
      expect(tester.testTextInput.isVisible, isFalse);
      expect(tester.getRect(firstField).top, greaterThan(750));

      await reveal(tester, firstField);
      expect(
        tester.widget<TextField>(firstField).controller,
        same(firstController),
      );
      expect(firstController.text, 'スクロール前の未保存入力');
      await reveal(tester, lastField);
      expect(
        tester.widget<TextField>(lastField).controller,
        same(lastController),
      );
      expect(lastController.text, '回');
      expect(store.data['a'], storedBefore);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('caret selection and keyboard focus scrolling keep editing',
      (tester) async {
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

  testWidgets('scrolling inside a multiline field keeps its editing focus',
      (tester) async {
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

}
