import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/business_execution.dart';
import 'package:my_web_app/services/business_execution_store.dart';
import 'package:my_web_app/widgets/business_execution_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/business_execution_test.dart' as fixtures;
import '../view_models/business_execution_controller_test.dart' as fakes;

Future<void> enter(
  WidgetTester tester,
  String label,
  String value,
) async {
  final field = find.widgetWithText(TextField, label);
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
}

Future<void> tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Widget app(BusinessExecutionStore store, {String user = 'a', double scale = 1}) =>
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
    const store = LocalBusinessExecutionStore(withLock: fakes.testExecutionLock);
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
    expect(find.text('まだ計画がありません。解決したい課題から始めましょう。'),
        findsOneWidget);
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
    expect(find.textContaining('この環境では安全に保存できません。'), findsOneWidget);
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

}
