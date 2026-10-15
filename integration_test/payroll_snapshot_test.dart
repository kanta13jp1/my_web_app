import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'payroll_snapshot_fixture.dart' show SyntheticSnapshotStore, showForm;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const mobile = bool.fromEnvironment('PAYROLL_MOBILE');
  testWidgets(
      'explicit preview and owner assertion save use synthetic storage only',
      (tester) async {
    final store = SyntheticSnapshotStore();
    await showForm(tester, store, textScale: mobile ? 2 : 1);
    expect(store.writes, 0);
    expect(find.text('給与入金直後の残高を確認'), findsOneWidget);
    expect(tester.takeException(), isNull);
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
