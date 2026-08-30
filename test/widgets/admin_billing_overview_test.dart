import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/admin_growth_evidence.dart';
import 'package:my_web_app/widgets/admin_billing_overview.dart';

void main() {
  Widget testApp(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  List<String> richTextValues(WidgetTester tester) {
    return tester
        .widgetList<RichText>(find.byType(RichText))
        .map((widget) => widget.text.toPlainText())
        .toList();
  }

  testWidgets('paid conversion card preserves the extracted summary', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        const AdminPaidConversionCard(
          metrics: AdminPaidConversionMetrics(
            paidCustomers: 2,
            mrrYen: 3960,
          ),
          totalUsers: 20,
        ),
      ),
    );

    final values = richTextValues(tester);
    expect(find.text('有料転換'), findsOneWidget);
    expect(values, contains('課金ユーザー数 2'));
    expect(values, contains('MRR ¥3,960'));
    expect(values, contains('free→paid CVR 10.0%'));
    expect(values, contains('登録総数 20'));
  });

  testWidgets('billing funnel card preserves counts and safe rates', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        const AdminBillingFunnelCard(
          metrics: AdminBillingFunnelMetrics(
            billingViews: 30,
            upgradeClicks: 9,
            checkoutSuccesses: 6,
            checkoutCancels: 2,
          ),
        ),
      ),
    );

    final values = richTextValues(tester);
    expect(find.byKey(const Key('billing_funnel_card')), findsOneWidget);
    expect(values, contains('課金ページ表示 30'));
    expect(values, contains('アップグレードクリック 9'));
    expect(values, contains('決済成功 6'));
    expect(values, contains('決済キャンセル 2'));
    expect(values, contains('表示→クリック 30.0%'));
    expect(values, contains('クリック→成功 66.7%'));
  });

  testWidgets('billing cards show an em dash for an unmeasured rate', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        const AdminPaidConversionCard(
          metrics: AdminPaidConversionMetrics.empty,
          totalUsers: 0,
        ),
      ),
    );

    expect(richTextValues(tester), contains('free→paid CVR —'));
  });
}
