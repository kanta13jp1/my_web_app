import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/asset_payroll_snapshot_connection.dart';

import '../../integration_test/payroll_snapshot_fixture.dart';

class _OwnerBStore extends SyntheticSnapshotStore {
  @override
  String get ownerId => 'synthetic-owner-b';
}

void main() {
  testWidgets('probe: an open confirmation route remains after owner switch',
      (tester) async {
    final owner = ValueNotifier<String?>('synthetic-owner');
    addTearDown(owner.dispose);
    final storeA = SyntheticSnapshotStore();
    final storeB = _OwnerBStore();
    final builtOwners = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ValueListenableBuilder<String?>(
            valueListenable: owner,
            builder: (context, value, _) => AssetPayrollSnapshotConnection(
              ownerId: value,
              initialMonth: DateTime(2020),
              createStore: (id) {
                builtOwners.add(id);
                return id == 'synthetic-owner' ? storeA : storeB;
              },
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), '2020-01-25');
    await tester.enterText(find.byType(TextFormField).at(1), '120000');
    await tester.enterText(find.byType(TextFormField).at(2), '架空の資料');
    await tester.ensureVisible(find.text('保存前の確認へ'));
    await tester.tap(find.text('保存前の確認へ'));
    await tester.pumpAndSettle();
    expect(find.text('入金直後残高：120000円'), findsOneWidget);
    owner.value = 'synthetic-owner-b';
    await tester.pumpAndSettle();
    expect(builtOwners.last, 'synthetic-owner-b');
    expect(
      find.byKey(const ValueKey('payroll-confirmed-snapshot-synthetic-owner-b'),
          skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('payroll-confirmed-snapshot-synthetic-owner'),
          skipOffstage: false),
      findsNothing,
    );
    // This probe intentionally records the potentially unsafe old behavior;
    // success means the synthetic leak reproduced, not that it is fixed.
    expect(find.text('入金直後残高：120000円'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(storeA.writes, 0);
    expect(storeB.writes, 0);
    expect(tester.takeException(), isNull);
  });
}
