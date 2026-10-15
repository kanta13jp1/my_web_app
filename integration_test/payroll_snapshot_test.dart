import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'payroll_snapshot_fixture.dart' show SyntheticSnapshotStore, showForm, showSnapshot;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const mobile = bool.fromEnvironment('PAYROLL_MOBILE');
  testWidgets('explicit target save and unknown response never post a balance', (tester) async {
    final store = SyntheticSnapshotStore()..failTargetAfterCommit = true;
    await showSnapshot(tester, store, textScale: mobile ? 2 : 1);
    expect(find.text('前月比の増加目標：未設定'), findsOneWidget);
    final field = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.hintText == '例：10000',
    );
    await tester.enterText(field, '10000');
    await tester.ensureVisible(find.text('目標を保存・解除'));
    await tester.tap(find.text('目標を保存・解除'));
    await tester.pumpAndSettle();
    expect(store.targetWrites, 1);
    expect(store.writes, 0);
    await tester.ensureVisible(find.text('目標の現在値を照合'));
    await tester.tap(find.text('目標の現在値を照合'));
    await tester.pumpAndSettle();
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
    await binding.takeScreenshot(mobile ? 'payroll-goal-mobile' : 'payroll-goal-desktop', {
      'width': tester.view.physicalSize.width / tester.view.devicePixelRatio,
      'height': tester.view.physicalSize.height / tester.view.devicePixelRatio,
      'devicePixelRatio': tester.view.devicePixelRatio,
    });
  });
  testWidgets(
      'explicit preview and owner assertion save use synthetic storage only',
      (tester) async {
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
        });
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('確認して保存'));
    await tester.pumpAndSettle();
    expect(store.writes, 1);
    expect(find.text('本人確認の直後残高：120000円'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
