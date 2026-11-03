import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:my_web_app/widgets/asset_payroll_deductions_card.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const mobile = bool.fromEnvironment('PAYROLL_MOBILE');
  Future<void> show(
    WidgetTester tester,
    List<Map<String, dynamic>> rows,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(mobile ? 2 : 1),
            ),
            child: SingleChildScrollView(
              child: AssetPayrollDeductionsCard(
                ownerId: 'synthetic-owner',
                year: 2030,
                rows: rows,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    expect(tester.takeException(), isNull);
    await binding.takeScreenshot(name, {
      'width': tester.view.physicalSize.width / tester.view.devicePixelRatio,
      'height': tester.view.physicalSize.height / tester.view.devicePixelRatio,
      'devicePixelRatio': tester.view.devicePixelRatio,
    });
  }

  Map<String, dynamic> fixture() => {
        'id': 'synthetic-statement',
        'user_id': 'synthetic-owner',
        'pay_date': '2030-01-20',
        'review_status': 'confirmed',
        'gross_amount': 1000,
        'net_amount': 700,
        'social_insurance_total': 200,
        'deductions': {
          'income_tax': 50,
          'resident_tax': 40,
          'health_insurance': 70,
          'employees_pension_insurance': 100,
          'employment_insurance': 20,
          'long_term_care_insurance': 5,
          'employees_pension_fund_contribution': 5,
          'ideco': 10,
        },
      };

  testWidgets('confirmed source shows tax and social separately and recreates',
      (tester) async {
    await show(tester, [fixture()]);
    expect(find.text('税金の確認済み分：90円（1/12か月）'), findsOneWidget);
    expect(find.text('社会保険料の確認済み分：200円（1/12か月）'), findsOneWidget);
    await capture(
      tester,
      mobile ? 'payroll-confirmed-mobile' : 'payroll-confirmed-desktop',
    );
    await tester.pumpWidget(const SizedBox());
    await show(tester, [fixture()]);
    expect(find.text('税金の確認済み分：90円（1/12か月）'), findsOneWidget);
  });
  testWidgets('conflicting source remains review-required without totals',
      (tester) async {
    final correction = fixture()..['net_amount'] = 600;
    await show(tester, [fixture(), correction]);
    expect(find.text('同じ明細の内容が競合・要確認'), findsOneWidget);
    expect(find.text('税金の確認済み分：確定累計対象なし（0/12か月）'), findsOneWidget);
    await capture(
      tester,
      mobile ? 'payroll-conflict-mobile' : 'payroll-conflict-desktop',
    );
  });
  testWidgets('retrieved unconfirmed statement is not labelled missing',
      (tester) async {
    final automatic = fixture()..['review_status'] = 'auto';
    await show(tester, [automatic]);
    expect(find.textContaining('取得済み・本人未確認'), findsWidgets);
    expect(find.text('明細取得済み 1/12か月・本人未確認 1か月'), findsOneWidget);
    expect(find.text('税金の確認済み分：確定累計対象なし（0/12か月）'), findsOneWidget);
    await capture(
      tester,
      mobile ? 'payroll-unconfirmed-mobile' : 'payroll-unconfirmed-desktop',
    );
  });
  testWidgets('empty state does not invent zero deductions', (tester) async {
    await show(tester, []);
    expect(find.text('税金の確認済み分：確定累計対象なし（0/12か月）'), findsOneWidget);
    await capture(
      tester,
      mobile ? 'payroll-empty-mobile' : 'payroll-empty-desktop',
    );
  });
}
