import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_web_app/widgets/savings_life_plan_card.dart';

void main() {
  Future<void> open(WidgetTester tester,
      {int income = 400000, int commitments = 200000}) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: SavingsLifePlanCard(
      userId: 'fixture',
      today: DateTime(2026, 10, 13),
      monthlyCommitments: commitments,
      commitmentsEstimated: true,
      suggestedIncome: income,
      onReviewPayments: () {},
    ),),),),);
    await tester.pumpAndSettle();
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('saving confirms final savings goal; reload preserves anchors',
      (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextFormField).at(0), '400000');
    await tester.enterText(find.byType(TextFormField).at(2), '50000');
    await tester.ensureVisible(find.text('計画を保存・再計算'));
    await tester.tap(find.text('計画を保存・再計算'));
    await tester.pumpAndSettle();
    expect(find.text('必要な積立：月 ¥50,000'), findsOneWidget);
    expect(find.text('2026-10-13 → 2027-10-13'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await open(tester);
    expect(find.text('必要な積立：月 ¥50,000'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('missing savings and zero living costs cannot fabricate a plan',
      (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextFormField).at(2), '0');
    await tester.ensureVisible(find.text('計画を保存・再計算'));
    await tester.tap(find.text('計画を保存・再計算'));
    await tester.pumpAndSettle();
    expect(find.textContaining('生活に必要な1円以上'), findsOneWidget);
    expect(find.textContaining('必要な積立：'), findsNothing);
  });
  testWidgets('deficit suppresses daily spending allowance', (tester) async {
    await open(tester, income: 300000, commitments: 240000);
    await tester.enterText(find.byType(TextFormField).at(0), '0');
    await tester.enterText(find.byType(TextFormField).at(2), '60000');
    await tester.ensureVisible(find.text('計画を保存・再計算'));
    await tester.tap(find.text('計画を保存・再計算'));
    await tester.pumpAndSettle();
    expect(find.textContaining('現計画では月 ¥83,334 不足'), findsOneWidget);
    expect(find.textContaining('生活費の日割り目安'), findsNothing);
    expect(find.textContaining('朝食・食器洗い・歯磨き'), findsOneWidget);
  });
}
