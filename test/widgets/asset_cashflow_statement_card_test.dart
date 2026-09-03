import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_cashflow_statement_service.dart';
import 'package:my_web_app/widgets/asset_cashflow_statement_card.dart';

AssetLiabilityMonthlySnapshot _snapshot(
  String monthKey, {
  double? income,
  double expense = 0,
  required double netWorth,
}) {
  return AssetLiabilityMonthlySnapshot(
    monthKey: monthKey,
    savedAt: DateTime(2026, 1, 1),
    positiveAssetTotal: 0,
    liabilityTotal: 0,
    netWorth: netWorth,
    cashLikeTotal: 0,
    monthlyScheduledPaymentTotal: 0,
    monthlyPaidPaymentTotal: expense,
    monthlyUnpaidPaymentTotal: 0,
    overduePaymentCount: 0,
    monthlyReceivedIncomeTotal: income,
  );
}

AssetCashflowStatement _statementWithEstimate() {
  return const AssetCashflowStatementService().build(
    snapshots: [
      _snapshot('2026-05', netWorth: -1000),
      _snapshot('2026-06', netWorth: -1200),
      _snapshot(
        '2026-07',
        income: 500,
        expense: 300,
        netWorth: -1100,
      ),
    ],
    asOf: DateTime(2026, 7, 15),
  );
}

Widget _app(double width) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: width,
        child: AssetCashflowStatementCard(
          statement: _statementWithEstimate(),
          currencyFormatter: (value) => '¥${value.round()}',
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows net worth delta as an explicitly labeled estimate', (
    tester,
  ) async {
    await tester.pumpWidget(_app(720));

    expect(
      find.byKey(
        const Key('asset_cashflow_statement_estimate_2026-06'),
      ),
      findsOneWidget,
    );
    expect(
      find.text('純資産差からの推定CF（評価損益・口座追加等を含む）'),
      findsOneWidget,
    );
    expect(find.text('≈-¥200'), findsOneWidget);
    expect(
      find.byKey(
        const Key('asset_cashflow_statement_amount_2026-05'),
      ),
      findsOneWidget,
    );
    expect(find.text('—'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('estimated row stays readable at a narrow card width', (
    tester,
  ) async {
    await tester.pumpWidget(_app(320));

    expect(find.text('≈-¥200'), findsOneWidget);
    expect(
      find.text('純資産差からの推定CF（評価損益・口座追加等を含む）'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}