import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_balance_observation.dart';
import 'package:my_web_app/widgets/asset_balance_history_control.dart';

AssetBalanceObservation observation(
  int id,
  String timestamp, {
  double amount = 1000,
}) =>
    AssetBalanceObservation(
      id: id,
      accountName: 'サンプル銀行',
      amount: amount,
      recordedAt: DateTime.parse(timestamp),
    );

Future<void> openHistory(
  WidgetTester tester,
  AssetBalanceHistoryLoader loader, {
  AssetBalanceObservation? latest,
}) async {
  await tester.pumpWidget(
    MaterialApp(
    home: Scaffold(
      body: AssetBalanceHistoryControl(
        accountName: 'サンプル銀行',
        latest: latest,
        loadPage: loader,
      ),
    ),
    ),
  );
  await tester.tap(find.text('残高履歴'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opens lazily and retains same-day equal-value rows',
      (tester) async {
    final offsets = <int>[];
    final rows = [
      observation(2, '2026-10-11T08:44:00Z'),
      observation(1, '2026-10-10T17:18:00Z'),
    ];
    await openHistory(tester, (offset) async {
      offsets.add(offset);
      return rows;
    }, latest: rows.first,);
    expect(offsets, [0]);
    expect(find.text('2026-10-11 17:44 JST'), findsOneWidget);
    expect(find.text('2026-10-11 02:18 JST'), findsOneWidget);
    expect(find.text('¥1,000'), findsNWidgets(2));
    await tester.tap(find.text('閉じる'));
    await tester.pumpAndSettle();
    expect(find.text('残高日時 2026-10-11 17:44 JST'), findsOneWidget);
  });

  testWidgets(
      'retry keeps the same offset and displays older negative balances',
      (tester) async {
    final offsets = <int>[];
    await openHistory(tester, (offset) async {
      offsets.add(offset);
      if (offsets.length == 1) throw StateError('offline');
      return [observation(1, '2024-01-01T00:00:00Z', amount: -1234)];
    });
    expect(find.text('履歴を読み込めませんでした。'), findsOneWidget);
    await tester.tap(find.text('再試行'));
    await tester.pumpAndSettle();
    expect(offsets, [0, 0]);
    expect(find.text('2024-01-01 09:00 JST'), findsOneWidget);
    expect(find.text('¥-1,234'), findsOneWidget);
  });

  testWidgets('pages beyond fifty records without dropping a same-day row',
      (tester) async {
    final offsets = <int>[];
    await openHistory(tester, (offset) async {
      offsets.add(offset);
      if (offset == 0) {
        return [
          for (var id = 100; id > 50; id--)
            observation(id, '2026-10-11T08:44:00Z'),
        ];
      }
      return [observation(50, '2024-01-01T00:00:00Z')];
    });
    final more = find.text('さらに読み込む');
    await tester.scrollUntilVisible(
      more,
      500,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(more);
    await tester.pumpAndSettle();
    expect(offsets, [0, 50]);
    expect(more, findsNothing);
    expect(find.text('2024-01-01 09:00 JST'), findsOneWidget);
  });
}
