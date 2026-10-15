import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../integration_test/payroll_snapshot_fixture.dart';
import 'package:my_web_app/services/asset_payroll_snapshot_store.dart';

class ComparableStore extends SyntheticSnapshotStore {
  @override
  Future<PayrollSnapshotRecord?> selected(String accountId, DateTime month) async {
    return PayrollSnapshotRecord(
      id: 'selected-${month.month}',
      ownerId: ownerId,
      accountId: accountId,
      month: month,
      depositDate: DateTime(month.year, month.month, 25),
      balanceYen: month.month == 1 ? 111000 : 100000,
      note: 'synthetic owner-confirmed day observation',
    );
  }
}

Finder targetField() => find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.hintText == '例：10000',
    );
Future<void> saveGoal(WidgetTester tester, String value) async {
  await tester.enterText(targetField(), value);
  await tester.ensureVisible(find.text('目標を保存・解除'));
  await tester.tap(find.text('目標を保存・解除'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('selected consecutive day records show the configured target reached', (tester) async {
    final store = ComparableStore()..target = 10000;
    await showSnapshot(tester, store);
    expect(find.text('前月との差：11000円'), findsOneWidget);
    expect(find.text('前月比の増加目標：10000円'), findsOneWidget);
    expect(find.text('目標判定：達成'), findsOneWidget);
    expect(store.targetWrites, 0);
    expect(store.writes, 0);
  });
  testWidgets('stale expected target never overwrites a concurrent setting',
      (tester) async {
    final store = SyntheticSnapshotStore();
    await showSnapshot(tester, store);
    store.target = 20000;
    await saveGoal(tester, '10000');
    expect(store.targetWrites, 0);
    expect(store.target, 20000);
    await tester.ensureVisible(find.text('目標の現在値を照合'));
    await tester.tap(find.text('目標の現在値を照合'));
    await tester.pumpAndSettle();
    expect(find.text('前月比の増加目標：20000円'), findsOneWidget);
    expect(store.targetWrites, 0);
  });
  testWidgets('target remains unset until explicit save and can be cleared',
      (tester) async {
    final store = SyntheticSnapshotStore();
    await showSnapshot(tester, store);
    expect(find.text('前月比の増加目標：未設定'), findsOneWidget);
    expect(store.targetWrites, 0);
    await saveGoal(tester, '10000');
    expect(find.text('前月比の増加目標：10000円'), findsOneWidget);
    expect(store.targetWrites, 1);
    expect(store.writes, 0);
    await saveGoal(tester, '');
    expect(store.target, isNull);
    expect(store.targetWrites, 2);
  });
  testWidgets(
      'unknown response reconciles current value without resend or success claim',
      (tester) async {
    final store = SyntheticSnapshotStore()..failTargetAfterCommit = true;
    await showSnapshot(tester, store);
    await saveGoal(tester, '10000');
    expect(store.targetWrites, 1);
    expect(find.textContaining('目標の更新結果が不明'), findsOneWidget);
    expect(tester.widget<TextField>(targetField()).enabled, isFalse);
    store.failTargetReads = true;
    await tester.ensureVisible(find.text('目標の現在値を照合'));
    await tester.tap(find.text('目標の現在値を照合'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(targetField()).enabled, isFalse);
    store.failTargetReads = false;
    store.target = 20000;
    await tester.tap(find.text('目標の現在値を照合'));
    await tester.pumpAndSettle();
    expect(find.textContaining('今回の更新の成否は確定できません'), findsOneWidget);
    expect(find.text('前月比の増加目標：20000円'), findsOneWidget);
    expect(store.targetWrites, 1);
    await saveGoal(tester, '20000');
    expect(store.targetWrites, 1);
    expect(store.writes, 0);
  });
  testWidgets('zero is explicit while invalid targets never write',
      (tester) async {
    final store = SyntheticSnapshotStore();
    await showSnapshot(tester, store);
    for (final value in ['-1', '1.5', '9007199254740992']) {
      await saveGoal(tester, value);
      expect(store.targetWrites, 0);
    }
    await saveGoal(tester, '0');
    expect(find.text('前月比の増加目標：0円'), findsOneWidget);
    expect(find.text('目標判定：比較対象未取得'), findsOneWidget);
    expect(store.targetWrites, 1);
  });
}
