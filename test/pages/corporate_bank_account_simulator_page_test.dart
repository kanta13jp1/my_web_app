import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/corporate_bank_account_simulator_page.dart';
import 'package:my_web_app/services/corporate_bank_account_cost_service.dart';

void main() {
  testWidgets('renders simulator inputs, chart, and comparison rows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: CorporateBankAccountSimulatorPage(
          service: CorporateBankAccountCostService(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('法人口座コスト試算'), findsOneWidget);
    expect(find.text('入力条件'), findsOneWidget);
    expect(find.text('年間コスト比較'), findsOneWidget);
    expect(find.text('比較明細'), findsOneWidget);
    expect(find.textContaining('GMOあおぞらネット銀行'), findsWidgets);
    expect(find.textContaining('住信SBIネット銀行'), findsWidgets);
    expect(find.textContaining('Finswer Bank'), findsWidgets);
    expect(find.text('最適候補'), findsOneWidget);
  });
}
