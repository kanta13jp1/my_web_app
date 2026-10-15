import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/asset_payroll_deductions_card.dart';

void main() {
  testWidgets(
    'empty months remain missing on narrow enlarged-text layout',
    (tester) async {
      tester.view.physicalSize = const Size(
        320,
        900,
      );
      tester.view.devicePixelRatio = 1;
      addTearDown(
        tester.view.resetPhysicalSize,
      );
      addTearDown(
        tester.view.resetDevicePixelRatio,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: ListView(
                children: const [
                  AssetPayrollDeductionsCard(
                    ownerId: 'owner-a',
                    year: 2030,
                    rows: [],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(
        find.text('税金の確認済み分：未取得（0/12か月）'),
        findsOneWidget,
      );
      expect(
        find.text('社会保険料の確認済み分：未取得（0/12か月）'),
        findsOneWidget,
      );
      expect(
        tester.takeException(),
        isNull,
      );
    },
  );

  testWidgets(
    'automatic extraction is visible but not a confirmed annual total',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: const [
                AssetPayrollDeductionsCard(
                  ownerId: 'owner-a',
                  year: 2030,
                  rows: [
                    {
                      'id': 'synthetic',
                      'user_id': 'owner-a',
                      'pay_date': '2030-01-20',
                      'review_status': 'auto',
                      'deductions': {'income_tax': 0, 'resident_tax': 0},
                    },
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(
        find.text('1月'),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('明細1・1/20支給・読取内容は未確認'),
        findsOneWidget,
      );
      expect(
        find.text('所得税：0円'),
        findsOneWidget,
      );
      expect(
        find.text('健康保険：未取得'),
        findsOneWidget,
      );
      expect(
        find.text('税金の確認済み分：未取得（0/12か月）'),
        findsOneWidget,
      );
      expect(
        tester.takeException(),
        isNull,
      );
    },
  );
  testWidgets('zero residual does not claim unclassified details are complete',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ListView(children: const [
      AssetPayrollDeductionsCard(ownerId: 'owner-a', year: 2030, rows: [
        {
          'id': 'synthetic-unknown',
          'user_id': 'owner-a',
          'pay_date': '2030-01-20',
          'review_status': 'auto',
          'gross_amount': 1000,
          'net_amount': 700,
          'social_insurance_total': 300,
          'deductions': {'unknown_social_component': 20},
        }
      ]),
    ]))));
    await tester.tap(find.text('1月'));
    await tester.pumpAndSettle();
    expect(find.text('記載済み控除小計との差：0円'), findsOneWidget);
    expect(find.text('内訳の分類状態：未分類 1項目'), findsOneWidget);
    expect(find.textContaining('差が0円でも内訳の分類完了を意味しません'), findsOneWidget);
    expect(find.text('社会保険料の確認済み分：未取得（0/12か月）'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
