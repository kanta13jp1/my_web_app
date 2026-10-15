import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/asset_calendar_refresh_control.dart';

void main() {
  testWidgets('disables duplicate refresh and retains sibling draft',
      (tester) async {
    final pending = Completer<void>();
    final draft = TextEditingController(text: '未保存の入力');
    addTearDown(draft.dispose);
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              TextField(controller: draft),
              AssetCalendarRefreshControl(onRefresh: () {
                calls++;
                return pending.future;
              }),
            ],
          ),
        ),
      ),
    );
    final button = find.byKey(const Key('asset_calendar_refresh'));
    await tester.tap(button);
    await tester.pump();
    expect(find.text('記録を更新中…'), findsOneWidget);
    expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
    expect(calls, 1);
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.textContaining('記録を更新しました'), findsOneWidget);
    expect(draft.text, '未保存の入力');
  });

  testWidgets('failed read is visible and can be retried', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AssetCalendarRefreshControl(onRefresh: () async {
            if (++calls == 1) throw StateError('offline');
          }),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('asset_calendar_refresh')));
    await tester.pumpAndSettle();
    expect(find.textContaining('表示は前回のまま'), findsOneWidget);
    await tester.tap(find.byKey(const Key('asset_calendar_refresh')));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.textContaining('記録を更新しました'), findsOneWidget);
  });
}
