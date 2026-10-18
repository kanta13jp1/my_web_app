import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_web_app/widgets/savings_life_plan_card.dart';

void main() {
  Future<void> open(
    WidgetTester tester, {
    int income = 400000,
    int commitments = 200000,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SavingsLifePlanCard(
              userId: 'fixture',
              today: DateTime(2026, 10, 13),
              monthlyCommitments: commitments,
              commitmentsEstimated: true,
              suggestedIncome: income,
              onReviewPayments: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(
    () => SharedPreferences.setMockInitialValues({
      'savings_life_plan_v1:fixture': jsonEncode({
        'version': 2,
        'start': '2026-10-13',
        'targetDate': '2027-10-13',
        'target': 1000000,
        'reserve': 0,
      }),
    }),
  );
  testWidgets('new user has no personal goal; amount and deadline are required',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await open(tester);
    expect(find.text('貯蓄目標と生活費の計画'), findsOneWidget);
    expect(find.textContaining('同棲'), findsNothing);
    expect(find.textContaining('目標は未設定'), findsOneWidget);
    expect(find.text('目標期限を設定'), findsOneWidget);
    expect(find.textContaining('必要な積立：'), findsNothing);
    await tester.enterText(find.byType(TextFormField).at(0), '400000');
    await tester.enterText(find.byType(TextFormField).at(2), '50000');
    await tester.enterText(find.byType(TextFormField).at(5), '250000');
    await tester.ensureVisible(find.text('計画を保存・再計算'));
    await tester.tap(find.text('計画を保存・再計算'));
    await tester.pumpAndSettle();
    expect(find.text('目標期限を選択してください。'), findsOneWidget);
  });
  testWidgets('saving confirms final savings goal; reload preserves anchors',
      (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextFormField).at(0), '400000');
    await tester.enterText(find.byType(TextFormField).at(2), '50000');
    await tester.ensureVisible(find.text('計画を保存・再計算'));
    await tester.tap(find.text('計画を保存・再計算'));
    await tester.pumpAndSettle();
    expect(find.text('必要な積立：月 ¥70,834'), findsOneWidget);
    expect(find.text('2026-10-13 → 2027-10-13'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await open(tester);
    expect(find.text('必要な積立：月 ¥70,834'), findsOneWidget);
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
    expect(find.textContaining('現計画では月 ¥108,334 不足'), findsOneWidget);
    expect(find.textContaining('生活費の日割り目安'), findsNothing);
    expect(find.textContaining('朝食・食器洗い・歯磨き'), findsOneWidget);
  });
  testWidgets('edited income survives parent updates, save and reload without other writes',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('financial_records', 'unchanged');
    await prefs.setString('recurring_income_templates', 'unchanged');
    final before = {for (final key in prefs.getKeys()) key: prefs.get(key)};
    await open(tester);
    final income = find.byKey(const Key('savings-plan-income'));
    await tester.enterText(income, '390000');
    await open(tester, income: 395000);
    expect(tester.widget<TextFormField>(income).controller!.text, '390000');
    await tester.enterText(find.byType(TextFormField).at(0), '400000');
    await tester.enterText(find.byType(TextFormField).at(2), '50000');
    await tester.ensureVisible(find.text('計画を保存・再計算'));
    await tester.tap(find.text('計画を保存・再計算'));
    await tester.pumpAndSettle();
    final saved = jsonDecode(prefs.getString('savings_life_plan_v1:fixture')!)
        as Map<String, dynamic>;
    expect(saved['income'], 390000);
    expect(saved['start'], '2026-10-13');
    expect(saved['targetDate'], '2027-10-13');
    for (final entry in before.entries) {
      if (entry.key != 'savings_life_plan_v1:fixture') {
        expect(prefs.get(entry.key), entry.value);
      }
    }
    expect(prefs.getKeys(), before.keys.toSet());
    await tester.pumpWidget(const SizedBox());
    await open(tester);
    expect(tester.widget<TextFormField>(income).controller!.text, '390000');
    expect(find.text('必要な積立：月 ¥70,834'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('income above the confirmed ceiling cannot be saved', (tester) async {
    await open(tester);
    final prefs = await SharedPreferences.getInstance();
    final before = prefs.getString('savings_life_plan_v1:fixture');
    await tester.enterText(find.byType(TextFormField).at(0), '400000');
    await tester.enterText(find.byType(TextFormField).at(2), '50000');
    await tester.enterText(find.byKey(const Key('savings-plan-income')), '400001');
    await tester.ensureVisible(find.text('計画を保存・再計算'));
    await tester.tap(find.text('計画を保存・再計算'));
    await tester.pumpAndSettle();
    expect(find.text('登録済みの手取り以下の金額を入力してください'), findsOneWidget);
    expect(prefs.getString('savings_life_plan_v1:fixture'), before);
  });

}
