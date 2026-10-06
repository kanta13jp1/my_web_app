import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';
import 'package:my_web_app/widgets/revolving_extra_payment_dialog.dart';

void main() {
  testWidgets('typing an extra amount shows months and interest saved',
      (tester) async {
    final workbook = const AssetLiabilityPlanningService().buildWorkbook(
      latestSnapshot: const <String, double>{
        'bank': 500000,
        'ファミペイ': -100000,
      },
      baseDate: DateTime(2026, 6, 1),
      monthlyPaymentOverrides: const <String, double>{'ファミペイ': 10000},
    );
    final row = workbook.debtMasterRows.firstWhere(
      (r) => r.name == 'ファミペイ',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: RevolvingExtraPaymentDialog(row: row)),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('revolving_extra_payment_input')),
      '5000',
    );
    await tester.pump();
    final summary = tester.widget<Text>(
      find.byKey(const Key('revolving_extra_payment_summary')),
    );
    expect(summary.data, contains('早まり'));
    expect(summary.data, contains('利息'));
  });
}
