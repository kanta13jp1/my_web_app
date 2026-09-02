import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/debt_progress_card_service.dart';
import 'package:my_web_app/widgets/debt_progress_card.dart';

void main() {
  DebtProgressCardData cardData({
    int? payoffMonths = 38,
    double? interest = 234567,
    double? delta = -50000,
  }) =>
      DebtProgressCardData(
        totalDebt: 1234567,
        monthlyPayment: 45000,
        payoffMonths: payoffMonths,
        estimatedInterest: interest,
        monthOverMonthDelta: delta,
        debtCount: 3,
      );

  Future<void> pump(WidgetTester tester, DebtProgressCardData data) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: DebtProgressCard(data: data, month: DateTime(2026, 7, 1)),
          ),
        ),
      ),
    );
  }

  testWidgets('renders the disclosed figures', (tester) async {
    await pump(tester, cardData());

    expect(find.text('2026年7月の返済報告'), findsOneWidget);
    expect(find.text('1,234,567円'), findsOneWidget);
    expect(find.text('45,000円'), findsOneWidget);
    expect(find.text('あと3年2ヶ月'), findsOneWidget);
    expect(find.text('234,567円'), findsOneWidget);
    expect(find.text('返済中 3件'), findsOneWidget);
  });

  testWidgets('shows a decrease in green and an increase in red', (
    tester,
  ) async {
    // 借金は減る方が良い。増加を緑にすると悪化を好調に見せてしまう。
    await pump(tester, cardData(delta: -50000));
    final decrease = tester.widget<Text>(find.text('−50,000円'));
    expect(decrease.style?.color, const Color(0xFF4ADE80));

    await pump(tester, cardData(delta: 30000));
    final increase = tester.widget<Text>(find.text('+30,000円'));
    expect(increase.style?.color, const Color(0xFFF87171));
  });

  testWidgets('flags a non-clearing payment instead of hiding it', (
    tester,
  ) async {
    await pump(tester, cardData(payoffMonths: null, interest: null));

    expect(find.text('— (要見直し)'), findsOneWidget);
    // 完済しないときに利息見込みを出すと、実際より小さい額を約束してしまう。
    expect(find.text('利息見込み'), findsNothing);
  });

  testWidgets('omits the delta chip when there is no prior month', (
    tester,
  ) async {
    await pump(tester, cardData(delta: null));

    expect(find.textContaining('前月比'), findsNothing);
    expect(find.textContaining('−'), findsNothing);
  });
}
