import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_waste_training_snapshot_inputs.dart';
import 'package:my_web_app/widgets/asset_waste_observation_status.dart';

void main() {
  for (final width in [1200.0, 390.0]) {
    testWidgets('observation status empty sparse recovery at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Future<void> render(List<Map<String, dynamic>> flows) async {
        final snapshot = AssetWasteTrainingSnapshotInputs.build(
          monthFlows: flows,
          now: DateTime(2026, 6, 15),
          isExpense: (type) => type == 'expense',
          wasteCategoryOf: (_, __) => null,
          ruleCompletedCount: 0,
          ruleTargetCount: 5,
          todayViolationCount: 0,
          compliantStreakDays: 0,
          lockdownActive: false,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: AssetWasteObservationStatus(snapshot: snapshot)),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.textContaining('未記録日の支出・浪費の有無は不明'), findsOneWidget);
      }

      await render([]);
      expect(find.textContaining('記録不足・採点なし'), findsOneWidget);
      expect(find.textContaining('0/15日'), findsOneWidget);
      await render([
        {
          'action_type': 'expense',
          'amount': 100,
          'occurred_at': '2026-06-10T09:00:00'
        },
      ]);
      expect(find.textContaining('記録ベースの参考値'), findsOneWidget);
      expect(find.textContaining('1/15日'), findsOneWidget);
      await render([]);
      expect(find.textContaining('記録不足・採点なし'), findsOneWidget);
      expect(find.textContaining('1/15日'), findsNothing);
    });
  }
}
