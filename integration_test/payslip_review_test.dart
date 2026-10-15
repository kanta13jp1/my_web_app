import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:my_web_app/widgets/asset_payroll_deductions_card.dart';
import 'package:my_web_app/widgets/asset_payslip_review_dialog.dart';
import 'payslip_review_fixture.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const mobile = bool.fromEnvironment('PAYSLIP_REVIEW_MOBILE');
  Future<void> showCard(WidgetTester tester, SyntheticPayslipReviewStore store) async {
    addTearDown(() async { await tester.pumpWidget(const SizedBox()); await store.dispose(); });
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(mobile ? 2 : 1)), child: child!,
      ),
      home: Scaffold(body: StatefulBuilder(builder: (context, refresh) => SingleChildScrollView(
        child: AssetPayrollDeductionsCard(
          ownerId: store.ownerId, year: 2030, rows: [store.data],
          onReview: (id) async {
            await showDialog<void>(context: context, barrierDismissible: false,
              builder: (_) => AssetPayslipReviewDialog(store: store, payslipId: id, openPdf: (_) async => true),
            );
            if (context.mounted) refresh(() {});
          },
        ),
      ))),
    ));
    await tester.pumpAndSettle();
  }
  Future<void> open(WidgetTester tester) async {
    await tester.ensureVisible(find.text('1月'));
    await tester.tap(find.text('1月'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('元明細と照合して確認'));
    await tester.tap(find.text('元明細と照合して確認'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async { await Future<void>.delayed(const Duration(seconds: 2)); });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }
  Future<void> acknowledge(WidgetTester tester) async {
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '記載内容を本人確認済みにする'));
    await tester.pumpAndSettle();
  }
  Future<void> capture(WidgetTester tester, String name) async {
    await tester.runAsync(() async { await Future<void>.delayed(const Duration(seconds: 2)); });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await binding.takeScreenshot('$name-${mobile ? 'mobile' : 'desktop'}', {
      'width': tester.view.physicalSize.width / tester.view.devicePixelRatio,
      'height': tester.view.physicalSize.height / tester.view.devicePixelRatio,
      'devicePixelRatio': tester.view.devicePixelRatio,
    });
  }

  testWidgets('original review requires acknowledgement then refreshes confirmed cumulative totals', (tester) async {
    final store = SyntheticPayslipReviewStore();
    await showCard(tester, store);
    await open(tester);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, '記載内容を本人確認済みにする')).onPressed, isNull);
    expect(store.originalRequests, 0);
    await acknowledge(tester);
    expect(store.writes, 1);
    await tester.tap(find.text('閉じる'));
    await tester.pumpAndSettle();
    expect(find.text('税金の確認済み分：90円（1/12か月）'), findsOneWidget);
    await tester.ensureVisible(find.text('税金の確認済み分：90円（1/12か月）'));
    await capture(tester, 'payslip-review-confirmed');
  });
  testWidgets('lost update response only rereads current status without resend', (tester) async {
    final store = SyntheticPayslipReviewStore()..failAfterCommit = true;
    await showCard(tester, store);
    await open(tester);
    await acknowledge(tester);
    expect(store.writes, 1);
    await tester.ensureVisible(find.text('確認保存の現在状態を照合'));
    await tester.tap(find.text('確認保存の現在状態を照合'));
    await tester.pumpAndSettle();
    expect(find.textContaining('今回の操作で保存されたかは確定できません'), findsOneWidget);
    expect(store.writes, 1);
    await tester.ensureVisible(find.textContaining('今回の操作で保存されたかは確定できません'));
    await capture(tester, 'payslip-review-reconciled');
    await tester.tap(find.text('閉じる'));
    await tester.pumpAndSettle();
  });
  testWidgets('conflicting aliases prevent confirmation and never alter original values', (tester) async {
    final store = SyntheticPayslipReviewStore();
    (store.data['deductions'] as Map)['employees_pension_insurance'] = 99;
    await showCard(tester, store);
    await open(tester);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, '記載内容を本人確認済みにする')).onPressed, isNull);
    expect(store.writes, 0);
    await tester.ensureVisible(find.textContaining('項目名違いが競合しています'));
    await capture(tester, 'payslip-review-conflict');
    await tester.tap(find.text('閉じる'));
    await tester.pumpAndSettle();
  });
}
