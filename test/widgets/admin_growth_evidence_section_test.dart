import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/admin_growth_evidence.dart';
import 'package:my_web_app/widgets/admin_growth_evidence_section.dart';

void main() {
  Widget testApp({
    List<AdminAcquisitionCohortEvidence> acquisitionEvidence = const [],
    List<AdminPlanEconomics> planEconomics = const [],
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: AdminGrowthEvidenceSection(
            acquisitionEvidence: acquisitionEvidence,
            planEconomics: planEconomics,
          ),
        ),
      ),
    );
  }

  testWidgets('shows explicit missing-input states', (tester) async {
    await tester.pumpWidget(testApp());

    expect(find.byKey(const Key('acquisition_evidence_empty')), findsOneWidget);
    expect(find.textContaining('判断保留：獲得元'), findsOneWidget);
    expect(find.byKey(const Key('plan_economics_empty')), findsOneWidget);
    expect(find.textContaining('判断保留：プラン別'), findsOneWidget);
    expect(find.textContaining('AI・その他変動費'), findsWidgets);
  });

  testWidgets('renders complete cohort and unit-economics decisions', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        acquisitionEvidence: const [
          AdminAcquisitionCohortEvidence(
            source: 'google',
            acquiredUsers: 50,
            day7EligibleUsers: 40,
            day7RetainedUsers: 20,
            day30EligibleUsers: 25,
            day30RetainedUsers: 10,
            paidConvertedUsers: 5,
          ),
        ],
        planEconomics: const [
          AdminPlanEconomics(
            planName: 'Pro',
            monthlyRevenueYen: 100000,
            paidCustomers: 20,
            monthlyAiVariableCostYen: 20000,
            monthlyOtherVariableCostYen: 0,
            monthlyAcquisitionSpendYen: 30000,
            newPaidCustomers: 10,
            beginningPaidCustomers: 20,
            churnedCustomers: 2,
          ),
        ],
      ),
    );

    expect(find.text('google'), findsOneWidget);
    expect(find.text('D7 50.0%'), findsOneWidget);
    expect(find.text('D30 40.0%'), findsOneWidget);
    expect(find.text('有料転換 10.0%'), findsOneWidget);
    expect(find.text('Pro'), findsOneWidget);
    expect(find.text('AI変動費 ¥20,000'), findsOneWidget);
    expect(find.text('その他変動費 ¥0'), findsOneWidget);
    expect(find.text('粗利 ¥80,000'), findsOneWidget);
    expect(find.text('粗利率 80.0%'), findsOneWidget);
    expect(find.text('CAC ¥3,000'), findsOneWidget);
    expect(find.text('回収月数 0.8か月'), findsOneWidget);
    expect(find.text('月次解約率 10.0%'), findsOneWidget);
    expect(find.text('LTV ¥40,000'), findsOneWidget);
    expect(find.textContaining('未取得：'), findsNothing);
  });

  testWidgets('labels aggregate source signals as incomplete cohort evidence', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        acquisitionEvidence: adminAcquisitionEvidenceFromAggregateSignals({
          'direct': 12,
        }),
      ),
    );

    expect(find.text('集計信号 12'), findsOneWidget);
    expect(find.text('D7 —'), findsOneWidget);
    expect(find.text('D30 —'), findsOneWidget);
    expect(find.text('有料転換 —'), findsOneWidget);
    expect(find.textContaining('ユーザーコホート人数として扱いません'), findsOneWidget);
  });
}
