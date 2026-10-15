import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/debt_progress_card_service.dart';
import 'package:my_web_app/widgets/debt_progress_card.dart';

void main() {
  for (final status in [
    DebtProgressProjectionStatus.unconfirmedTerms,
    DebtProgressProjectionStatus.insufficientPayment,
  ]) {
    testWidgets('390px card preserves projection evidence for $status',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final data = DebtProgressCardData(
        totalDebt: 100000,
        monthlyPayment: 1000,
        payoffMonths: null,
        estimatedInterest: null,
        monthOverMonthDelta: null,
        debtCount: 1,
        projectionStatus: status,
      );
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DebtProgressCard(data: data, month: DateTime(2026, 6)),
          ),
        ),
      ),);
      expect(find.text(data.projectionNote), findsOneWidget);
      expect(find.text('毎月の返済予定'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
