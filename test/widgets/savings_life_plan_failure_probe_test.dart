import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_web_app/models/savings_life_plan.dart';
import 'package:my_web_app/services/savings_life_plan_store.dart';
import 'package:my_web_app/widgets/savings_life_plan_card.dart';

class FailingStore extends SavingsLifePlanStore {
  FailingStore() : super('failure-fixture');
  int calls = 0;
  @override
  Future<void> save(SavingsLifePlan plan) async {
    calls++;
    if (calls == 1) throw StateError('synthetic save failure');
    await super.save(plan);
  }
}

void main() {
  testWidgets('save failure retains input and old plan; retry persists once',
      (tester) async {
    const key = 'savings_life_plan_v1:failure-fixture';
    final original = jsonEncode({
      'version': 2,
      'start': '2026-10-13',
      'targetDate': '2027-10-13',
      'target': 1000000,
      'reserve': 0,
    });
    SharedPreferences.setMockInitialValues({
      key: original,
      'financial_records': 'untouched',
    });
    final store = FailingStore();
    Widget screen() => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SavingsLifePlanCard(
            userId: 'failure-fixture',
            today: DateTime(2026, 10, 13),
            monthlyCommitments: 200000,
            commitmentsEstimated: true,
            suggestedIncome: 400000,
            onReviewPayments: () {},
            store: store,
          ),
        ),
      ),
    );
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), '400000');
    await tester.enterText(find.byType(TextFormField).at(2), '50000');
    final income = find.byKey(const Key('savings-plan-income'));
    await tester.enterText(income, '390000');
    final save = find.text('計画を保存・再計算');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(store.calls, 1);
    expect(find.text('保存できませんでした。入力は保持しています。再試行してください。'),
        findsOneWidget);
    expect(prefs.getString(key), original);
    expect(tester.widget<TextFormField>(income).controller!.text, '390000');
    expect(prefs.getString('financial_records'), 'untouched');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(store.calls, 2);
    expect(jsonDecode(prefs.getString(key)!)['income'], 390000);
    expect(prefs.getString('financial_records'), 'untouched');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(income).controller!.text, '390000');
    expect(store.calls, 2);
    expect(tester.takeException(), isNull);
  });
}
