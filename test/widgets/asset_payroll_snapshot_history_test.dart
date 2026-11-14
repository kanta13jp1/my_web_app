import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_payroll_snapshot_history.dart';
import 'package:my_web_app/services/asset_payroll_snapshot_store.dart';
import 'package:my_web_app/widgets/asset_payroll_snapshot_history.dart';

class _Reader implements PayrollSnapshotHistoryReader {
  _Reader({this.ownerId = 'owner-a'});
  @override
  final String ownerId;
  final responses = <Future<PayrollSnapshotHistoryPage>>[];
  final calls = <String>[];
  @override
  Future<PayrollSnapshotHistoryPage> read(String accountId, DateTime month) {
    calls.add('$accountId/${month.month}');
    return responses.removeAt(0);
  }
}

PayrollSnapshotHistoryPage _page({String owner = 'owner-a'}) =>
    PayrollSnapshotHistoryPage([
      PayrollSnapshotHistoryEntry(
        id: 2,
        previousId: 'old-observation',
        reason: '本人から入金直後の額を訂正',
        changedAt: DateTime.utc(2026, 10, 25, 1),
        record: PayrollSnapshotRecord(
          id: 'new-observation',
          balanceYen: 12345,
          ownerId: owner,
          accountId: 'account-a',
          month: DateTime(2026, 10),
          depositDate: DateTime(2026, 10, 23),
          note: '本人確認メモ',
        ),
      ),
    ], hasMore: true);

Widget _app(_Reader reader, {int month = 10}) => MaterialApp(
      home: Scaffold(
        body: AssetPayrollSnapshotHistory(
          reader: reader,
          accountId: 'account-a',
          month: DateTime(2026, month),
        ),
      ),
    );

void main() {
  testWidgets('history is opt-in and displays reason and truncation honestly',
      (tester) async {
    final reader = _Reader()..responses.add(Future.value(_page()));
    await tester.pumpWidget(_app(reader));
    expect(reader.calls, isEmpty);
    await tester.tap(find.text('訂正履歴を読み込む'));
    await tester.pumpAndSettle();
    expect(reader.calls, ['account-a/10']);
    expect(find.textContaining('訂正・12345円'), findsOneWidget);
    expect(find.textContaining('本人から入金直後の額を訂正'), findsOneWidget);
    expect(find.textContaining('最新50件'), findsOneWidget);
    expect(find.textContaining('銀行検証済みではありません'), findsOneWidget);
  });

  testWidgets('old month response is discarded after selection changes',
      (tester) async {
    final pending = Completer<PayrollSnapshotHistoryPage>();
    final reader = _Reader()..responses.add(pending.future);
    await tester.pumpWidget(_app(reader));
    await tester.tap(find.text('訂正履歴を読み込む'));
    await tester.pump();
    await tester.pumpWidget(_app(reader, month: 11));
    pending.complete(_page());
    await tester.pumpAndSettle();
    expect(find.textContaining('12345円'), findsNothing);
    expect(find.text('訂正履歴を読み込む'), findsOneWidget);
  });

  testWidgets('old owner response is discarded after account session changes',
      (tester) async {
    final pending = Completer<PayrollSnapshotHistoryPage>();
    final oldReader = _Reader()..responses.add(pending.future);
    await tester.pumpWidget(_app(oldReader));
    await tester.tap(find.text('訂正履歴を読み込む'));
    await tester.pump();
    await tester.pumpWidget(_app(_Reader(ownerId: 'owner-b')));
    pending.complete(_page());
    await tester.pumpAndSettle();
    expect(find.textContaining('12345円'), findsNothing);
    expect(find.text('訂正履歴を読み込む'), findsOneWidget);
  });

  testWidgets('transport failure is not empty history and permits retry',
      (tester) async {
    final pending = Completer<PayrollSnapshotHistoryPage>();
    final reader = _Reader()
      ..responses.add(pending.future)
      ..responses.add(Future.value(_page()));
    await tester.pumpWidget(_app(reader));
    await tester.tap(find.text('訂正履歴を読み込む'));
    await tester.pump();
    pending.completeError(StateError('network unavailable'));
    await tester.pumpAndSettle();
    expect(find.textContaining('読み込めませんでした'), findsOneWidget);
    expect(find.textContaining('履歴はありません'), findsNothing);
    await tester.tap(find.text('訂正履歴を読み込む'));
    await tester.pumpAndSettle();
    expect(find.textContaining('訂正・12345円'), findsOneWidget);
    expect(find.textContaining('読み込めませんでした'), findsNothing);
  });

  testWidgets('foreign owner result is withheld and empty retry is distinct',
      (tester) async {
    final reader = _Reader()
      ..responses.add(Future.value(_page(owner: 'owner-b')))
      ..responses.add(Future.value(
        const PayrollSnapshotHistoryPage([], hasMore: false),
      ));
    await tester.pumpWidget(_app(reader));
    await tester.tap(find.text('訂正履歴を読み込む'));
    await tester.pumpAndSettle();
    expect(find.textContaining('12345円'), findsNothing);
    expect(find.textContaining('読み込めませんでした'), findsOneWidget);
    expect(find.textContaining('履歴はありません'), findsNothing);
    await tester.tap(find.text('訂正履歴を読み込む'));
    await tester.pumpAndSettle();
    expect(find.textContaining('読み込めませんでした'), findsNothing);
    expect(find.textContaining('履歴はありません'), findsOneWidget);
  });
}
